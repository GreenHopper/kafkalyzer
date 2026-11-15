use crate::api::kafka_metadata::{TopicConfigEntry, TopicConfigSource};
use crate::api::kafka_types::ClusterProfile;
use kafkalyzer_core::topic_config as core;
use kafkalyzer_kafka::kafka_metadata::describe_topic_configs_detailed;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicConfigAvailability {
    Available,
    NotAuthorized,
    TopicNotFound,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigSnapshot {
    pub topic: String,
    pub availability: TopicConfigAvailability,
    pub error_message: Option<String>,
    pub entries: Vec<TopicConfigEntry>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicConfigDiffStatus {
    Equal,
    Different,
    OnlyLeft,
    OnlyRight,
    NotComparable,
    Unknown,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigDiffRow {
    pub name: String,
    pub left: Option<TopicConfigEntry>,
    pub right: Option<TopicConfigEntry>,
    pub status: TopicConfigDiffStatus,
    pub non_default: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigDiff {
    pub rows: Vec<TopicConfigDiffRow>,
    pub difference_count: Option<u32>,
}

fn source_to_api(s: core::TopicConfigSource) -> TopicConfigSource {
    match s {
        core::TopicConfigSource::DynamicTopic => TopicConfigSource::DynamicTopic,
        core::TopicConfigSource::DynamicBroker => TopicConfigSource::DynamicBroker,
        core::TopicConfigSource::DynamicDefaultBroker => TopicConfigSource::DynamicDefaultBroker,
        core::TopicConfigSource::StaticBroker => TopicConfigSource::StaticBroker,
        core::TopicConfigSource::Default => TopicConfigSource::Default,
        core::TopicConfigSource::Unknown => TopicConfigSource::Unknown,
    }
}

fn source_to_core(s: TopicConfigSource) -> core::TopicConfigSource {
    match s {
        TopicConfigSource::DynamicTopic => core::TopicConfigSource::DynamicTopic,
        TopicConfigSource::DynamicBroker => core::TopicConfigSource::DynamicBroker,
        TopicConfigSource::DynamicDefaultBroker => core::TopicConfigSource::DynamicDefaultBroker,
        TopicConfigSource::StaticBroker => core::TopicConfigSource::StaticBroker,
        TopicConfigSource::Default => core::TopicConfigSource::Default,
        TopicConfigSource::Unknown => core::TopicConfigSource::Unknown,
    }
}

fn entry_to_api(e: core::TopicConfigEntry) -> TopicConfigEntry {
    TopicConfigEntry {
        name: e.name,
        value: if e.is_sensitive { None } else { e.value },
        source: source_to_api(e.source),
        is_default: e.is_default,
        is_sensitive: e.is_sensitive,
        is_read_only: false,
    }
}

fn entry_to_core(e: TopicConfigEntry) -> core::TopicConfigEntry {
    core::TopicConfigEntry {
        name: e.name,
        value: if e.is_sensitive { None } else { e.value },
        source: source_to_core(e.source),
        is_default: e.is_default,
        is_sensitive: e.is_sensitive,
    }
}

impl From<core::ConfigDiffStatus> for TopicConfigDiffStatus {
    fn from(s: core::ConfigDiffStatus) -> Self {
        match s {
            core::ConfigDiffStatus::Equal => Self::Equal,
            core::ConfigDiffStatus::Different => Self::Different,
            core::ConfigDiffStatus::OnlyLeft => Self::OnlyLeft,
            core::ConfigDiffStatus::OnlyRight => Self::OnlyRight,
            core::ConfigDiffStatus::NotComparable => Self::NotComparable,
            core::ConfigDiffStatus::Unknown => Self::Unknown,
        }
    }
}

impl From<core::ConfigDiffRow> for TopicConfigDiffRow {
    fn from(r: core::ConfigDiffRow) -> Self {
        Self {
            name: r.name,
            left: r.left.map(entry_to_api),
            right: r.right.map(entry_to_api),
            status: r.status.into(),
            non_default: r.non_default,
        }
    }
}

impl From<core::TopicConfigDiff> for TopicConfigDiff {
    fn from(d: core::TopicConfigDiff) -> Self {
        Self {
            rows: d.rows.into_iter().map(Into::into).collect(),
            difference_count: d.difference_count,
        }
    }
}

pub(crate) fn snapshot_from_result(
    topic: String,
    result: Result<Vec<core::TopicConfigEntry>, core::TopicConfigUnavailable>,
) -> TopicConfigSnapshot {
    match result {
        Ok(entries) => TopicConfigSnapshot {
            topic,
            availability: TopicConfigAvailability::Available,
            error_message: None,
            entries: entries.into_iter().map(entry_to_api).collect(),
        },
        Err(core::TopicConfigUnavailable::NotAuthorized) => TopicConfigSnapshot {
            topic,
            availability: TopicConfigAvailability::NotAuthorized,
            error_message: None,
            entries: Vec::new(),
        },
        Err(core::TopicConfigUnavailable::TopicNotFound) => TopicConfigSnapshot {
            topic,
            availability: TopicConfigAvailability::TopicNotFound,
            error_message: None,
            entries: Vec::new(),
        },
        Err(core::TopicConfigUnavailable::Failed(msg)) => TopicConfigSnapshot {
            topic,
            availability: TopicConfigAvailability::Failed,
            error_message: Some(msg),
            entries: Vec::new(),
        },
    }
}

pub fn fetch_topic_config(profile: ClusterProfile, topic: String) -> TopicConfigSnapshot {
    let domain_profile = profile.to_domain();
    let mut results =
        describe_topic_configs_detailed(&domain_profile, std::slice::from_ref(&topic));
    match results.pop() {
        Some(item) => snapshot_from_result(item.topic, item.result),
        None => TopicConfigSnapshot {
            topic,
            availability: TopicConfigAvailability::Failed,
            error_message: Some("no result for topic".to_string()),
            entries: Vec::new(),
        },
    }
}

#[flutter_rust_bridge::frb(sync)]
pub fn diff_topic_configs(
    left: TopicConfigSnapshot,
    right: TopicConfigSnapshot,
) -> TopicConfigDiff {
    let left_entries: Option<Vec<core::TopicConfigEntry>> = (left.availability
        == TopicConfigAvailability::Available)
        .then(|| left.entries.into_iter().map(entry_to_core).collect());
    let right_entries: Option<Vec<core::TopicConfigEntry>> = (right.availability
        == TopicConfigAvailability::Available)
        .then(|| right.entries.into_iter().map(entry_to_core).collect());

    core::diff_topic_configs(left_entries.as_deref(), right_entries.as_deref()).into()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snapshot_from_result_maps_failed_not_authorized_and_sensitive() {
        let failed = snapshot_from_result(
            "t1".to_string(),
            Err(core::TopicConfigUnavailable::Failed(
                "timed out".to_string(),
            )),
        );
        assert_eq!(failed.availability, TopicConfigAvailability::Failed);
        assert_eq!(failed.error_message.as_deref(), Some("timed out"));
        assert!(failed.entries.is_empty());

        let denied = snapshot_from_result(
            "t2".to_string(),
            Err(core::TopicConfigUnavailable::NotAuthorized),
        );
        assert_eq!(denied.availability, TopicConfigAvailability::NotAuthorized);

        let avail = snapshot_from_result(
            "t1".to_string(),
            Ok(vec![core::TopicConfigEntry {
                name: "ssl.key.password".to_string(),
                value: Some("leaked".to_string()),
                source: core::TopicConfigSource::DynamicTopic,
                is_default: false,
                is_sensitive: true,
            }]),
        );
        assert_eq!(avail.entries[0].value, None);

        let diff = diff_topic_configs(avail, denied);
        assert_eq!(diff.difference_count, None);
        assert_eq!(diff.rows.len(), 1);
        assert_eq!(diff.rows[0].status, TopicConfigDiffStatus::Unknown);
    }
}
