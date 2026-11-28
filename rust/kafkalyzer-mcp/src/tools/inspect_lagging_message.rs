use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Instant;

use kafkalyzer_core::kafka_types::{
    ClusterProfile, ConsumerGroupLag, FilterType, PartitionLagStatus, SearchScope,
};
use kafkalyzer_kafka::bounded::{collect_messages, CollectBounds, CollectedMessages};
use kafkalyzer_kafka::kafka_consumer::{ConsumeCriteria, ScanBounds};
use kafkalyzer_kafka::kafka_metadata::fetch_consumer_group_lag;
use serde::Serialize;

use super::get_consumer_lag::LagStatusOut;
use super::messages::{map_collected, MessageOut};
use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::shape::{redact, ResultMeta, StopReason};

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct InspectLaggingMessageOutput {
    pub group_id: String,
    pub topic: String,
    pub partition: i32,
    pub status: LagStatusOut,
    /// Next offset the group would consume; set when status is `known`.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub committed_offset: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub message: Option<MessageOut>,
    /// Present for `unknown`, or when a known partition has no unprocessed message / empty scan.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub detail: Option<String>,
    pub meta: ResultMeta,
}

pub fn kafka_inspect_lagging_message(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    group_id: &str,
    topic: &str,
    partition: i32,
    include_internal: bool,
) -> Result<InspectLaggingMessageOutput, ToolError> {
    kafka_inspect_lagging_message_with(
        ctx,
        cluster,
        group_id,
        topic,
        partition,
        include_internal,
        |profile, gid| fetch_consumer_group_lag(profile, gid).map_err(|e| e.to_string()),
        |profile, t, criteria, bounds, collect, max_text, cancel| {
            collect_messages(profile, t, criteria, bounds, collect, max_text, cancel)
                .map_err(|e| e.to_string())
        },
    )
}

