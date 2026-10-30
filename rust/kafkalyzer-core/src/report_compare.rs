//! Comparison of two analysis reports of the same topic.
//!
//! The comparison works on whatever both reports provide: a metric one report
//! does not carry (for example size percentiles from a file written by an older
//! version) is marked not comparable instead of being counted as zero.

use crate::kafka_types::TopicAnalysisReport;
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

/// One aggregate metric of the two reports plus its difference.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MetricDelta {
    /// Stable metric key; the UI supplies the localized label.
    pub metric: String,
    pub before: Option<f64>,
    pub after: Option<f64>,
    pub absolute: Option<f64>,
    pub relative_percent: Option<f64>,
    /// False when one side does not carry the metric at all.
    pub comparable: bool,
}

/// One field of the field-frequency summary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldDelta {
    pub field: String,
    pub before: Option<i64>,
    pub after: Option<i64>,
    pub added: bool,
    pub removed: bool,
    pub count_delta: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReportComparison {
    pub topic: String,
    pub metrics: Vec<MetricDelta>,
    pub fields: Vec<FieldDelta>,
}

/// Compare `before` against `after`. Nothing here depends on the cluster the
/// reports were recorded on, so the same topic stays comparable across clusters.
pub fn compare_reports(
    before: &TopicAnalysisReport,
    after: &TopicAnalysisReport,
) -> ReportComparison {
    let mut metrics = vec![
        delta(
            "total_messages",
            Some(before.total_messages as f64),
            Some(after.total_messages as f64),
        ),
        delta(
            "total_bytes",
            Some(before.total_bytes as f64),
            Some(after.total_bytes as f64),
        ),
        delta(
            "avg_message_size",
            Some(before.avg_message_size),
            Some(after.avg_message_size),
        ),
        delta(
            "min_message_size",
            Some(before.min_message_size as f64),
            Some(after.min_message_size as f64),
        ),
        delta(
            "max_message_size",
            Some(before.max_message_size as f64),
            Some(after.max_message_size as f64),
        ),
        delta(
            "tombstones",
            Some(before.tombstones_count as f64),
            Some(after.tombstones_count as f64),
        ),
        delta(
            "null_keys",
            Some(before.null_keys_count as f64),
            Some(after.null_keys_count as f64),
        ),
        delta(
            "distinct_keys",
            Some(before.estimated_distinct_keys as f64),
            Some(after.estimated_distinct_keys as f64),
        ),
        delta(
            "busiest_partition_share",
            busiest_partition_share(before),
            busiest_partition_share(after),
        ),
    ];

    for (key, pick) in [
        (
            "size_p50",
            pick_p50 as fn(&crate::size_stats::SizePercentiles) -> f64,
        ),
        (
            "size_p95",
            pick_p95 as fn(&crate::size_stats::SizePercentiles) -> f64,
        ),
        (
            "size_p99",
            pick_p99 as fn(&crate::size_stats::SizePercentiles) -> f64,
        ),
    ] {
        metrics.push(delta(
            key,
            before.message_size_percentiles.as_ref().map(pick),
            after.message_size_percentiles.as_ref().map(pick),
        ));
    }

    ReportComparison {
        topic: after.topic.clone(),
        metrics,
        fields: field_deltas(before, after),
    }
}

fn delta(metric: &str, before: Option<f64>, after: Option<f64>) -> MetricDelta {
    let comparable = before.is_some() && after.is_some();
    let absolute = match (before, after) {
        (Some(b), Some(a)) => Some(a - b),
        _ => None,
    };
    let relative_percent = match (before, after) {
        (Some(b), Some(a)) if b != 0.0 => Some((a - b) / b * 100.0),
        (Some(0.0), Some(0.0)) => Some(0.0),
        _ => None,
    };
    MetricDelta {
        metric: metric.to_string(),
        before,
        after,
        absolute,
        relative_percent,
        comparable,
    }
}

fn pick_p50(p: &crate::size_stats::SizePercentiles) -> f64 {
    p.p50 as f64
}

fn pick_p95(p: &crate::size_stats::SizePercentiles) -> f64 {
    p.p95 as f64
}

fn pick_p99(p: &crate::size_stats::SizePercentiles) -> f64 {
    p.p99 as f64
}

/// Share of the messages held by the busiest partition, in percent.
fn busiest_partition_share(report: &TopicAnalysisReport) -> Option<f64> {
    if report.partition_stats.is_empty() || report.total_messages <= 0 {
        return None;
    }
    let busiest = report
        .partition_stats
        .iter()
        .map(|p| p.message_count)
        .max()?;
    Some(busiest as f64 / report.total_messages as f64 * 100.0)
}

