use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_kafka::kafka_metadata::{fetch_topics, TopicMetadata};
use serde::Serialize;

use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::shape::{ResultMeta, StopReason};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TopicInfo {
    pub name: String,
    pub partition_count: Option<i32>,
    pub replication_factor: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cleanup_policy: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub retention_ms: Option<String>,
    pub readable: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub not_readable_reason: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ListTopicsOutput {
    pub topics: Vec<TopicInfo>,
    pub total: usize,
    pub internal_omitted: usize,
    pub meta: ResultMeta,
}

/// Map domain topic metadata into the tool output (filter, internal rule, list cap).
pub fn map_topics(
    topics: Vec<TopicMetadata>,
    name_filter: Option<&str>,
    include_internal: bool,
    max_entries: usize,
    limits: &crate::limits::Limits,
) -> ListTopicsOutput {
    let filter = name_filter.map(|s| s.to_ascii_lowercase());
    let mut internal_omitted = 0usize;
    let mut mapped: Vec<TopicInfo> = Vec::new();

    for t in topics {
        if Clusters::is_internal_topic(&t.name) && !include_internal {
            internal_omitted += 1;
            continue;
        }
        if let Some(ref f) = filter {
            if !t.name.to_ascii_lowercase().contains(f) {
                continue;
            }
        }
        let readable = t.metadata_error.is_none();
        mapped.push(TopicInfo {
            name: t.name,
            partition_count: if readable {
                Some(t.partition_count)
            } else {
                None
            },
            replication_factor: if readable {
                Some(t.replication_factor)
            } else {
                None
            },
            cleanup_policy: t.cleanup_policy,
            retention_ms: t.retention_ms,
            readable,
            not_readable_reason: t.metadata_error.map(|e| e.message),
        });
    }

    let total = mapped.len();
    let truncated = total > max_entries;
    if truncated {
        mapped.truncate(max_entries);
    }
    let mut meta = ResultMeta::new(limits);
    if truncated {
        meta.stop_reason = Some(StopReason::MessageLimit);
        meta.notes
            .push(format!("list truncated to {max_entries} of {total} topics"));
    }
    ListTopicsOutput {
        topics: mapped,
        total,
        internal_omitted,
        meta,
    }
}

pub fn kafka_list_topics(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    name_filter: Option<&str>,
    include_internal: bool,
) -> Result<ListTopicsOutput, ToolError> {
    kafka_list_topics_with(ctx, cluster, name_filter, include_internal, |profile| {
        fetch_topics(profile).map_err(|e| e.to_string())
    })
}

pub fn kafka_list_topics_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    name_filter: Option<&str>,
    include_internal: bool,
    fetch: F,
) -> Result<ListTopicsOutput, ToolError>
where
    F: FnOnce(ClusterProfile) -> Result<Vec<TopicMetadata>, String>,
{
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let topics = fetch(profile.clone())
        .map_err(|e| ToolError::Message(crate::shape::redact(&e, &profile)))?;
    Ok(map_topics(
        topics,
        name_filter,
        include_internal,
        ctx.limits.max_list_entries,
        &ctx.limits,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::limits::Limits;
    use kafkalyzer_kafka::kafka_metadata::{TopicMetadataError, TopicMetadataErrorKind};

    fn topic(name: &str, partitions: i32, readable: bool) -> TopicMetadata {
        TopicMetadata {
            name: name.into(),
            partition_count: partitions,
            replication_factor: 1,
            cleanup_policy: Some("delete".into()),
            retention_ms: Some("86400000".into()),
            under_replicated_partitions: Some(0),
            leaderless_partitions: Some(0),
            metadata_error: if readable {
                None
            } else {
                Some(TopicMetadataError {
                    kind: TopicMetadataErrorKind::NotAuthorized,
                    message: "not authorized".into(),
                })
            },
        }
    }

    #[test]
    fn list_cap_with_total_and_internal_omitted() {
        let mut topics = vec![topic("secret", 1, false)];
        for i in 0..10 {
            topics.push(topic(&format!("t-{i}"), 3, true));
        }
        topics.push(topic("__consumer_offsets", 50, true));
        topics.push(topic("_schemas", 1, true));

        let limits = Limits {
            max_list_entries: 5,
            ..Limits::defaults()
        };
        let out = map_topics(topics, None, false, limits.max_list_entries, &limits);
        assert_eq!(out.internal_omitted, 2);
        assert_eq!(out.total, 11); // 10 + unreadable, internals omitted
        assert_eq!(out.topics.len(), 5);
        assert!(!out.topics[0].readable);
        assert_eq!(out.meta.stop_reason, Some(StopReason::MessageLimit));
        assert!(!out.topics.iter().any(|t| t.name.starts_with('_')));
    }

    #[test]
    fn not_readable_topics_kept() {
        let out = map_topics(
            vec![topic("locked", 0, false)],
            None,
            false,
            500,
            &Limits::defaults(),
        );
        assert_eq!(out.topics.len(), 1);
        assert!(!out.topics[0].readable);
        assert_eq!(out.topics[0].partition_count, None);
        assert_eq!(
            out.topics[0].not_readable_reason.as_deref(),
            Some("not authorized")
        );
    }
}