#[allow(clippy::too_many_arguments)]
pub fn kafka_inspect_lagging_message_with<FLag, FCollect>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    group_id: &str,
    topic: &str,
    partition: i32,
    include_internal: bool,
    fetch_lag: FLag,
    collect: FCollect,
) -> Result<InspectLaggingMessageOutput, ToolError>
where
    FLag: FnOnce(ClusterProfile, String) -> Result<ConsumerGroupLag, String>,
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
    let lag = fetch_lag(profile.clone(), group_id.to_string())
        .map_err(|e| ToolError::Message(redact(&e, &profile)))?;

    let part = lag
        .partition_lags
        .iter()
        .find(|p| p.topic == topic && p.partition == partition)
        .cloned()
        .ok_or_else(|| {
            ToolError::Message(format!(
                "partition {partition} of topic '{topic}' was not found for group '{group_id}'"
            ))
        })?;

    let status = LagStatusOut::from(part.status);
    let mut meta = ResultMeta::new(&ctx.limits);

    match part.status {
        PartitionLagStatus::NoCommit => {
            return Ok(InspectLaggingMessageOutput {
                group_id: group_id.into(),
                topic: topic.into(),
                partition,
                status,
                committed_offset: None,
                message: None,
                detail: Some("no committed offset for this partition".into()),
                meta,
            });
        }
        PartitionLagStatus::Unknown => {
            return Ok(InspectLaggingMessageOutput {
                group_id: group_id.into(),
                topic: topic.into(),
                partition,
                status,
                committed_offset: None,
                message: None,
                detail: part
                    .error
                    .or_else(|| Some("partition lag is unknown".into())),
                meta,
            });
        }
        PartitionLagStatus::Known => {}
    }

    let committed = part.current_offset;
    let log_end = part.log_end_offset;
    if committed >= log_end {
        meta.notes
            .push("no unprocessed message; group is caught up".into());
        return Ok(InspectLaggingMessageOutput {
            group_id: group_id.into(),
            topic: topic.into(),
            partition,
            status,
            committed_offset: Some(committed),
            message: None,
            detail: Some("no unprocessed message".into()),
            meta,
        });
    }

    let criteria = ConsumeCriteria {
        filter_terms: None,
        filter_field: None,
        filter_type: FilterType::Contains,
        search_scope: SearchScope::Both,
        filter_expression: None,
        filter_variables: None,
        local_schemas: None,
        fast_trace_key: None,
        start_partition: Some(partition),
        max_results: Some(1),
        run_forever: false,
    };
    let bounds = ScanBounds {
        start_offset: Some(committed),
        ..ScanBounds::default()
    };
    let collect_bounds = CollectBounds {
        max_messages: 1,
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
    meta.stop_reason = Some(stop);
    let message = messages.into_iter().next();
    let detail = if message.is_none() && stop == StopReason::Complete {
        Some("partition end reached with no message at or after the committed offset".into())
    } else {
        None
    };

    Ok(InspectLaggingMessageOutput {
        group_id: group_id.into(),
        topic: topic.into(),
        partition,
        status,
        committed_offset: Some(committed),
        message,
        detail,
        meta,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
    use kafkalyzer_core::kafka_types::{ClusterProfile, TopicPartitionLag};
    use kafkalyzer_kafka::bounded::CollectStop;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::sync::atomic::{AtomicBool, Ordering};
    use std::sync::Mutex;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn setup() -> (std::path::PathBuf, MemorySecretStore, Clusters) {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-inspect-{nanos}"));
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

    fn lag_with(parts: Vec<TopicPartitionLag>) -> ConsumerGroupLag {
        ConsumerGroupLag {
            group_id: "g".into(),
            state: "Stable".into(),
            protocol_type: "consumer".into(),
            partition_lags: parts,
            members_count: 1,
            topics_count: 1,
            members: vec![],
            unassigned_partitions: vec![],
            lag_error: None,
            ownership_known: true,
        }
    }

    fn part(
        status: PartitionLagStatus,
        current: i64,
        log_end: i64,
        error: Option<&str>,
    ) -> TopicPartitionLag {
        TopicPartitionLag {
            topic: "orders".into(),
            partition: 1,
            log_end_offset: log_end,
            current_offset: current,
            lag: if matches!(status, PartitionLagStatus::Known) {
                (log_end - current).max(0)
            } else {
                0
            },
            status,
            error: error.map(str::to_string),
        }
    }

    #[test]
    fn no_commit_does_not_read() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let read = Arc::new(AtomicBool::new(false));
        let read_c = Arc::clone(&read);
        let out = kafka_inspect_lagging_message_with(
            &ctx,
            Some("local"),
            "g",
            "orders",
            1,
            false,
            |_, _| {
                Ok(lag_with(vec![part(
                    PartitionLagStatus::NoCommit,
                    -1,
                    100,
                    None,
                )]))
            },
            move |_, _, _, _, _, _, _| {
                read_c.store(true, Ordering::SeqCst);
                panic!("must not collect");
            },
        )
        .unwrap();
        assert!(!read.load(Ordering::SeqCst));
        assert_eq!(out.status, LagStatusOut::NoCommit);
        assert!(out.message.is_none());
        assert!(out.committed_offset.is_none());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn unknown_does_not_read() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let read = Arc::new(AtomicBool::new(false));
        let read_c = Arc::clone(&read);
        let out = kafka_inspect_lagging_message_with(
            &ctx,
            Some("local"),
            "g",
            "orders",
            1,
            false,
            |_, _| {
                Ok(lag_with(vec![part(
                    PartitionLagStatus::Unknown,
                    -1,
                    -1,
                    Some("not authorized"),
                )]))
            },
            move |_, _, _, _, _, _, _| {
                read_c.store(true, Ordering::SeqCst);
                panic!("must not collect");
            },
        )
        .unwrap();
        assert!(!read.load(Ordering::SeqCst));
        assert_eq!(out.status, LagStatusOut::Unknown);
        assert_eq!(out.detail.as_deref(), Some("not authorized"));
        assert!(out.message.is_none());
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn caught_up_does_not_read() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let read = Arc::new(AtomicBool::new(false));
        let read_c = Arc::clone(&read);
        let out = kafka_inspect_lagging_message_with(
            &ctx,
            Some("local"),
            "g",
            "orders",
            1,
            false,
            |_, _| {
                Ok(lag_with(vec![part(
                    PartitionLagStatus::Known,
                    50,
                    50,
                    None,
                )]))
            },
            move |_, _, _, _, _, _, _| {
                read_c.store(true, Ordering::SeqCst);
                panic!("must not collect");
            },
        )
        .unwrap();
        assert!(!read.load(Ordering::SeqCst));
        assert_eq!(out.status, LagStatusOut::Known);
        assert_eq!(out.committed_offset, Some(50));
        assert!(out.message.is_none());
        assert_eq!(out.detail.as_deref(), Some("no unprocessed message"));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn lagging_reads_from_committed_offset() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let seen = Arc::new(Mutex::new(None));
        let seen_c = Arc::clone(&seen);
        let out = kafka_inspect_lagging_message_with(
            &ctx,
            Some("local"),
            "g",
            "orders",
            1,
            false,
            |_, _| {
                Ok(lag_with(vec![part(
                    PartitionLagStatus::Known,
                    10,
                    40,
                    None,
                )]))
            },
            move |_, _, criteria, bounds, collect, _, _| {
                *seen_c.lock().unwrap() = Some((
                    criteria.start_partition,
                    bounds.start_offset,
                    collect.max_messages,
                ));
                Ok(CollectedMessages {
                    messages: vec![],
                    stop: CollectStop::Complete,
                    scanned: Some(0),
                    log: vec![],
                })
            },
        )
        .unwrap();
        assert_eq!(out.committed_offset, Some(10));
        assert!(out.message.is_none());
        assert!(out.detail.as_ref().unwrap().contains("no message"));
        let (part, offset, max) = (*seen.lock().unwrap()).unwrap();
        assert_eq!(part, Some(1));
        assert_eq!(offset, Some(10));
        assert_eq!(max, 1);
        let _ = fs::remove_dir_all(&dir);
    }
}
