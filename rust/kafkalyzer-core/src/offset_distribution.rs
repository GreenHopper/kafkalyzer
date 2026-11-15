use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum WatermarkRead {
    Known { low: i64, high: i64 },
    NotReadable(String),
    Failed(String),
    TimedOut,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PartitionWatermarks {
    pub partition: i32,
    pub read: WatermarkRead,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SkewSkipReason {
    SinglePartition,
    Incomplete,
    Empty,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum SkewStatus {
    NotRequested,
    NotEvaluated(SkewSkipReason),
    Balanced,
    Skewed(Vec<i32>),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct PartitionShare {
    pub partition: i32,
    pub read: WatermarkRead,
    pub span: Option<i64>,
    pub share_percent: Option<f64>,
    pub skewed: bool,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct OffsetDistribution {
    pub rows: Vec<PartitionShare>,
    pub total_span: Option<i64>,
    pub known_span: i64,
    pub complete: bool,
    pub skew: SkewStatus,
}

pub fn summarize_offsets(
    partitions: &[PartitionWatermarks],
    skew_threshold_percent: Option<u8>,
) -> OffsetDistribution {
    let mut sorted: Vec<PartitionWatermarks> = partitions.to_vec();
    sorted.sort_by_key(|p| p.partition);

    if sorted.is_empty() {
        let skew = match skew_threshold_percent {
            None => SkewStatus::NotRequested,
            Some(_) => SkewStatus::NotEvaluated(SkewSkipReason::Incomplete),
        };
        return OffsetDistribution {
            rows: Vec::new(),
            total_span: None,
            known_span: 0,
            complete: false,
            skew,
        };
    }

    let mut complete = true;
    let mut known_sum: i128 = 0;
    let mut rows = Vec::with_capacity(sorted.length_or_len());

    for entry in sorted {
        let (read, span) = match entry.read {
            WatermarkRead::Known { low, high } => {
                if low < 0 || high < 0 || low > high {
                    complete = false;
                    (
                        WatermarkRead::Failed("invalid watermarks".to_string()),
                        None,
                    )
                } else {
                    let diff = (high as i128) - (low as i128);
                    let clamped = diff.min(i64::MAX as i128) as i64;
                    known_sum = known_sum.saturating_add(diff);
                    (WatermarkRead::Known { low, high }, Some(clamped))
                }
            }
            other => {
                complete = false;
                (other, None)
            }
        };

        rows.push(PartitionShare {
            partition: entry.partition,
            read,
            span,
            share_percent: None,
            skewed: false,
        });
    }

    let known_span = known_sum.min(i64::MAX as i128) as i64;
    let total_span = if complete { Some(known_span) } else { None };

    if complete && known_span > 0 {
        for row in &mut rows {
            if let Some(span) = row.span {
                row.share_percent = Some((span as f64 / known_span as f64) * 100.0);
            }
        }
    }

    let skew = match skew_threshold_percent {
        None => SkewStatus::NotRequested,
        Some(_) if !complete => SkewStatus::NotEvaluated(SkewSkipReason::Incomplete),
        Some(_) if rows.len() < 2 => SkewStatus::NotEvaluated(SkewSkipReason::SinglePartition),
        Some(_) if known_span == 0 => SkewStatus::NotEvaluated(SkewSkipReason::Empty),
        Some(threshold) => {
            let mut skewed_partitions = Vec::new();
            let t = threshold as i128;
            let total_i128 = known_sum;
            for row in &mut rows {
                if let Some(span) = row.span {
                    if (span as i128) * 100 > t * total_i128 {
                        row.skewed = true;
                        skewed_partitions.push(row.partition);
                    }
                }
            }
            if skewed_partitions.is_empty() {
                SkewStatus::Balanced
            } else {
                SkewStatus::Skewed(skewed_partitions)
            }
        }
    };

    OffsetDistribution {
        rows,
        total_span,
        known_span,
        complete,
        skew,
    }
}

trait VecLenExt {
    fn length_or_len(&self) -> usize;
}
impl<T> VecLenExt for Vec<T> {
    fn length_or_len(&self) -> usize {
        self.len()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn known(partition: i32, low: i64, high: i64) -> PartitionWatermarks {
        PartitionWatermarks {
            partition,
            read: WatermarkRead::Known { low, high },
        }
    }

    #[test]
    fn computes_60_40_shares_per_spec_example() {
        let dist = summarize_offsets(&[known(0, 0, 600), known(1, 100, 500)], Some(50));
        assert!(dist.complete);
        assert_eq!(dist.total_span, Some(1000));
        assert_eq!(dist.known_span, 1000);
        assert_eq!(dist.rows[0].span, Some(600));
        assert!((dist.rows[0].share_percent.unwrap() - 60.0).abs() < 1e-9);
        assert!(dist.rows[0].skewed);
        assert_eq!(dist.rows[1].span, Some(400));
        assert!((dist.rows[1].share_percent.unwrap() - 40.0).abs() < 1e-9);
        assert!(!dist.rows[1].skewed);
        assert_eq!(dist.skew, SkewStatus::Skewed(vec![0]));
    }

    #[test]
    fn empty_topic_has_zero_spans_no_shares_and_empty_skew_status() {
        let dist = summarize_offsets(&[known(0, 10, 10), known(1, 0, 0)], Some(50));
        assert!(dist.complete);
        assert_eq!(dist.total_span, Some(0));
        assert_eq!(dist.known_span, 0);
        assert_eq!(dist.rows[0].span, Some(0));
        assert_eq!(dist.rows[0].share_percent, None);
        assert_eq!(dist.rows[1].span, Some(0));
        assert_eq!(dist.rows[1].share_percent, None);
        assert_eq!(dist.skew, SkewStatus::NotEvaluated(SkewSkipReason::Empty));
    }

    #[test]
    fn unreadable_or_failed_or_timed_out_row_clears_total_and_shares_but_keeps_other_spans() {
        for err_read in [
            WatermarkRead::Failed("broker err".into()),
            WatermarkRead::NotReadable("auth err".into()),
            WatermarkRead::TimedOut,
        ] {
            let dist = summarize_offsets(
                &[
                    known(0, 0, 100),
                    PartitionWatermarks {
                        partition: 1,
                        read: err_read.clone(),
                    },
                ],
                Some(50),
            );
            assert!(!dist.complete);
            assert_eq!(dist.total_span, None);
            assert_eq!(dist.known_span, 100);
            assert_eq!(dist.rows[0].span, Some(100));
            assert_eq!(dist.rows[0].share_percent, None);
            assert_eq!(dist.rows[1].span, None);
            assert_eq!(dist.rows[1].share_percent, None);
            assert_eq!(dist.rows[1].read, err_read);
            assert_eq!(
                dist.skew,
                SkewStatus::NotEvaluated(SkewSkipReason::Incomplete)
            );
        }
    }

    #[test]
    fn invalid_watermarks_become_failed() {
        let dist = summarize_offsets(&[known(0, 50, 10), known(1, -1, 10)], Some(50));
        assert!(!dist.complete);
        assert_eq!(dist.total_span, None);
        assert!(matches!(dist.rows[0].read, WatermarkRead::Failed(_)));
        assert!(matches!(dist.rows[1].read, WatermarkRead::Failed(_)));
        assert_eq!(dist.rows[0].span, None);
        assert_eq!(dist.rows[1].span, None);
    }

    #[test]
    fn single_partition_skips_skew() {
        let dist = summarize_offsets(&[known(0, 0, 500)], Some(50));
        assert!(dist.complete);
        assert_eq!(dist.total_span, Some(500));
        assert!((dist.rows[0].share_percent.unwrap() - 100.0).abs() < 1e-9);
        assert!(!dist.rows[0].skewed);
        assert_eq!(
            dist.skew,
            SkewStatus::NotEvaluated(SkewSkipReason::SinglePartition)
        );
    }

    #[test]
    fn skew_threshold_boundary_and_balanced_cases() {
        // 700 / 200 / 100 at 50% -> partition 0 skewed
        let d1 = summarize_offsets(
            &[known(0, 0, 700), known(1, 0, 200), known(2, 0, 100)],
            Some(50),
        );
        assert_eq!(d1.skew, SkewStatus::Skewed(vec![0]));
        assert!(d1.rows[0].skewed);
        assert!(!d1.rows[1].skewed);

        // 500 / 500 at 50% -> equal to threshold, not skewed
        let d2 = summarize_offsets(&[known(0, 0, 500), known(1, 0, 500)], Some(50));
        assert_eq!(d2.skew, SkewStatus::Balanced);
        assert!(!d2.rows[0].skewed);
        assert!(!d2.rows[1].skewed);

        // 700 / 200 / 100 at 80% -> Balanced
        let d3 = summarize_offsets(
            &[known(0, 0, 700), known(1, 0, 200), known(2, 0, 100)],
            Some(80),
        );
        assert_eq!(d3.skew, SkewStatus::Balanced);

        // threshold None -> NotRequested
        let d4 = summarize_offsets(&[known(0, 0, 700), known(1, 0, 300)], None);
        assert_eq!(d4.skew, SkewStatus::NotRequested);
        assert!(!d4.rows[0].skewed);
    }

    #[test]
    fn saturates_i64_max_and_sorts_by_partition() {
        let dist = summarize_offsets(&[known(2, 0, i64::MAX), known(0, 0, i64::MAX)], Some(50));
        assert_eq!(dist.rows[0].partition, 0);
        assert_eq!(dist.rows[1].partition, 2);
        assert_eq!(dist.total_span, Some(i64::MAX));
        assert_eq!(dist.known_span, i64::MAX);
    }
}
