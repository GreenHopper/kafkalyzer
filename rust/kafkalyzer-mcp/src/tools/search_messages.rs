use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Instant;

use kafkalyzer_core::kafka_types::{ClusterProfile, FilterType};
use kafkalyzer_kafka::bounded::{collect_messages, CollectBounds, CollectedMessages};
use kafkalyzer_kafka::kafka_consumer::{invalid_filter_patterns, ConsumeCriteria, ScanBounds};
use kafkalyzer_kafka::kafka_metadata::{fetch_topic_metadata, TopicMetadata};
use serde::Serialize;

use super::messages::{
    ensure_topic_readable, map_collected, parse_filter_type, parse_search_scope,
    position_to_bounds, ConsumePosition, MessageOut,
};
use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::shape::{redact, ResultMeta, StopReason};

/// How far a single topic got in a multi-topic search.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum TopicScanState {
    Complete,
    Partial,
    NotScanned,
    Error,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TopicScanStatus {
    pub topic: String,
    pub state: TopicScanState,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SearchMessagesOutput {
    pub messages: Vec<MessageOut>,
    pub topics: Vec<TopicScanStatus>,
    pub meta: ResultMeta,
}

pub struct SearchMessagesRequest<'a> {
    pub cluster: Option<&'a str>,
    pub topics: &'a [String],
    pub pattern: &'a str,
    pub filter_type: &'a str,
    pub search_scope: Option<&'a str>,
    pub filter_field: Option<&'a str>,
    pub position: ConsumePosition,
    pub include_internal: bool,
}

pub fn kafka_search_messages(
    ctx: &ToolContext<'_>,
    req: SearchMessagesRequest<'_>,
) -> Result<SearchMessagesOutput, ToolError> {
    kafka_search_messages_with(
        ctx,
        req,
        |profile, t| fetch_topic_metadata(profile, t).map_err(|e| e.to_string()),
        |profile, t, criteria, bounds, collect, max_text, cancel| {
            collect_messages(profile, t, criteria, bounds, collect, max_text, cancel)
                .map_err(|e| e.to_string())
        },
    )
}

