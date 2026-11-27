use std::sync::atomic::AtomicBool;
use std::sync::Arc;
use std::time::Instant;

use kafkalyzer_core::analysis_scope::{AnalysisScope, ScopeLimitFrom};
use kafkalyzer_core::kafka_types::{
    ClusterProfile, FieldOccurrence, FieldValueOccurrence, KeyOccurrence, PartitionAnalysis,
    TopicAnalysisOptions, TopicAnalysisReport, TypeOccurrence,
};
use kafkalyzer_kafka::bounded::{collect_topic_analysis, CollectStop, CollectedAnalysis};
use kafkalyzer_kafka::kafka_metadata::{fetch_topic_metadata, TopicMetadata};
use serde::Serialize;

use super::messages::ensure_topic_readable;
use super::{ToolContext, ToolError};
use crate::clusters::Clusters;
use crate::shape::{cap_text, CappedText, ResultMeta, StopReason};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum AnalyzeLimitFrom {
    Newest,
    Oldest,
}

impl From<AnalyzeLimitFrom> for ScopeLimitFrom {
    fn from(v: AnalyzeLimitFrom) -> Self {
        match v {
            AnalyzeLimitFrom::Newest => ScopeLimitFrom::Newest,
            AnalyzeLimitFrom::Oldest => ScopeLimitFrom::Oldest,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct KeySampleOut {
    pub key: CappedText,
    pub count: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FieldValueSampleOut {
    pub value: CappedText,
    pub count: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub struct FieldFrequencyOut {
    pub field_name: String,
    pub count: i64,
    pub percentage: f64,
    pub top_values: Vec<FieldValueSampleOut>,
}

#[derive(Debug, Clone, Serialize)]
pub struct AnalyzeTopicOutput {
    pub topic: String,
    pub total_messages: i64,
    pub total_bytes: i64,
    pub min_message_size: i64,
    pub max_message_size: i64,
    pub avg_message_size: f64,
    pub tombstones_count: i64,
    pub is_compacted: bool,
    pub null_keys_count: i64,
    pub partition_stats: Vec<PartitionAnalysis>,
    pub top_keys: Vec<KeySampleOut>,
    pub content_type_distribution: Vec<TypeOccurrence>,
    pub field_frequencies: Vec<FieldFrequencyOut>,
    pub scan_duration_ms: i64,
    /// True when the scan stopped before a complete pass.
    pub partial: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub scanned: Option<i64>,
    pub meta: ResultMeta,
}

fn map_key(k: KeyOccurrence, max_text: usize) -> KeySampleOut {
    KeySampleOut {
        key: cap_text(&k.key, max_text),
        count: k.count,
        percentage: k.percentage,
    }
}

fn map_field_value(v: FieldValueOccurrence, max_text: usize) -> FieldValueSampleOut {
    FieldValueSampleOut {
        value: cap_text(&v.value, max_text),
        count: v.count,
        percentage: v.percentage,
    }
}

fn map_field(f: FieldOccurrence, max_text: usize) -> FieldFrequencyOut {
    FieldFrequencyOut {
        field_name: f.field_name,
        count: f.count,
        percentage: f.percentage,
        top_values: f
            .top_values
            .into_iter()
            .map(|v| map_field_value(v, max_text))
            .collect(),
    }
}

pub fn map_analysis_report(
    report: TopicAnalysisReport,
    stop: CollectStop,
    scanned: Option<i64>,
    max_text: usize,
    limits: &crate::limits::Limits,
) -> AnalyzeTopicOutput {
    let partial = !matches!(stop, CollectStop::Complete);
    let mut meta = ResultMeta::new(limits);
    meta.stop_reason = Some(match stop {
        CollectStop::Complete => StopReason::Complete,
        CollectStop::MessageLimit => StopReason::MessageLimit,
        CollectStop::TimeLimit => StopReason::TimeLimit,
        CollectStop::Cancelled => StopReason::Cancelled,
    });
    if partial {
        meta.notes.push("analysis is partial".into());
    }
    if report.size_percentiles_estimated || report.key_cardinality_capped {
        meta.notes
            .push("some figures derived from capped samples are estimates".into());
    }
    AnalyzeTopicOutput {
        topic: report.topic,
        total_messages: report.total_messages,
        total_bytes: report.total_bytes,
        min_message_size: report.min_message_size,
        max_message_size: report.max_message_size,
        avg_message_size: report.avg_message_size,
        tombstones_count: report.tombstones_count,
        is_compacted: report.is_compacted,
        null_keys_count: report.null_keys_count,
        partition_stats: report.partition_stats,
        top_keys: report
            .top_keys
            .into_iter()
            .map(|k| map_key(k, max_text))
            .collect(),
        content_type_distribution: report.content_type_distribution,
        field_frequencies: report
            .field_frequencies
            .into_iter()
            .map(|f| map_field(f, max_text))
            .collect(),
        scan_duration_ms: report.scan_duration_ms,
        partial,
        scanned,
        meta,
    }
}

pub fn kafka_analyze_topic(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    topic: &str,
    limit_from: AnalyzeLimitFrom,
    include_internal: bool,
) -> Result<AnalyzeTopicOutput, ToolError> {
    kafka_analyze_topic_with(
        ctx,
        cluster,
        topic,
        limit_from,
        include_internal,
        |profile, t| fetch_topic_metadata(profile, t).map_err(|e| e.to_string()),
        |profile, t, options, deadline, cancel| {
            collect_topic_analysis(profile, t, options, deadline, cancel).map_err(|e| e.to_string())
        },
    )
}

pub fn kafka_analyze_topic_with<FMeta, FCollect>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    topic: &str,
    limit_from: AnalyzeLimitFrom,
    include_internal: bool,
    fetch_meta: FMeta,
    collect: FCollect,
) -> Result<AnalyzeTopicOutput, ToolError>
where
    FMeta: FnOnce(ClusterProfile, String) -> Result<TopicMetadata, String>,
    FCollect: FnOnce(
        ClusterProfile,
        String,
        TopicAnalysisOptions,
        Instant,
        Arc<AtomicBool>,
    ) -> Result<CollectedAnalysis, String>,
{
    Clusters::ensure_topic_allowed(topic, include_internal)?;
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let meta = fetch_meta(profile.clone(), topic.to_string())
        .map_err(|e| ToolError::Message(crate::shape::redact(&e, &profile)))?;
    ensure_topic_readable(&meta)?;

    let options = TopicAnalysisOptions {
        max_messages: Some(ctx.limits.max_analysed_messages as i64),
        sample_from_latest: matches!(limit_from, AnalyzeLimitFrom::Newest),
        value_filter: None,
        duplicate_scope: None,
        scope: Some(AnalysisScope {
            message_limit: Some(ctx.limits.max_analysed_messages as i64),
            limit_from: limit_from.into(),
            ..Default::default()
        }),
        local_schemas: None,
    };
    let deadline = Instant::now() + ctx.limits.time_budget;
    let collected = collect(
        profile.clone(),
        topic.to_string(),
        options,
        deadline,
        Arc::clone(&ctx.cancel),
    )
    .map_err(|e| ToolError::Message(crate::shape::redact(&e, &profile)))?;

    let report = collected
        .report
        .ok_or_else(|| ToolError::Message("topic analysis produced no report".into()))?;
    Ok(map_analysis_report(
        report,
        collected.stop,
        collected.scanned,
        ctx.limits.max_text_bytes,
        &ctx.limits,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn setup() -> (std::path::PathBuf, MemorySecretStore, Clusters) {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-analyze-{nanos}"));
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

    fn empty_report(topic: &str) -> TopicAnalysisReport {
        TopicAnalysisReport {
            topic: topic.into(),
            total_messages: 0,
            total_bytes: 0,
            min_message_size: 0,
            max_message_size: 0,
            avg_message_size: 0.0,
            tombstones_count: 0,
            is_compacted: false,
            null_keys_count: 0,
            partition_stats: vec![],
            hourly_distribution: vec![],
            top_keys: vec![],
            content_type_distribution: vec![],
            field_frequencies: vec![],
            scan_duration_ms: 0,
            message_size_percentiles: None,
            size_percentiles_estimated: false,
            estimated_distinct_keys: 0,
            key_cardinality_capped: false,
            hourly_timeline: vec![],
            scan_reference_time_ms: None,
            complete_from_ms: None,
            timeline_outside_count: 0,
            value_filter_result: None,
            duplicate_analysis_result: None,
            cleanup_policy_unknown: false,
            scan_scope: None,
            analysis_limits: None,
            tracked_field_count: None,
            complete_until_ms: None,
        }
    }

    #[test]
    fn samples_are_capped() {
        let (dir, store, clusters) = setup();
        let mut limits = Limits::defaults();
        limits.max_text_bytes = 4;
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits,
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let mut report = empty_report("orders");
        report.total_messages = 1;
        report.top_keys = vec![KeyOccurrence {
            key: "abcdef".into(),
            count: 1,
            percentage: 100.0,
        }];
        report.field_frequencies = vec![FieldOccurrence {
            field_name: "status".into(),
            count: 1,
            percentage: 100.0,
            top_values: vec![FieldValueOccurrence {
                value: "READY!".into(),
                count: 1,
                percentage: 100.0,
                truncated: false,
            }],
            values_capped: false,
        }];
        let out = kafka_analyze_topic_with(
            &ctx,
            Some("local"),
            "orders",
            AnalyzeLimitFrom::Newest,
            false,
            |_, t| Ok(ok_meta(&t)),
            move |_, _, options, _, _| {
                assert!(options.value_filter.is_none());
                assert!(options.duplicate_scope.is_none());
                Ok(CollectedAnalysis {
                    report: Some(report.clone()),
                    stop: CollectStop::Complete,
                    scanned: Some(1),
                })
            },
        )
        .unwrap();
        assert_eq!(out.top_keys[0].key.text, "abcd");
        assert_eq!(out.top_keys[0].key.original_size, Some(6));
        assert_eq!(out.field_frequencies[0].top_values[0].value.text, "READ");
        assert_eq!(
            out.field_frequencies[0].top_values[0].value.original_size,
            Some(6)
        );
        assert!(!out.partial);
        let _ = fs::remove_dir_all(&dir);
    }
}
