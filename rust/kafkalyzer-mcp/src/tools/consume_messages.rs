use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Instant;

use kafkalyzer_core::kafka_types::{ClusterProfile, FilterType, SearchScope};
use kafkalyzer_kafka::bounded::{collect_messages, CollectBounds, CollectedMessages};
use kafkalyzer_kafka::kafka_consumer::{ConsumeCriteria, ScanBounds};
use kafkalyzer_kafka::kafka_metadata::{fetch_topic_metadata, TopicMetadata};
use serde::Serialize;

use super::messages::{
    ensure_topic_readable, map_collected, position_to_bounds, ConsumePosition, MessageOut,
};
use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::shape::{redact, ResultMeta, StopReason};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ConsumeMessagesOutput {
    pub messages: Vec<MessageOut>,
    pub meta: ResultMeta,
}

pub fn kafka_consume_messages(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    topic: &str,
    position: ConsumePosition,
    partition: Option<i32>,
    include_internal: bool,
) -> Result<ConsumeMessagesOutput, ToolError> {
    kafka_consume_messages_with(
        ctx,
        cluster,
        topic,
        position,
        partition,
        include_internal,
        |profile, t| fetch_topic_metadata(profile, t).map_err(|e| e.to_string()),
        |profile, t, criteria, bounds, collect, max_text, cancel| {
            collect_messages(profile, t, criteria, bounds, collect, max_text, cancel)
                .map_err(|e| e.to_string())
        },
    )
}

#[allow(clippy::too_many_arguments)]
pub fn kafka_consume_messages_with<FMeta, FCollect>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    topic: &str,
    position: ConsumePosition,
    partition: Option<i32>,
    include_internal: bool,
    fetch_meta: FMeta,
    collect: FCollect,
) -> Result<ConsumeMessagesOutput, ToolError>
where
    FMeta: FnOnce(ClusterProfile, String) -> Result<TopicMetadata, String>,
    FCollect: FnOnce(
        ClusterProfile,
        String,
        ConsumeCriteria,
        ScanBounds,
        CollectBounds,
        usize,
        Arc<AtomicBool>,
    ) -> Result<CollectedMessages, String>,
{
    Clusters::ensure_topic_allowed(topic, include_internal)?;
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let meta = fetch_meta(profile.clone(), topic.to_string())
        .map_err(|e| ToolError::Message(redact(&e, &profile)))?;
    ensure_topic_readable(&meta)?;

    let criteria = ConsumeCriteria {
        filter_terms: None,
        filter_field: None,
        filter_type: FilterType::Contains,
        search_scope: SearchScope::Both,
        filter_expression: None,
        filter_variables: None,
        local_schemas: None,
        fast_trace_key: None,
        start_partition: partition,
        max_results: None,
        run_forever: false,
    };
    let bounds = position_to_bounds(position);
    let collect_bounds = CollectBounds {
        max_messages: ctx.limits.max_messages,
        deadline: Instant::now() + ctx.limits.time_budget,
    };
    let collected = collect(
        profile.clone(),
        topic.to_string(),
        criteria,
        bounds,
        collect_bounds,
        ctx.limits.max_text_bytes,
        Arc::clone(&ctx.cancel),
    )
    .map_err(|e| ToolError::Message(redact(&e, &profile)))?;

    let (messages, stop) = map_collected(collected);
    let mut meta_out = ResultMeta::new(&ctx.limits);
    meta_out.stop_reason = Some(stop);
    if stop == StopReason::Complete && messages.is_empty() {
        meta_out
            .notes
            .push("end of topic reached; no messages".into());
    }
    Ok(ConsumeMessagesOutput {
        messages,
        meta: meta_out,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
    use kafkalyzer_core::kafka_types::ClusterProfile;
    use kafkalyzer_kafka::bounded::CollectStop;
    use kafkalyzer_kafka::kafka_metadata::TopicMetadata;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::sync::Mutex;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn setup() -> (std::path::PathBuf, MemorySecretStore, Clusters) {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-consume-{nanos}"));
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
        (dir, store, Clusters::new(&path, None::<String>))
    }

    fn ok_meta(name: &str) -> TopicMetadata {
        TopicMetadata {
            name: name.into(),
            partition_count: 3,
            replication_factor: 1,
            cleanup_policy: None,
            retention_ms: None,
            under_replicated_partitions: Some(0),
            leaderless_partitions: Some(0),
            metadata_error: None,
        }
    }

    #[test]
    fn position_mapping_passed_to_collect() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let seen = Arc::new(Mutex::new(None));
        let seen_c = Arc::clone(&seen);
        let out = kafka_consume_messages_with(
            &ctx,
            Some("local"),
            "orders",
            ConsumePosition::Offset(99),
            Some(2),
            false,
            |_, t| Ok(ok_meta(&t)),
            move |_, _, criteria, bounds, _, _, _| {
                *seen_c.lock().unwrap() = Some((criteria.start_partition, bounds));
                Ok(CollectedMessages {
                    messages: vec![],
                    stop: CollectStop::Complete,
                    scanned: Some(0),
                    log: vec![],
                })
            },
        )
        .unwrap();
        assert_eq!(out.meta.stop_reason, Some(StopReason::Complete));
        let (part, bounds) = (*seen.lock().unwrap()).unwrap();
        assert_eq!(part, Some(2));
        assert_eq!(bounds.start_offset, Some(99));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn internal_topic_refused_without_flag() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let err = kafka_consume_messages_with(
            &ctx,
            Some("local"),
            "__consumer_offsets",
            ConsumePosition::Oldest,
            None,
            false,
            |_, _| panic!("must not fetch meta"),
            |_, _, _, _, _, _, _| panic!("must not collect"),
        )
        .unwrap_err();
        assert!(err.message().contains("internal"));
        let _ = fs::remove_dir_all(&dir);
    }
}
