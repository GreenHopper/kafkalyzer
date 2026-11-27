use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_core::partitioner::default_partition;
use kafkalyzer_kafka::kafka_metadata::{
    fetch_topic_metadata, TopicMetadata, TopicMetadataErrorKind,
};
use serde::Serialize;

use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::shape::ResultMeta;

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct CalculatePartitionOutput {
    pub topic: String,
    pub key: String,
    pub partition_count: i32,
    pub partition: i32,
    pub meta: ResultMeta,
}

pub fn kafka_calculate_partition(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    topic: &str,
    key: &str,
    include_internal: bool,
) -> Result<CalculatePartitionOutput, ToolError> {
    kafka_calculate_partition_with(ctx, cluster, topic, key, include_internal, |profile, t| {
        fetch_topic_metadata(profile, t).map_err(|e| e.to_string())
    })
}

pub fn kafka_calculate_partition_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    topic: &str,
    key: &str,
    include_internal: bool,
    fetch_meta: F,
) -> Result<CalculatePartitionOutput, ToolError>
where
    F: FnOnce(ClusterProfile, String) -> Result<TopicMetadata, String>,
{
    Clusters::ensure_topic_allowed(topic, include_internal)?;
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let meta = fetch_meta(profile.clone(), topic.to_string())
        .map_err(|e| ToolError::Message(crate::shape::redact(&e, &profile)))?;
    if let Some(err) = meta.metadata_error {
        let msg = match err.kind {
            TopicMetadataErrorKind::NotFound => {
                format!("topic '{topic}' does not exist")
            }
            TopicMetadataErrorKind::NotAuthorized => {
                format!("topic '{topic}' is not readable: {}", err.message)
            }
            TopicMetadataErrorKind::Other => {
                format!("topic '{topic}': {}", err.message)
            }
        };
        return Err(ToolError::Message(msg));
    }
    if meta.partition_count <= 0 {
        return Err(ToolError::Message(format!(
            "topic '{topic}' has no usable partition count"
        )));
    }
    let partition = default_partition(key.as_bytes(), meta.partition_count).ok_or_else(|| {
        ToolError::Message(format!("could not calculate partition for topic '{topic}'"))
    })?;
    Ok(CalculatePartitionOutput {
        topic: topic.to_string(),
        key: key.to_string(),
        partition_count: meta.partition_count,
        partition,
        meta: ResultMeta::new(&ctx.limits),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::sync::atomic::AtomicBool;
    use std::sync::Arc;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn setup() -> (std::path::PathBuf, MemorySecretStore, Clusters) {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-part-{nanos}"));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("shared-profiles.json");
        let store = MemorySecretStore::new();
        let report = write_shared(
            &path,
            &store,
            &[SharedProfileInput {
                profile: ClusterProfile {
                    name: "local".into(),
                    bootstrap_servers: "localhost:9094".into(),
                    ..ClusterProfile::default()
                },
                environment_label: None,
            }],
        );
        assert!(report.file_error.is_none());
        (dir, store, Clusters::new(path, None::<String>))
    }

    #[test]
    fn calculate_partition_matches_default_partitioner() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let out = kafka_calculate_partition_with(
            &ctx,
            Some("local"),
            "orders",
            "order-1",
            false,
            |_, _| {
                Ok(TopicMetadata {
                    name: "orders".into(),
                    partition_count: 12,
                    replication_factor: 1,
                    cleanup_policy: None,
                    retention_ms: None,
                    under_replicated_partitions: Some(0),
                    leaderless_partitions: Some(0),
                    metadata_error: None,
                })
            },
        )
        .unwrap();
        let expected = default_partition(b"order-1", 12).unwrap();
        assert_eq!(out.partition, expected);
        assert_eq!(out.partition_count, 12);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn missing_topic_is_error() {
        use kafkalyzer_kafka::kafka_metadata::{TopicMetadataError, TopicMetadataErrorKind};
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let err =
            kafka_calculate_partition_with(&ctx, Some("local"), "nope", "k", false, |_, _| {
                Ok(TopicMetadata {
                    name: "nope".into(),
                    partition_count: 0,
                    replication_factor: 0,
                    cleanup_policy: None,
                    retention_ms: None,
                    under_replicated_partitions: None,
                    leaderless_partitions: None,
                    metadata_error: Some(TopicMetadataError {
                        kind: TopicMetadataErrorKind::NotFound,
                        message: "unknown".into(),
                    }),
                })
            })
            .unwrap_err();
        assert!(err.message().contains("nope"));
        let _ = fs::remove_dir_all(&dir);
    }
}