pub fn kafka_search_messages_with<FMeta, FCollect>(
    ctx: &ToolContext<'_>,
    req: SearchMessagesRequest<'_>,
    mut fetch_meta: FMeta,
    mut collect: FCollect,
) -> Result<SearchMessagesOutput, ToolError>
where
    FMeta: FnMut(ClusterProfile, String) -> Result<TopicMetadata, String>,
    FCollect: FnMut(
        ClusterProfile,
        String,
        ConsumeCriteria,
        ScanBounds,
        CollectBounds,
        usize,
        Arc<AtomicBool>,
    ) -> Result<CollectedMessages, String>,
{
    if req.topics.is_empty() {
        return Err(ToolError::Message(
            "at least one topic is required for kafka_search_messages".into(),
        ));
    }
    if req.topics.len() > ctx.limits.max_search_topics {
        return Err(ToolError::Message(format!(
            "at most {} topics per search call (got {})",
            ctx.limits.max_search_topics,
            req.topics.len()
        )));
    }

    let filter_type = parse_filter_type(req.filter_type)?;
    let terms = vec![req.pattern.to_string()];
    if filter_type == FilterType::Regex {
        let bad = invalid_filter_patterns(&terms);
        if let Some(pattern) = bad.into_iter().next() {
            return Err(ToolError::Message(format!(
                "invalid regular expression '{pattern}'"
            )));
        }
    }

    for topic in req.topics {
        Clusters::ensure_topic_allowed(topic, req.include_internal)?;
    }

    let profile = ctx.clusters.resolve(ctx.store, req.cluster)?;
    let search_scope = parse_search_scope(req.search_scope);
    let bounds = position_to_bounds(req.position);
    let deadline = Instant::now() + ctx.limits.time_budget;

    let mut messages = Vec::new();
    let mut topic_status = Vec::new();
    let mut remaining = ctx.limits.max_messages;
    let mut overall_stop = StopReason::Complete;
    let mut reached_budget = false;

    for topic in req.topics {
        if remaining == 0 || Instant::now() >= deadline {
            topic_status.push(TopicScanStatus {
                topic: topic.clone(),
                state: TopicScanState::NotScanned,
                error: None,
            });
            if remaining == 0 {
                overall_stop = StopReason::MessageLimit;
            } else {
                overall_stop = StopReason::TimeLimit;
            }
            reached_budget = true;
            continue;
        }

        let meta = match fetch_meta(profile.clone(), topic.clone()) {
            Ok(m) => m,
            Err(e) => {
                topic_status.push(TopicScanStatus {
                    topic: topic.clone(),
                    state: TopicScanState::Error,
                    error: Some(redact(&e, &profile)),
                });
                continue;
            }
        };
        if let Err(err) = ensure_topic_readable(&meta) {
            topic_status.push(TopicScanStatus {
                topic: topic.clone(),
                state: TopicScanState::Error,
                error: Some(err.message()),
            });
            continue;
        }

        let criteria = ConsumeCriteria {
            filter_terms: Some(terms.clone()),
            filter_field: req.filter_field.map(str::to_string),
            filter_type,
            search_scope,
            filter_expression: None,
            filter_variables: None,
            local_schemas: None,
            fast_trace_key: None,
            start_partition: None,
            max_results: None,
            run_forever: false,
        };
        let collect_bounds = CollectBounds {
            max_messages: remaining,
            deadline,
        };
        match collect(
            profile.clone(),
            topic.clone(),
            criteria,
            bounds,
            collect_bounds,
            ctx.limits.max_text_bytes,
            Arc::clone(&ctx.cancel),
        ) {
            Ok(collected) => {
                let (mapped, stop) = map_collected(collected);
                remaining = remaining.saturating_sub(mapped.len());
                messages.extend(mapped);
                let state = match stop {
                    StopReason::Complete => TopicScanState::Complete,
                    StopReason::MessageLimit
                    | StopReason::TimeLimit
                    | StopReason::Cancelled
                    | StopReason::ResultBudget => {
                        overall_stop = stop;
                        TopicScanState::Partial
                    }
                };
                topic_status.push(TopicScanStatus {
                    topic: topic.clone(),
                    state,
                    error: None,
                });
            }
            Err(e) => {
                topic_status.push(TopicScanStatus {
                    topic: topic.clone(),
                    state: TopicScanState::Error,
                    error: Some(redact(&e, &profile)),
                });
            }
        }
    }

    if reached_budget {
        // already set overall_stop
    } else if messages.len() >= ctx.limits.max_messages
        && topic_status
            .iter()
            .any(|t| t.state == TopicScanState::Partial)
    {
        overall_stop = StopReason::MessageLimit;
    }

    let mut meta = ResultMeta::new(&ctx.limits);
    meta.stop_reason = Some(overall_stop);
    if overall_stop == StopReason::Complete && messages.is_empty() {
        meta.notes
            .push("scan complete; no matching messages".into());
    }

    Ok(SearchMessagesOutput {
        messages,
        topics: topic_status,
        meta,
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
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::{SystemTime, UNIX_EPOCH};

    fn setup() -> (std::path::PathBuf, MemorySecretStore, Clusters) {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-search-{nanos}"));
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
            partition_count: 1,
            replication_factor: 1,
            cleanup_policy: None,
            retention_ms: None,
            under_replicated_partitions: Some(0),
            leaderless_partitions: Some(0),
            metadata_error: None,
        }
    }

    #[test]
    fn invalid_regex_fails_before_any_io() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let meta_calls = Arc::new(AtomicUsize::new(0));
        let meta_c = Arc::clone(&meta_calls);
        let err = kafka_search_messages_with(
            &ctx,
            SearchMessagesRequest {
                cluster: Some("local"),
                topics: &["a".into()],
                pattern: "(",
                filter_type: "regex",
                search_scope: None,
                filter_field: None,
                position: ConsumePosition::Oldest,
                include_internal: false,
            },
            move |_, _| {
                meta_c.fetch_add(1, Ordering::SeqCst);
                panic!("must not fetch meta")
            },
            |_, _, _, _, _, _, _| panic!("must not collect"),
        )
        .unwrap_err();
        assert!(err.message().contains("invalid regular expression"));
        assert!(err.message().contains("("));
        assert_eq!(meta_calls.load(Ordering::SeqCst), 0);
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn per_topic_scan_state_marks_unreached_as_not_scanned() {
        let (dir, store, clusters) = setup();
        let limits = Limits {
            max_messages: 1,
            max_search_topics: 5,
            ..Limits::defaults()
        };
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits,
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let topics = vec!["a".into(), "b".into(), "c".into()];
        let out = kafka_search_messages_with(
            &ctx,
            SearchMessagesRequest {
                cluster: Some("local"),
                topics: &topics,
                pattern: "x",
                filter_type: "contains",
                search_scope: Some("value"),
                filter_field: None,
                position: ConsumePosition::Oldest,
                include_internal: false,
            },
            |_, t| Ok(ok_meta(&t)),
            |_, t, _, _, collect, _, _| {
                // First topic fills the budget immediately.
                if t == "a" {
                    use kafkalyzer_core::kafka_types::KafkaMessage;
                    use kafkalyzer_kafka::bounded::{CollectedMessage, OriginalSizes};
                    Ok(CollectedMessages {
                        messages: vec![CollectedMessage {
                            message: KafkaMessage {
                                topic: t,
                                partition: 0,
                                offset: 0,
                                key: None,
                                payload: Some("x".into()),
                                timestamp: 0,
                                headers: None,
                                key_schema: None,
                                value_schema: None,
                                key_local_schema: None,
                                value_local_schema: None,
                            },
                            original_sizes: OriginalSizes::default(),
                        }],
                        stop: if collect.max_messages <= 1 {
                            CollectStop::MessageLimit
                        } else {
                            CollectStop::Complete
                        },
                        scanned: Some(1),
                        log: vec![],
                    })
                } else {
                    panic!("topic {t} must not be scanned after budget")
                }
            },
        )
        .unwrap();
        assert_eq!(out.messages.len(), 1);
        assert_eq!(out.topics[0].state, TopicScanState::Partial);
        assert_eq!(out.topics[1].state, TopicScanState::NotScanned);
        assert_eq!(out.topics[2].state, TopicScanState::NotScanned);
        assert_eq!(out.meta.stop_reason, Some(StopReason::MessageLimit));
        let _ = fs::remove_dir_all(&dir);
    }
}
