use crate::offset_distribution::{PartitionWatermarks, WatermarkRead};
use serde::{Deserialize, Serialize};
use std::collections::{BTreeSet, HashMap};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ScopeLimitFrom {
    #[default]
    Newest,
    Oldest,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct AnalysisScope {
    #[serde(default)]
    pub partitions: Option<Vec<i32>>,
    #[serde(default)]
    pub start_timestamp_ms: Option<i64>,
    #[serde(default)]
    pub end_timestamp_ms: Option<i64>,
    #[serde(default)]
    pub message_limit: Option<i64>,
    #[serde(default)]
    pub limit_from: ScopeLimitFrom,
}

impl AnalysisScope {
    pub fn validate(&self) -> Result<(), String> {
        if let Some(partitions) = &self.partitions {
            if partitions.is_empty() {
                return Err("At least one partition must be selected".to_string());
            }
        }
        if let Some(start) = self.start_timestamp_ms {
            if start < 0 {
                return Err("Start timestamp must be non-negative".to_string());
            }
        }
        if let Some(end) = self.end_timestamp_ms {
            if end < 0 {
                return Err("End timestamp must be non-negative".to_string());
            }
        }
        if let (Some(start), Some(end)) = (self.start_timestamp_ms, self.end_timestamp_ms) {
            if end <= start {
                return Err("End timestamp must be after start timestamp".to_string());
            }
        }
        if let Some(limit) = self.message_limit {
            if limit <= 0 {
                return Err("Message limit must be positive".to_string());
            }
        }
        Ok(())
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TimeBound {
    Offset(i64),
    AfterEnd,
    Failed(String),
}

#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct TimeBounds {
    pub start: Option<TimeBound>,
    pub end: Option<TimeBound>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PlannedRange {
    pub partition: i32,
    pub start: i64,
    pub end: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct UnreadablePartition {
    pub partition: i32,
    pub reason: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ScanPlan {
    pub ranges: Vec<PlannedRange>,
    pub unreadable: Vec<UnreadablePartition>,
    pub planned_total: i64,
    pub complete: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct AnalysisScopeEstimate {
    pub planned_total: Option<i64>,
    pub known_total: i64,
    pub complete: bool,
    pub unreadable: Vec<UnreadablePartition>,
}

pub fn plan_scan(
    watermarks: &[PartitionWatermarks],
    time_bounds: &HashMap<i32, TimeBounds>,
    scope: &AnalysisScope,
) -> ScanPlan {
    let selected_filter: Option<BTreeSet<i32>> = scope
        .partitions
        .as_ref()
        .map(|p| p.iter().copied().collect());

    let mut ordered_watermarks: Vec<&PartitionWatermarks> = watermarks
        .iter()
        .filter(|pw| {
            selected_filter
                .as_ref()
                .is_none_or(|set| set.contains(&pw.partition))
        })
        .collect();
    ordered_watermarks.sort_by_key(|pw| pw.partition);

    let mut candidates: Vec<(i32, i64, i64)> = Vec::new();
    let mut unreadable: Vec<UnreadablePartition> = Vec::new();

    for pw in ordered_watermarks {
        let (low, high) = match &pw.read {
            WatermarkRead::Known { low, high } => (*low, (*high).max(*low)),
            WatermarkRead::NotReadable(reason) | WatermarkRead::Failed(reason) => {
                unreadable.push(UnreadablePartition {
                    partition: pw.partition,
                    reason: reason.clone(),
                });
                continue;
            }
            WatermarkRead::TimedOut => {
                unreadable.push(UnreadablePartition {
                    partition: pw.partition,
                    reason: "timed out".to_string(),
                });
                continue;
            }
        };

        let mut start = low;
        let mut end = high;

        if let Some(bounds) = time_bounds.get(&pw.partition) {
            match &bounds.start {
                Some(TimeBound::Failed(reason)) => {
                    unreadable.push(UnreadablePartition {
                        partition: pw.partition,
                        reason: reason.clone(),
                    });
                    continue;
                }
                Some(TimeBound::Offset(o)) => {
                    start = start.max(*o).min(high);
                }
                Some(TimeBound::AfterEnd) => {
                    start = high;
                }
                None => {}
            }

            match &bounds.end {
                Some(TimeBound::Failed(reason)) => {
                    unreadable.push(UnreadablePartition {
                        partition: pw.partition,
                        reason: reason.clone(),
                    });
                    continue;
                }
                Some(TimeBound::Offset(o)) => {
                    end = end.min(*o).max(low);
                }
                Some(TimeBound::AfterEnd) => {
                    end = high;
                }
                None => {}
            }
        }

        end = end.max(start);
        candidates.push((pw.partition, start, end));
    }

    if let Some(limit) = scope.message_limit {
        if limit > 0 && !candidates.is_empty() {
            let spans: Vec<i128> = candidates
                .iter()
                .map(|(_, s, e)| (*e as i128 - *s as i128).max(0))
                .collect();
            let mut quotas: Vec<i128> = vec![0; candidates.len()];
            let mut remaining: i128 = limit as i128;

            while remaining > 0 {
                let unsatisfied: Vec<usize> = (0..candidates.len())
                    .filter(|&i| quotas[i] < spans[i])
                    .collect();
                if unsatisfied.is_empty() {
                    break;
                }
                let share = remaining / (unsatisfied.len() as i128);
                if share > 0 {
                    for &i in &unsatisfied {
                        let add = share.min(spans[i] - quotas[i]);
                        quotas[i] += add;
                        remaining -= add;
                    }
                } else {
                    for &i in unsatisfied.iter().take(remaining as usize) {
                        quotas[i] += 1;
                    }
                    remaining = 0;
                }
            }

            for (i, (_, s, e)) in candidates.iter_mut().enumerate() {
                match scope.limit_from {
                    ScopeLimitFrom::Newest => {
                        let new_s =
                            (*e as i128 - quotas[i]).clamp(i64::MIN as i128, i64::MAX as i128);
                        *s = new_s as i64;
                    }
                    ScopeLimitFrom::Oldest => {
                        let new_e =
                            (*s as i128 + quotas[i]).clamp(i64::MIN as i128, i64::MAX as i128);
                        *e = new_e as i64;
                    }
                }
            }
        }
    }

    let ranges: Vec<PlannedRange> = candidates
        .into_iter()
        .map(|(partition, start, end)| PlannedRange {
            partition,
            start,
            end,
        })
        .collect();

    let planned_total_i128 = ranges.iter().fold(0i128, |acc, r| {
        acc.saturating_add((r.end as i128 - r.start as i128).max(0))
    });
    let planned_total = planned_total_i128.min(i64::MAX as i128) as i64;
    let complete = unreadable.is_empty();

    ScanPlan {
        ranges,
        unreadable,
        planned_total,
        complete,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kafka_types::TopicAnalysisOptions;

    fn known(p: i32, low: i64, high: i64) -> PartitionWatermarks {
        PartitionWatermarks {
            partition: p,
            read: WatermarkRead::Known { low, high },
        }
    }

    #[test]
    fn default_scope_is_full_scan_of_all_partitions() {
        let wms = vec![known(0, 10, 100), known(1, 0, 50)];
        let plan = plan_scan(&wms, &HashMap::new(), &AnalysisScope::default());
        assert!(plan.complete);
        assert_eq!(plan.planned_total, 140);
        assert_eq!(
            plan.ranges,
            vec![
                PlannedRange {
                    partition: 0,
                    start: 10,
                    end: 100
                },
                PlannedRange {
                    partition: 1,
                    start: 0,
                    end: 50
                },
            ]
        );
    }

    #[test]
    fn time_range_and_open_ended_and_after_end() {
        let wms = vec![known(0, 0, 100), known(1, 0, 50)];
        let mut bounds = HashMap::new();
        bounds.insert(
            0,
            TimeBounds {
                start: Some(TimeBound::Offset(20)),
                end: Some(TimeBound::Offset(80)),
            },
        );
        bounds.insert(
            1,
            TimeBounds {
                start: Some(TimeBound::AfterEnd),
                end: None,
            },
        );
        let scope = AnalysisScope {
            start_timestamp_ms: Some(1000),
            end_timestamp_ms: Some(2000),
            ..Default::default()
        };
        let plan = plan_scan(&wms, &bounds, &scope);
        assert!(plan.complete);
        assert!(plan.unreadable.is_empty());
        assert_eq!(plan.planned_total, 60);
        assert_eq!(
            plan.ranges,
            vec![
                PlannedRange {
                    partition: 0,
                    start: 20,
                    end: 80
                },
                PlannedRange {
                    partition: 1,
                    start: 50,
                    end: 50
                },
            ]
        );
    }

    #[test]
    fn both_bounds_after_end_yields_empty_not_unreadable() {
        let wms = vec![known(0, 10, 50)];
        let mut bounds = HashMap::new();
        bounds.insert(
            0,
            TimeBounds {
                start: Some(TimeBound::AfterEnd),
                end: Some(TimeBound::AfterEnd),
            },
        );
        let plan = plan_scan(&wms, &bounds, &AnalysisScope::default());
        assert!(plan.complete);
        assert_eq!(plan.planned_total, 0);
        assert_eq!(
            plan.ranges,
            vec![PlannedRange {
                partition: 0,
                start: 50,
                end: 50
            }]
        );
    }

    #[test]
    fn partition_subset_selects_only_requested() {
        let wms = (0..6).map(|p| known(p, 0, 100)).collect::<Vec<_>>();
        let scope = AnalysisScope {
            partitions: Some(vec![3, 0]),
            ..Default::default()
        };
        let plan = plan_scan(&wms, &HashMap::new(), &scope);
        assert!(plan.complete);
        assert_eq!(plan.planned_total, 200);
        assert_eq!(
            plan.ranges,
            vec![
                PlannedRange {
                    partition: 0,
                    start: 0,
                    end: 100
                },
                PlannedRange {
                    partition: 3,
                    start: 0,
                    end: 100
                },
            ]
        );
    }

    #[test]
    fn newest_10k_across_4_equal_partitions_gives_2500_each() {
        let wms = (0..4).map(|p| known(p, 0, 10_000)).collect::<Vec<_>>();
        let scope = AnalysisScope {
            message_limit: Some(10_000),
            limit_from: ScopeLimitFrom::Newest,
            ..Default::default()
        };
        let plan = plan_scan(&wms, &HashMap::new(), &scope);
        assert_eq!(plan.planned_total, 10_000);
        for p in 0..4 {
            assert_eq!(
                plan.ranges[p],
                PlannedRange {
                    partition: p as i32,
                    start: 7_500,
                    end: 10_000
                }
            );
        }
    }

    #[test]
    fn water_filling_redistributes_from_small_partition() {
        let wms = vec![known(0, 0, 1_000), known(1, 0, 50_000)];
        let scope = AnalysisScope {
            message_limit: Some(10_000),
            limit_from: ScopeLimitFrom::Newest,
            ..Default::default()
        };
        let plan = plan_scan(&wms, &HashMap::new(), &scope);
        assert_eq!(plan.planned_total, 10_000);
        assert_eq!(
            plan.ranges,
            vec![
                PlannedRange {
                    partition: 0,
                    start: 0,
                    end: 1_000
                },
                PlannedRange {
                    partition: 1,
                    start: 41_000,
                    end: 50_000
                },
            ]
        );
    }

    #[test]
    fn oldest_message_count() {
        let wms = vec![known(0, 500, 100_000)];
        let scope = AnalysisScope {
            message_limit: Some(5_000),
            limit_from: ScopeLimitFrom::Oldest,
            ..Default::default()
        };
        let plan = plan_scan(&wms, &HashMap::new(), &scope);
        assert_eq!(plan.planned_total, 5_000);
        assert_eq!(
            plan.ranges,
            vec![PlannedRange {
                partition: 0,
                start: 500,
                end: 5_500
            }]
        );
    }

    #[test]
    fn count_combined_with_time_range() {
        let wms = vec![known(0, 0, 100_000)];
        let mut bounds = HashMap::new();
        bounds.insert(
            0,
            TimeBounds {
                start: Some(TimeBound::Offset(10_000)),
                end: Some(TimeBound::Offset(25_000)),
            },
        );
        let scope = AnalysisScope {
            start_timestamp_ms: Some(1000),
            end_timestamp_ms: Some(2000),
            message_limit: Some(1_000),
            limit_from: ScopeLimitFrom::Newest,
            ..Default::default()
        };
        let plan = plan_scan(&wms, &bounds, &scope);
        assert_eq!(plan.planned_total, 1_000);
        assert_eq!(
            plan.ranges,
            vec![PlannedRange {
                partition: 0,
                start: 24_000,
                end: 25_000
            }]
        );
    }

    #[test]
    fn invalid_scopes_rejected() {
        assert!(AnalysisScope {
            start_timestamp_ms: Some(2000),
            end_timestamp_ms: Some(1000),
            ..Default::default()
        }
        .validate()
        .is_err());
        assert!(AnalysisScope {
            start_timestamp_ms: Some(1000),
            end_timestamp_ms: Some(1000),
            ..Default::default()
        }
        .validate()
        .is_err());
        assert!(AnalysisScope {
            message_limit: Some(0),
            ..Default::default()
        }
        .validate()
        .is_err());
        assert!(AnalysisScope {
            message_limit: Some(-5),
            ..Default::default()
        }
        .validate()
        .is_err());
        assert!(AnalysisScope {
            partitions: Some(vec![]),
            ..Default::default()
        }
        .validate()
        .is_err());
        assert!(AnalysisScope {
            start_timestamp_ms: Some(-1),
            ..Default::default()
        }
        .validate()
        .is_err());
    }

    #[test]
    fn empty_topic_low_eq_high_limit_gt_total_and_unreadable() {
        let wms = vec![
            known(0, 50, 50),
            PartitionWatermarks {
                partition: 1,
                read: WatermarkRead::NotReadable("ACL denied".to_string()),
            },
            PartitionWatermarks {
                partition: 2,
                read: WatermarkRead::TimedOut,
            },
        ];
        let scope = AnalysisScope {
            message_limit: Some(1_000),
            ..Default::default()
        };
        let plan = plan_scan(&wms, &HashMap::new(), &scope);
        assert!(!plan.complete);
        assert_eq!(plan.planned_total, 0);
        assert_eq!(plan.ranges.len(), 1);
        assert_eq!(plan.unreadable.len(), 2);
        assert_eq!(plan.unreadable[0].partition, 1);
        assert_eq!(plan.unreadable[1].partition, 2);
    }

    #[test]
    fn failed_time_bound_marks_partition_unreadable() {
        let wms = vec![known(0, 0, 100)];
        let mut bounds = HashMap::new();
        bounds.insert(
            0,
            TimeBounds {
                start: Some(TimeBound::Failed("broker error".to_string())),
                end: None,
            },
        );
        let plan = plan_scan(&wms, &bounds, &AnalysisScope::default());
        assert!(!plan.complete);
        assert!(plan.ranges.is_empty());
        assert_eq!(
            plan.unreadable,
            vec![UnreadablePartition {
                partition: 0,
                reason: "broker error".to_string()
            }]
        );
    }

    #[test]
    fn planned_total_saturates_at_i64_max() {
        let wms = vec![known(0, 0, i64::MAX), known(1, 0, i64::MAX)];
        let plan = plan_scan(&wms, &HashMap::new(), &AnalysisScope::default());
        assert_eq!(plan.planned_total, i64::MAX);
    }

    #[test]
    fn legacy_options_map_sample_from_latest_false_to_oldest() {
        let opts = TopicAnalysisOptions {
            max_messages: Some(500),
            sample_from_latest: false,
            ..Default::default()
        };
        let eff = opts.effective_scope();
        assert_eq!(eff.message_limit, Some(500));
        assert_eq!(eff.limit_from, ScopeLimitFrom::Oldest);
    }
}
