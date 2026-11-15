use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum TopicConfigSource {
    DynamicTopic,
    DynamicBroker,
    DynamicDefaultBroker,
    StaticBroker,
    Default,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopicConfigEntry {
    pub name: String,
    pub value: Option<String>,
    pub source: TopicConfigSource,
    pub is_default: bool,
    pub is_sensitive: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum TopicConfigUnavailable {
    NotAuthorized,
    TopicNotFound,
    Failed(String),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum ConfigDiffStatus {
    Equal,
    Different,
    OnlyLeft,
    OnlyRight,
    NotComparable,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConfigDiffRow {
    pub name: String,
    pub left: Option<TopicConfigEntry>,
    pub right: Option<TopicConfigEntry>,
    pub status: ConfigDiffStatus,
    pub non_default: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopicConfigDiff {
    pub rows: Vec<ConfigDiffRow>,
    pub difference_count: Option<u32>,
}

fn index_first_wins(entries: &[TopicConfigEntry]) -> BTreeMap<&str, &TopicConfigEntry> {
    let mut map = BTreeMap::new();
    for entry in entries {
        map.entry(entry.name.as_str()).or_insert(entry);
    }
    map
}

/// Computes a deterministic, byte-order-sorted diff between two optional topic
/// configuration snapshots. `None` indicates that the side could not be read.
pub fn diff_topic_configs(
    left: Option<&[TopicConfigEntry]>,
    right: Option<&[TopicConfigEntry]>,
) -> TopicConfigDiff {
    match (left, right) {
        (None, None) => TopicConfigDiff {
            rows: Vec::new(),
            difference_count: None,
        },
        (Some(l_entries), None) => {
            let l_map = index_first_wins(l_entries);
            let rows = l_map
                .into_iter()
                .map(|(name, l)| ConfigDiffRow {
                    name: name.to_string(),
                    left: Some(l.clone()),
                    right: None,
                    status: ConfigDiffStatus::Unknown,
                    non_default: !l.is_default,
                })
                .collect();
            TopicConfigDiff {
                rows,
                difference_count: None,
            }
        }
        (None, Some(r_entries)) => {
            let r_map = index_first_wins(r_entries);
            let rows = r_map
                .into_iter()
                .map(|(name, r)| ConfigDiffRow {
                    name: name.to_string(),
                    left: None,
                    right: Some(r.clone()),
                    status: ConfigDiffStatus::Unknown,
                    non_default: !r.is_default,
                })
                .collect();
            TopicConfigDiff {
                rows,
                difference_count: None,
            }
        }
        (Some(l_entries), Some(r_entries)) => {
            let l_map = index_first_wins(l_entries);
            let mut r_map = index_first_wins(r_entries);

            let mut union: BTreeMap<&str, (Option<&TopicConfigEntry>, Option<&TopicConfigEntry>)> =
                BTreeMap::new();
            for (name, l) in l_map {
                let r = r_map.remove(name);
                union.insert(name, (Some(l), r));
            }
            for (name, r) in r_map {
                union.insert(name, (None, Some(r)));
            }

            let mut difference_count: u32 = 0;
            let mut rows = Vec::with_capacity(union.len());
            for (name, (l_opt, r_opt)) in union {
                let any_sensitive =
                    l_opt.is_some_and(|e| e.is_sensitive) || r_opt.is_some_and(|e| e.is_sensitive);
                let non_default =
                    l_opt.is_some_and(|e| !e.is_default) || r_opt.is_some_and(|e| !e.is_default);

                let status = if any_sensitive {
                    ConfigDiffStatus::NotComparable
                } else {
                    match (l_opt, r_opt) {
                        (Some(l), Some(r)) => {
                            if l.value == r.value {
                                ConfigDiffStatus::Equal
                            } else {
                                ConfigDiffStatus::Different
                            }
                        }
                        (Some(_), None) => ConfigDiffStatus::OnlyLeft,
                        (None, Some(_)) => ConfigDiffStatus::OnlyRight,
                        (None, None) => unreachable!(),
                    }
                };

                if matches!(
                    status,
                    ConfigDiffStatus::Different
                        | ConfigDiffStatus::OnlyLeft
                        | ConfigDiffStatus::OnlyRight
                ) {
                    difference_count += 1;
                }

                rows.push(ConfigDiffRow {
                    name: name.to_string(),
                    left: l_opt.cloned(),
                    right: r_opt.cloned(),
                    status,
                    non_default,
                });
            }

            TopicConfigDiff {
                rows,
                difference_count: Some(difference_count),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn entry(
        name: &str,
        value: Option<&str>,
        source: TopicConfigSource,
        is_default: bool,
        is_sensitive: bool,
    ) -> TopicConfigEntry {
        TopicConfigEntry {
            name: name.to_string(),
            value: value.map(ToString::to_string),
            source,
            is_default,
            is_sensitive,
        }
    }

    #[test]
    fn both_none_returns_empty_and_unknown_count() {
        let diff = diff_topic_configs(None, None);
        assert!(diff.rows.is_empty());
        assert_eq!(diff.difference_count, None);
    }

    #[test]
    fn one_side_none_marks_rows_unknown_and_count_none() {
        let left = vec![
            entry(
                "z.key",
                Some("1"),
                TopicConfigSource::DynamicTopic,
                false,
                false,
            ),
            entry("a.key", Some("2"), TopicConfigSource::Default, true, false),
        ];
        let diff_left_only = diff_topic_configs(Some(&left), None);
        assert_eq!(diff_left_only.difference_count, None);
        assert_eq!(
            diff_left_only
                .rows
                .iter()
                .map(|r| r.name.as_str())
                .collect::<Vec<_>>(),
            vec!["a.key", "z.key"]
        );
        assert_eq!(diff_left_only.rows[0].status, ConfigDiffStatus::Unknown);
        assert!(!diff_left_only.rows[0].non_default);
        assert_eq!(diff_left_only.rows[1].status, ConfigDiffStatus::Unknown);
        assert!(diff_left_only.rows[1].non_default);

        let diff_right_only = diff_topic_configs(None, Some(&left));
        assert_eq!(diff_right_only.difference_count, None);
        assert_eq!(diff_right_only.rows[0].status, ConfigDiffStatus::Unknown);
        assert!(diff_right_only.rows[0].left.is_none());
        assert!(diff_right_only.rows[0].right.is_some());
    }

    #[test]
    fn classifies_equal_different_only_left_only_right_and_sorted_order() {
        let left = vec![
            entry(
                "retention.ms",
                Some("60000"),
                TopicConfigSource::DynamicTopic,
                false,
                false,
            ),
            entry(
                "cleanup.policy",
                Some("delete"),
                TopicConfigSource::Default,
                true,
                false,
            ),
            entry(
                "only.left",
                Some("x"),
                TopicConfigSource::StaticBroker,
                false,
                false,
            ),
        ];
        let right = vec![
            entry(
                "retention.ms",
                Some("120000"),
                TopicConfigSource::DynamicTopic,
                false,
                false,
            ),
            entry(
                "cleanup.policy",
                Some("delete"),
                TopicConfigSource::Default,
                true,
                false,
            ),
            entry(
                "only.right",
                Some("y"),
                TopicConfigSource::DynamicBroker,
                false,
                false,
            ),
        ];

        let diff = diff_topic_configs(Some(&left), Some(&right));
        assert_eq!(diff.difference_count, Some(3));
        let names: Vec<_> = diff.rows.iter().map(|r| r.name.as_str()).collect();
        assert_eq!(
            names,
            vec!["cleanup.policy", "only.left", "only.right", "retention.ms"]
        );

        assert_eq!(diff.rows[0].status, ConfigDiffStatus::Equal);
        assert!(!diff.rows[0].non_default);
        assert_eq!(diff.rows[1].status, ConfigDiffStatus::OnlyLeft);
        assert!(diff.rows[1].non_default);
        assert_eq!(diff.rows[2].status, ConfigDiffStatus::OnlyRight);
        assert!(diff.rows[2].non_default);
        assert_eq!(diff.rows[3].status, ConfigDiffStatus::Different);
        assert!(diff.rows[3].non_default);
    }

    #[test]
    fn same_value_different_source_is_equal_with_non_default() {
        let left = vec![entry(
            "retention.ms",
            Some("604800000"),
            TopicConfigSource::DynamicTopic,
            false,
            false,
        )];
        let right = vec![entry(
            "retention.ms",
            Some("604800000"),
            TopicConfigSource::Default,
            true,
            false,
        )];

        let diff = diff_topic_configs(Some(&left), Some(&right));
        assert_eq!(diff.difference_count, Some(0));
        assert_eq!(diff.rows[0].status, ConfigDiffStatus::Equal);
        assert!(diff.rows[0].non_default);
    }

    #[test]
    fn sensitive_on_one_or_both_sides_is_not_comparable_and_not_counted() {
        let left = vec![
            entry(
                "secret.one",
                None,
                TopicConfigSource::DynamicTopic,
                false,
                true,
            ),
            entry(
                "secret.both",
                None,
                TopicConfigSource::DynamicTopic,
                false,
                true,
            ),
        ];
        let right = vec![
            entry(
                "secret.one",
                Some("plain"),
                TopicConfigSource::Default,
                true,
                false,
            ),
            entry("secret.both", None, TopicConfigSource::Default, true, true),
        ];

        let diff = diff_topic_configs(Some(&left), Some(&right));
        assert_eq!(diff.difference_count, Some(0));
        assert_eq!(diff.rows[0].status, ConfigDiffStatus::NotComparable);
        assert_eq!(diff.rows[1].status, ConfigDiffStatus::NotComparable);
    }

    #[test]
    fn none_value_vs_empty_string_are_different() {
        let left = vec![entry("k", None, TopicConfigSource::Default, true, false)];
        let right = vec![entry(
            "k",
            Some(""),
            TopicConfigSource::Default,
            true,
            false,
        )];

        let diff = diff_topic_configs(Some(&left), Some(&right));
        assert_eq!(diff.difference_count, Some(1));
        assert_eq!(diff.rows[0].status, ConfigDiffStatus::Different);
    }

    #[test]
    fn duplicate_names_use_first_wins() {
        let left = vec![
            entry(
                "k",
                Some("first"),
                TopicConfigSource::DynamicTopic,
                false,
                false,
            ),
            entry("k", Some("second"), TopicConfigSource::Default, true, false),
        ];
        let right = vec![entry(
            "k",
            Some("first"),
            TopicConfigSource::Default,
            true,
            false,
        )];

        let diff = diff_topic_configs(Some(&left), Some(&right));
        assert_eq!(diff.rows.len(), 1);
        assert_eq!(diff.rows[0].status, ConfigDiffStatus::Equal);
        assert_eq!(
            diff.rows[0].left.as_ref().unwrap().value.as_deref(),
            Some("first")
        );
    }
}
