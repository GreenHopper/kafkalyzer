use crate::api::kafka_types::TopicAnalysisReport;
use serde::{Deserialize, Serialize};

/// One aggregate metric of a comparison at the bridge boundary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricDelta {
    pub metric: String,
    pub before: Option<f64>,
    pub after: Option<f64>,
    pub absolute: Option<f64>,
    pub relative_percent: Option<f64>,
    pub comparable: bool,
}

impl From<kafkalyzer_core::report_compare::MetricDelta> for MetricDelta {
    fn from(m: kafkalyzer_core::report_compare::MetricDelta) -> Self {
        Self {
            metric: m.metric,
            before: m.before,
            after: m.after,
            absolute: m.absolute,
            relative_percent: m.relative_percent,
            comparable: m.comparable,
        }
    }
}

/// One field of the field-frequency summary at the bridge boundary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldDelta {
    pub field: String,
    pub before: Option<i64>,
    pub after: Option<i64>,
    pub added: bool,
    pub removed: bool,
    pub count_delta: Option<i64>,
}

impl From<kafkalyzer_core::report_compare::FieldDelta> for FieldDelta {
    fn from(f: kafkalyzer_core::report_compare::FieldDelta) -> Self {
        Self {
            field: f.field,
            before: f.before,
            after: f.after,
            added: f.added,
            removed: f.removed,
            count_delta: f.count_delta,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReportComparison {
    pub topic: String,
    pub metrics: Vec<MetricDelta>,
    pub fields: Vec<FieldDelta>,
}

impl From<kafkalyzer_core::report_compare::ReportComparison> for ReportComparison {
    fn from(c: kafkalyzer_core::report_compare::ReportComparison) -> Self {
        Self {
            topic: c.topic,
            metrics: c.metrics.into_iter().map(MetricDelta::from).collect(),
            fields: c.fields.into_iter().map(FieldDelta::from).collect(),
        }
    }
}

/// Compare two reports of the same topic; both may come from imported files.
pub fn compare_reports(
    before: TopicAnalysisReport,
    after: TopicAnalysisReport,
) -> ReportComparison {
    kafkalyzer_core::report_compare::compare_reports(&before.to_domain(), &after.to_domain()).into()
}

#[cfg(test)]
mod tests {
    use super::*;

    const OLD_FORMAT_REPORT: &str = r#"{
        "topic": "orders",
        "total_messages": 100,
        "total_bytes": 10000,
        "min_message_size": 10,
        "max_message_size": 500,
        "avg_message_size": 100.0,
        "tombstones_count": 0,
        "is_compacted": false,
        "null_keys_count": 0,
        "partition_stats": [],
        "hourly_distribution": [],
        "top_keys": [],
        "content_type_distribution": [],
        "field_frequencies": [],
        "scan_duration_ms": 500
    }"#;

    fn report(messages: i64) -> TopicAnalysisReport {
        TopicAnalysisReport {
            topic: "orders".to_string(),
            total_messages: messages,
            total_bytes: messages * 100,
            min_message_size: 10,
            max_message_size: 500,
            avg_message_size: 100.0,
            tombstones_count: 0,
            is_compacted: false,
            null_keys_count: 0,
            partition_stats: vec![],
            hourly_distribution: vec![],
            top_keys: vec![],
            content_type_distribution: vec![],
            field_frequencies: vec![],
            scan_duration_ms: 500,
            message_size_percentiles: Some(crate::api::kafka_types::SizePercentiles {
                p50: 20,
                p95: 300,
                p99: 450,
            }),
            size_percentiles_estimated: false,
            estimated_distinct_keys: 7,
            key_cardinality_capped: false,
        }
    }

    #[test]
    fn a_report_written_without_the_new_fields_still_imports() {
        let imported: TopicAnalysisReport = serde_json::from_str(OLD_FORMAT_REPORT).unwrap();
        assert!(imported.message_size_percentiles.is_none());
        assert!(!imported.size_percentiles_estimated);
        assert_eq!(imported.estimated_distinct_keys, 0);
        assert!(!imported.key_cardinality_capped);
    }

    #[test]
    fn an_old_report_compares_with_its_missing_metrics_marked_unavailable() {
        let old: TopicAnalysisReport = serde_json::from_str(OLD_FORMAT_REPORT).unwrap();
        let comparison = compare_reports(old, report(120));

        let shared = comparison
            .metrics
            .iter()
            .find(|m| m.metric == "total_messages")
            .unwrap();
        assert!(shared.comparable);
        assert_eq!(shared.absolute, Some(20.0));

        let p95 = comparison
            .metrics
            .iter()
            .find(|m| m.metric == "size_p95")
            .unwrap();
        assert!(!p95.comparable);
        assert_eq!(p95.absolute, None);
    }
}
