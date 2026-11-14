use crate::consumer_group_protocol::TopicPartition;
use crate::kafka_types::{ConsumerGroupMember, PartitionLagStatus, TopicPartitionLag};
use std::collections::{HashMap, HashSet};

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum GroupLagTotal {
    Known(i64),
    NoCommittedOffsets,
    Unknown(String),
}

pub fn calculate_lag(high_offset: i64, current_offset: i64) -> i64 {
    if high_offset >= current_offset {
        high_offset - current_offset
    } else {
        0
    }
}

/// Classifies a single topic-partition's lag from its optional committed offset
/// and log-end watermark result. Non-`Known` rows use `current_offset = -1`
/// and `lag = 0` placeholders so additive bridge DTOs stay non-nullable.
pub fn classify_partition(
    topic: &str,
    partition: i32,
    committed: Option<i64>,
    log_end: Result<i64, String>,
) -> TopicPartitionLag {
    match committed {
        None => TopicPartitionLag {
            topic: topic.to_string(),
            partition,
            log_end_offset: log_end.as_ref().copied().unwrap_or(-1),
            current_offset: -1,
            lag: 0,
            status: PartitionLagStatus::NoCommit,
            error: log_end.err(),
        },
        Some(current_offset) => match log_end {
            Ok(high_offset) => TopicPartitionLag {
                topic: topic.to_string(),
                partition,
                log_end_offset: high_offset,
                current_offset,
                lag: calculate_lag(high_offset, current_offset),
                status: PartitionLagStatus::Known,
                error: None,
            },
            Err(reason) => TopicPartitionLag {
                topic: topic.to_string(),
                partition,
                log_end_offset: -1,
                current_offset: -1,
                lag: 0,
                status: PartitionLagStatus::Unknown,
                error: Some(reason),
            },
        },
    }
}

/// Aggregates partition lags into a group-level total. Any group error or
/// `Unknown` partition yields `GroupLagTotal::Unknown`; `NoCommit` partitions
/// are excluded from the sum.
pub fn group_total(partition_lags: &[TopicPartitionLag], lag_error: Option<&str>) -> GroupLagTotal {
    if let Some(reason) = lag_error {
        return GroupLagTotal::Unknown(reason.to_string());
    }

    if let Some(unknown) = partition_lags
        .iter()
        .find(|p| p.status == PartitionLagStatus::Unknown)
    {
        return GroupLagTotal::Unknown(
            unknown
                .error
                .clone()
                .unwrap_or_else(|| "Unknown partition lag".to_string()),
        );
    }

    let mut sum: i64 = 0;
    let mut known_count: usize = 0;
    for p in partition_lags {
        if p.status == PartitionLagStatus::Known {
            sum += p.lag;
            known_count += 1;
        }
    }

    if known_count == 0 {
        GroupLagTotal::NoCommittedOffsets
    } else {
        GroupLagTotal::Known(sum)
    }
}

pub fn no_commit_count(partition_lags: &[TopicPartitionLag]) -> usize {
    partition_lags
        .iter()
        .filter(|p| p.status == PartitionLagStatus::NoCommit)
        .count()
}