fn field_deltas(before: &TopicAnalysisReport, after: &TopicAnalysisReport) -> Vec<FieldDelta> {
    let before_counts: std::collections::HashMap<&str, i64> = before
        .field_frequencies
        .iter()
        .map(|f| (f.field_name.as_str(), f.count))
        .collect();
    let after_counts: std::collections::HashMap<&str, i64> = after
        .field_frequencies
        .iter()
        .map(|f| (f.field_name.as_str(), f.count))
        .collect();

    let names: BTreeSet<&str> = before_counts
        .keys()
        .chain(after_counts.keys())
        .copied()
        .collect();

    names
        .into_iter()
        .map(|name| {
            let b = before_counts.get(name).copied();
            let a = after_counts.get(name).copied();
            FieldDelta {
                field: name.to_string(),
                before: b,
                after: a,
                added: b.is_none() && a.is_some(),
                removed: a.is_none() && b.is_some(),
                count_delta: match (b, a) {
                    (Some(b), Some(a)) => Some(a - b),
                    _ => None,
                },
            }
        })
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kafka_types::{FieldOccurrence, PartitionAnalysis};
    use crate::size_stats::SizePercentiles;

    fn report(topic: &str, messages: i64, fields: &[&str]) -> TopicAnalysisReport {
        TopicAnalysisReport {
            topic: topic.to_string(),
            total_messages: messages,
            total_bytes: messages * 100,
            min_message_size: 10,
            max_message_size: 1_000,
            avg_message_size: 100.0,
            tombstones_count: 0,
            is_compacted: false,
            null_keys_count: 0,
            partition_stats: vec![PartitionAnalysis {
                partition: 0,
                message_count: messages,
                byte_size: messages * 100,
                percentage: 100.0,
                earliest_offset: 0,
                latest_offset: messages,
            }],
            hourly_distribution: vec![],
            top_keys: vec![],
            content_type_distribution: vec![],
            field_frequencies: fields
                .iter()
                .map(|f| FieldOccurrence {
                    field_name: f.to_string(),
                    count: messages,
                    percentage: 100.0,
                    top_values: vec![],
                    values_capped: false,
                })
                .collect(),
            scan_duration_ms: 1_000,
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
        }
    }

    fn metric<'a>(c: &'a ReportComparison, key: &str) -> &'a MetricDelta {
        c.metrics.iter().find(|m| m.metric == key).unwrap()
    }

    #[test]
    fn a_volume_growth_of_twenty_percent_is_reported_as_such() {
        let comparison = compare_reports(
            &report("orders", 100_000, &[]),
            &report("orders", 120_000, &[]),
        );
        let messages = metric(&comparison, "total_messages");
        assert_eq!(messages.before, Some(100_000.0));
        assert_eq!(messages.after, Some(120_000.0));
        assert_eq!(messages.absolute, Some(20_000.0));
        assert_eq!(messages.relative_percent, Some(20.0));
        assert!(messages.comparable);
    }

    #[test]
    fn a_metric_missing_on_one_side_is_marked_not_comparable() {
        let mut after = report("orders", 100, &[]);
        after.message_size_percentiles = Some(SizePercentiles {
            p50: 10,
            p95: 90,
            p99: 99,
        });
        let comparison = compare_reports(&report("orders", 100, &[]), &after);

        let p95 = metric(&comparison, "size_p95");
        assert!(!p95.comparable);
        assert_eq!(p95.before, None);
        assert_eq!(p95.after, Some(90.0));
        assert_eq!(p95.absolute, None);

        // The shared metrics still compare.
        assert!(metric(&comparison, "total_messages").comparable);
        assert!(metric(&comparison, "total_bytes").comparable);
    }

    #[test]
    fn added_and_removed_fields_are_listed_and_shared_fields_show_counts() {
        let before = report("orders", 10, &["id", "status"]);
        let after = report("orders", 10, &["status", "carrier"]);
        let comparison = compare_reports(&before, &after);

        let added = comparison
            .fields
            .iter()
            .find(|f| f.field == "carrier")
            .unwrap();
        assert!(added.added && !added.removed);
        assert_eq!(added.count_delta, None);

        let removed = comparison.fields.iter().find(|f| f.field == "id").unwrap();
        assert!(removed.removed && !removed.added);

        let shared = comparison
            .fields
            .iter()
            .find(|f| f.field == "status")
            .unwrap();
        assert!(!shared.added && !shared.removed);
        assert_eq!(shared.count_delta, Some(0));
    }

    #[test]
    fn reports_from_two_clusters_of_the_same_topic_stay_comparable() {
        // The core report carries no cluster; the file envelope adds it, so the
        // comparison itself never blocks across clusters.
        let comparison = compare_reports(&report("orders", 500, &[]), &report("orders", 400, &[]));
        assert_eq!(comparison.topic, "orders");
        let messages = metric(&comparison, "total_messages");
        assert_eq!(messages.absolute, Some(-100.0));
        assert_eq!(messages.relative_percent, Some(-20.0));
    }

    #[test]
    fn partition_balance_compares_the_busiest_partition_share() {
        let mut skewed = report("orders", 100, &[]);
        skewed.total_messages = 200;
        skewed.partition_stats.push(PartitionAnalysis {
            partition: 1,
            message_count: 100,
            byte_size: 10_000,
            percentage: 50.0,
            earliest_offset: 0,
            latest_offset: 100,
        });
        let comparison = compare_reports(&report("orders", 100, &[]), &skewed);
        let balance = metric(&comparison, "busiest_partition_share");
        assert_eq!(balance.before, Some(100.0));
        assert_eq!(balance.after, Some(50.0));
    }

    #[test]
    fn a_zero_baseline_does_not_produce_a_relative_number() {
        let comparison = compare_reports(&report("orders", 0, &[]), &report("orders", 50, &[]));
        let messages = metric(&comparison, "total_messages");
        assert_eq!(messages.absolute, Some(50.0));
        assert_eq!(messages.relative_percent, None);
    }
}
