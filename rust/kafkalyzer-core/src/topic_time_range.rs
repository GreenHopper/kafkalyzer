#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TimestampKind {
    CreateTime,
    LogAppendTime,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProbeOutcome {
    Found {
        offset: i64,
        timestamp_ms: i64,
        timestamp_type: TimestampKind,
    },
    Empty,
    NotFoundInWindow,
    NoTimestamp,
    TimedOut,
    Unreadable(String),
    Failed(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PartitionProbe {
    pub partition: i32,
    pub oldest: ProbeOutcome,
    pub newest: ProbeOutcome,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PartitionTimestamp {
    pub partition: i32,
    pub offset: i64,
    pub timestamp_ms: i64,
    pub timestamp_type: TimestampKind,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicTimeRange {
    pub oldest: Option<PartitionTimestamp>,
    pub newest: Option<PartitionTimestamp>,
    pub partitions_total: usize,
    pub partitions_empty: usize,
    pub oldest_known: usize,
    pub newest_known: usize,
    pub all_empty: bool,
    pub probes: Vec<PartitionProbe>,
}

pub const TAIL_WINDOW: i64 = 16;

/// Returns the inclusive start offset for probing the tail `window` offsets
/// `[max(low, high - window), high)`.
pub fn tail_start_offset(low: i64, high: i64, window: i64) -> i64 {
    high.saturating_sub(window.max(0)).max(low)
}

/// Aggregates per-partition oldest/newest probe outcomes into a topic-level
/// time range summary without guessing missing or timed-out partitions.
pub fn aggregate(probes: &[PartitionProbe]) -> TopicTimeRange {
    let mut sorted = probes.to_vec();
    sorted.sort_by_key(|p| p.partition);

    let partitions_total = sorted.len();
    let mut partitions_empty = 0usize;
    let mut oldest_known = 0usize;
    let mut newest_known = 0usize;
    let mut oldest: Option<PartitionTimestamp> = None;
    let mut newest: Option<PartitionTimestamp> = None;

    for probe in &sorted {
        if matches!(probe.oldest, ProbeOutcome::Empty)
            && matches!(probe.newest, ProbeOutcome::Empty)
        {
            partitions_empty += 1;
        }

        if let ProbeOutcome::Found {
            offset,
            timestamp_ms,
            timestamp_type,
        } = probe.oldest
        {
            oldest_known += 1;
            let candidate = PartitionTimestamp {
                partition: probe.partition,
                offset,
                timestamp_ms,
                timestamp_type,
            };
            let replace = match &oldest {
                None => true,
                Some(cur) => candidate.timestamp_ms < cur.timestamp_ms,
            };
            if replace {
                oldest = Some(candidate);
            }
        }

        if let ProbeOutcome::Found {
            offset,
            timestamp_ms,
            timestamp_type,
        } = probe.newest
        {
            newest_known += 1;
            let candidate = PartitionTimestamp {
                partition: probe.partition,
                offset,
                timestamp_ms,
                timestamp_type,
            };
            let replace = match &newest {
                None => true,
                Some(cur) => candidate.timestamp_ms > cur.timestamp_ms,
            };
            if replace {
                newest = Some(candidate);
            }
        }
    }

    let all_empty = partitions_total > 0 && partitions_empty == partitions_total;

    TopicTimeRange {
        oldest,
        newest,
        partitions_total,
        partitions_empty,
        oldest_known,
        newest_known,
        all_empty,
        probes: sorted,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn found(offset: i64, timestamp_ms: i64) -> ProbeOutcome {
        ProbeOutcome::Found {
            offset,
            timestamp_ms,
            timestamp_type: TimestampKind::CreateTime,
        }
    }

    #[test]
    fn tail_start_clamps_to_low_when_window_exceeds_span() {
        assert_eq!(tail_start_offset(100, 105, 16), 100);
        assert_eq!(tail_start_offset(100, 116, 16), 100);
        assert_eq!(tail_start_offset(100, 150, 16), 134);
        assert_eq!(tail_start_offset(0, 0, 16), 0);
    }

    #[test]
    fn empty_topic_has_no_timestamps_and_zero_totals() {
        let range = aggregate(&[]);
        assert_eq!(range.partitions_total, 0);
        assert_eq!(range.partitions_empty, 0);
        assert!(!range.all_empty);
        assert_eq!(range.oldest, None);
        assert_eq!(range.newest, None);
    }

    #[test]
    fn all_partitions_empty_sets_all_empty_true() {
        let range = aggregate(&[
            PartitionProbe {
                partition: 0,
                oldest: ProbeOutcome::Empty,
                newest: ProbeOutcome::Empty,
            },
            PartitionProbe {
                partition: 1,
                oldest: ProbeOutcome::Empty,
                newest: ProbeOutcome::Empty,
            },
        ]);
        assert_eq!(range.partitions_total, 2);
        assert_eq!(range.partitions_empty, 2);
        assert!(range.all_empty);
        assert_eq!(range.oldest, None);
        assert_eq!(range.newest, None);
    }

    #[test]
    fn not_found_in_window_and_timed_out_mark_partial_counts() {
        let range = aggregate(&[
            PartitionProbe {
                partition: 0,
                oldest: found(0, 1_000),
                newest: found(50, 5_000),
            },
            PartitionProbe {
                partition: 1,
                oldest: found(0, 2_000),
                newest: ProbeOutcome::NotFoundInWindow,
            },
            PartitionProbe {
                partition: 2,
                oldest: ProbeOutcome::TimedOut,
                newest: ProbeOutcome::TimedOut,
            },
        ]);
        assert_eq!(range.partitions_total, 3);
        assert_eq!(range.oldest_known, 2);
        assert_eq!(range.newest_known, 1);
        assert!(!range.all_empty);
        assert_eq!(range.oldest.unwrap().timestamp_ms, 1_000);
        assert_eq!(range.newest.unwrap().timestamp_ms, 5_000);
    }

    #[test]
    fn no_timestamp_is_treated_as_unknown_not_epoch_zero() {
        let range = aggregate(&[
            PartitionProbe {
                partition: 0,
                oldest: ProbeOutcome::NoTimestamp,
                newest: ProbeOutcome::NoTimestamp,
            },
            PartitionProbe {
                partition: 1,
                oldest: found(10, 9_000),
                newest: found(11, 9_500),
            },
        ]);
        assert_eq!(range.oldest_known, 1);
        assert_eq!(range.newest_known, 1);
        assert_eq!(range.oldest.unwrap().timestamp_ms, 9_000);
        assert_eq!(range.newest.unwrap().timestamp_ms, 9_500);
    }

    #[test]
    fn min_and_max_across_partitions_with_non_monotonic_timestamps() {
        let range = aggregate(&[
            PartitionProbe {
                partition: 2,
                oldest: found(0, 500),
                newest: found(20, 4_000),
            },
            PartitionProbe {
                partition: 0,
                oldest: found(10, 1_200),
                newest: found(30, 8_000),
            },
        ]);
        let oldest = range.oldest.unwrap();
        assert_eq!(oldest.partition, 2);
        assert_eq!(oldest.timestamp_ms, 500);
        let newest = range.newest.unwrap();
        assert_eq!(newest.partition, 0);
        assert_eq!(newest.timestamp_ms, 8_000);
    }

    #[test]
    fn all_unknown_partitions_are_not_marked_empty() {
        let range = aggregate(&[
            PartitionProbe {
                partition: 0,
                oldest: ProbeOutcome::TimedOut,
                newest: ProbeOutcome::TimedOut,
            },
            PartitionProbe {
                partition: 1,
                oldest: ProbeOutcome::Unreadable("ACL denied".to_string()),
                newest: ProbeOutcome::Unreadable("ACL denied".to_string()),
            },
        ]);
        assert!(!range.all_empty);
        assert_eq!(range.partitions_empty, 0);
        assert_eq!(range.oldest_known, 0);
        assert_eq!(range.newest_known, 0);
        assert_eq!(range.oldest, None);
        assert_eq!(range.newest, None);
    }
}