/// Computes partitions of subscribed topics not owned by any member. Returns
/// `None` when ownership cannot be determined (no members or any member has an
/// undecodable assignment).
pub fn unassigned_partitions(
    topic_partitions: &HashMap<String, Vec<i32>>,
    members: &[ConsumerGroupMember],
) -> Option<Vec<TopicPartition>> {
    if members.is_empty() || members.iter().any(|m| !m.assignment_decodable) {
        return None;
    }

    let owned: HashSet<(String, i32)> = members
        .iter()
        .flat_map(|m| m.assignments.iter().map(|a| (a.topic.clone(), a.partition)))
        .collect();

    let mut result: Vec<TopicPartition> = topic_partitions
        .iter()
        .flat_map(|(topic, partitions)| {
            partitions
                .iter()
                .filter(|p| !owned.contains(&(topic.clone(), **p)))
                .map(|p| TopicPartition {
                    topic: topic.clone(),
                    partition: *p,
                })
        })
        .collect();

    result.sort_by(|a, b| a.topic.cmp(&b.topic).then(a.partition.cmp(&b.partition)));
    Some(result)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn classify_partition_known_lag() {
        let p = classify_partition("orders", 0, Some(100), Ok(150));
        assert_eq!(p.status, PartitionLagStatus::Known);
        assert_eq!(p.current_offset, 100);
        assert_eq!(p.log_end_offset, 150);
        assert_eq!(p.lag, 50);
        assert_eq!(p.error, None);
    }

    #[test]
    fn classify_partition_no_commit() {
        let p = classify_partition("orders", 1, None, Ok(150));
        assert_eq!(p.status, PartitionLagStatus::NoCommit);
        assert_eq!(p.current_offset, -1);
        assert_eq!(p.log_end_offset, 150);
        assert_eq!(p.lag, 0);
        assert_eq!(p.error, None);
    }

    #[test]
    fn classify_partition_unreadable_log_end() {
        let p = classify_partition("orders", 2, Some(10), Err("leader unavailable".to_string()));
        assert_eq!(p.status, PartitionLagStatus::Unknown);
        assert_eq!(p.current_offset, -1);
        assert_eq!(p.log_end_offset, -1);
        assert_eq!(p.lag, 0);
        assert_eq!(p.error.as_deref(), Some("leader unavailable"));
    }

    #[test]
    fn classify_partition_committed_above_log_end_clamps_to_zero() {
        let p = classify_partition("orders", 0, Some(200), Ok(150));
        assert_eq!(p.status, PartitionLagStatus::Known);
        assert_eq!(p.lag, 0);
        assert_eq!(p.current_offset, 200);
        assert_eq!(p.log_end_offset, 150);
    }

    #[test]
    fn group_total_handles_empty_mixed_and_errors() {
        assert_eq!(group_total(&[], None), GroupLagTotal::NoCommittedOffsets);

        let no_commit_only = vec![classify_partition("t", 0, None, Ok(10))];
        assert_eq!(
            group_total(&no_commit_only, None),
            GroupLagTotal::NoCommittedOffsets
        );
        assert_eq!(no_commit_count(&no_commit_only), 1);

        let mixed = vec![
            classify_partition("t", 0, Some(10), Ok(25)),
            classify_partition("t", 1, None, Ok(30)),
        ];
        assert_eq!(group_total(&mixed, None), GroupLagTotal::Known(15));
        assert_eq!(no_commit_count(&mixed), 1);

        let with_unknown = vec![
            classify_partition("t", 0, Some(10), Ok(25)),
            classify_partition("t", 1, Some(5), Err("topic not readable".to_string())),
        ];
        assert_eq!(
            group_total(&with_unknown, None),
            GroupLagTotal::Unknown("topic not readable".to_string())
        );

        assert_eq!(
            group_total(&mixed, Some("group describe denied")),
            GroupLagTotal::Unknown("group describe denied".to_string())
        );
    }

    #[test]
    fn member_without_a_decodable_assignment_is_marked() {
        let member = ConsumerGroupMember {
            member_id: "m-1".to_string(),
            client_id: "client-1".to_string(),
            client_host: "host-1".to_string(),
            subscriptions: vec!["orders".to_string()],
            assignments: Vec::new(),
            assignment_decodable: false,
        };

        let partitions = HashMap::from([("orders".to_string(), vec![0, 1])]);
        assert_eq!(unassigned_partitions(&partitions, &[member]), None);
    }

    #[test]
    fn partitions_owned_by_no_member_are_reported_once() {
        let member = ConsumerGroupMember {
            member_id: "m-1".to_string(),
            client_id: "client-1".to_string(),
            client_host: "host-1".to_string(),
            subscriptions: vec!["orders".to_string()],
            assignments: vec![TopicPartition {
                topic: "orders".to_string(),
                partition: 0,
            }],
            assignment_decodable: true,
        };

        let partitions = HashMap::from([("orders".to_string(), vec![0, 1, 2])]);
        let unowned = unassigned_partitions(&partitions, &[member]).unwrap();

        assert_eq!(unowned.len(), 2);
        assert_eq!(unowned[0].partition, 1);
    }

    #[test]
    fn no_members_returns_unknown_ownership() {
        let partitions = HashMap::from([("orders".to_string(), vec![0, 1])]);
        assert_eq!(unassigned_partitions(&partitions, &[]), None);
    }
}
