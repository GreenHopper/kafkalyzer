use serde::{Deserialize, Serialize};

/// One partition exactly as the broker reported it.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct PartitionMetadata {
    pub partition: i32,
    /// `None` when the broker reports no leader for this partition.
    pub leader: Option<i32>,
    pub replicas: Vec<i32>,
    pub in_sync_replicas: Vec<i32>,
}

impl PartitionMetadata {
    pub fn is_leaderless(&self) -> bool {
        self.leader.is_none()
    }

    pub fn is_under_replicated(&self) -> bool {
        self.in_sync_replicas.len() < self.replicas.len()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct TopicHealth {
    pub under_replicated_partitions: i32,
    pub leaderless_partitions: i32,
}

/// Count the unhealthy partitions of one topic. `None` means the broker gave no
/// usable partition list for it, which must not be shown as "zero problems".
pub fn summarize_topic_health(partitions: &[PartitionMetadata]) -> Option<TopicHealth> {
    if partitions.is_empty() {
        return None;
    }

    Some(TopicHealth {
        under_replicated_partitions: partitions
            .iter()
            .filter(|p| p.is_under_replicated())
            .count() as i32,
        leaderless_partitions: partitions.iter().filter(|p| p.is_leaderless()).count() as i32,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn partition(id: i32, leader: Option<i32>, replicas: &[i32], isr: &[i32]) -> PartitionMetadata {
        PartitionMetadata {
            partition: id,
            leader,
            replicas: replicas.to_vec(),
            in_sync_replicas: isr.to_vec(),
        }
    }

    #[test]
    fn replica_missing_from_isr_is_under_replicated() {
        let p = partition(0, Some(1), &[1, 2, 3], &[1, 2]);
        assert!(p.is_under_replicated());
        assert!(!p.is_leaderless());
    }

    #[test]
    fn partition_without_leader_is_leaderless() {
        let p = partition(1, None, &[1, 2], &[1, 2]);
        assert!(p.is_leaderless());
        assert!(!p.is_under_replicated());
    }

    #[test]
    fn health_counts_only_the_broken_partitions() {
        let partitions = vec![
            partition(0, Some(1), &[1, 2, 3], &[1, 2, 3]),
            partition(1, Some(2), &[1, 2, 3], &[1, 2]),
            partition(2, None, &[1, 2, 3], &[1]),
        ];

        let health = summarize_topic_health(&partitions).unwrap();
        assert_eq!(health.under_replicated_partitions, 2);
        assert_eq!(health.leaderless_partitions, 1);
    }

    #[test]
    fn fully_replicated_topic_counts_zero() {
        let partitions = vec![
            partition(0, Some(1), &[1, 2], &[1, 2]),
            partition(1, Some(2), &[1, 2], &[1, 2]),
        ];

        let health = summarize_topic_health(&partitions).unwrap();
        assert_eq!(health.under_replicated_partitions, 0);
        assert_eq!(health.leaderless_partitions, 0);
    }

    #[test]
    fn missing_partition_metadata_is_not_reported_as_healthy() {
        assert_eq!(summarize_topic_health(&[]), None);
    }
}
