use crate::api::kafka_types::ClusterProfile;
use anyhow::Result;

#[derive(Debug, Clone)]
pub struct TopicMetadata {
    pub name: String,
    pub partition_count: i32,
    pub replication_factor: i32,
    pub cleanup_policy: Option<String>,
    pub retention_ms: Option<String>,
    /// `None` when the broker gave no usable partition list for this topic.
    pub under_replicated_partitions: Option<i32>,
    pub leaderless_partitions: Option<i32>,
}

/// One partition of one topic, with the health flags already decided in Rust so
/// the Dart side never has to re-implement the classification.
#[derive(Debug, Clone)]
pub struct PartitionRow {
    pub partition: i32,
    pub leader: Option<i32>,
    pub replicas: Vec<i32>,
    pub in_sync_replicas: Vec<i32>,
    pub under_replicated: bool,
    pub leaderless: bool,
}

#[derive(Debug, Clone)]
pub struct BrokerEndpoint {
    pub id: i32,
    pub host: String,
    pub port: i32,
}

#[derive(Debug, Clone)]
pub struct TopicPartitionDetails {
    pub topic: String,
    pub partitions: Vec<PartitionRow>,
    pub brokers: Vec<BrokerEndpoint>,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicMetadata> for TopicMetadata {
    fn from(meta: kafkalyzer_kafka::kafka_metadata::TopicMetadata) -> Self {
        Self {
            name: meta.name,
            partition_count: meta.partition_count,
            replication_factor: meta.replication_factor,
            cleanup_policy: meta.cleanup_policy,
            retention_ms: meta.retention_ms,
            under_replicated_partitions: meta.under_replicated_partitions,
            leaderless_partitions: meta.leaderless_partitions,
        }
    }
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails> for TopicPartitionDetails {
    fn from(details: kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails) -> Self {
        Self {
            topic: details.topic,
            partitions: details
                .partitions
                .into_iter()
                .map(|p| {
                    let under_replicated = p.is_under_replicated();
                    let leaderless = p.is_leaderless();
                    PartitionRow {
                        partition: p.partition,
                        leader: p.leader,
                        replicas: p.replicas,
                        in_sync_replicas: p.in_sync_replicas,
                        under_replicated,
                        leaderless,
                    }
                })
                .collect(),
            brokers: details
                .brokers
                .into_iter()
                .map(|b| BrokerEndpoint {
                    id: b.id,
                    host: b.host,
                    port: b.port,
                })
                .collect(),
        }
    }
}

pub fn validate_connection(profile: ClusterProfile) -> Result<bool> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::kafka_metadata::validate_connection(domain_profile)
}

pub fn fetch_topics(profile: ClusterProfile) -> Result<Vec<TopicMetadata>> {
    let domain_profile = profile.to_domain();
    let topics = kafkalyzer_kafka::kafka_metadata::fetch_topics(domain_profile)?;
    Ok(topics.into_iter().map(TopicMetadata::from).collect())
}

pub fn fetch_topic_partitions(
    profile: ClusterProfile,
    topic: String,
) -> Result<TopicPartitionDetails> {
    let domain_profile = profile.to_domain();
    let details = kafkalyzer_kafka::kafka_metadata::fetch_topic_partitions(domain_profile, topic)?;
    Ok(TopicPartitionDetails::from(details))
}

pub fn fetch_consumer_lags(
    profile: ClusterProfile,
) -> Result<Vec<crate::api::kafka_types::ConsumerGroupLag>> {
    let domain_profile = profile.to_domain();
    let group_lags = kafkalyzer_kafka::kafka_metadata::fetch_consumer_lags(domain_profile)?;
    Ok(group_lags
        .into_iter()
        .map(crate::api::kafka_types::ConsumerGroupLag::from)
        .collect())
}

pub fn fetch_consumer_groups(
    profile: ClusterProfile,
) -> Result<Vec<crate::api::kafka_types::ConsumerGroupLag>> {
    let domain_profile = profile.to_domain();
    let groups = kafkalyzer_kafka::kafka_metadata::fetch_consumer_groups(domain_profile)?;
    Ok(groups
        .into_iter()
        .map(crate::api::kafka_types::ConsumerGroupLag::from)
        .collect())
}

pub fn fetch_consumer_group_lag(
    profile: ClusterProfile,
    group_id: String,
) -> Result<crate::api::kafka_types::ConsumerGroupLag> {
    let domain_profile = profile.to_domain();
    let group_lag =
        kafkalyzer_kafka::kafka_metadata::fetch_consumer_group_lag(domain_profile, group_id)?;
    Ok(crate::api::kafka_types::ConsumerGroupLag::from(group_lag))
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_core::partition_health::PartitionMetadata;

    fn details() -> kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails {
        kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails {
            topic: "orders".to_string(),
            partitions: vec![
                PartitionMetadata {
                    partition: 0,
                    leader: Some(1),
                    replicas: vec![1, 2, 3],
                    in_sync_replicas: vec![1, 2, 3],
                },
                PartitionMetadata {
                    partition: 1,
                    leader: Some(2),
                    replicas: vec![1, 2, 3],
                    in_sync_replicas: vec![1, 2],
                },
                PartitionMetadata {
                    partition: 2,
                    leader: None,
                    replicas: vec![1, 2, 3],
                    in_sync_replicas: vec![1],
                },
            ],
            brokers: vec![kafkalyzer_kafka::kafka_metadata::BrokerEndpoint {
                id: 1,
                host: "kafka1".to_string(),
                port: 9092,
            }],
        }
    }

    #[test]
    fn partition_rows_keep_leader_replicas_and_isr() {
        let mapped = TopicPartitionDetails::from(details());

        assert_eq!(mapped.partitions.len(), 3);
        assert_eq!(mapped.partitions[0].leader, Some(1));
        assert_eq!(mapped.partitions[0].replicas, vec![1, 2, 3]);
        assert_eq!(mapped.partitions[0].in_sync_replicas, vec![1, 2, 3]);
        assert!(!mapped.partitions[0].under_replicated);
        assert_eq!(mapped.brokers[0].host, "kafka1");
    }

    #[test]
    fn partition_health_flags_are_decided_in_rust() {
        let mapped = TopicPartitionDetails::from(details());

        assert!(mapped.partitions[1].under_replicated);
        assert!(!mapped.partitions[1].leaderless);
        assert!(mapped.partitions[2].leaderless);
    }

    #[test]
    fn topic_metadata_carries_health_counters() {
        let mapped = TopicMetadata::from(kafkalyzer_kafka::kafka_metadata::TopicMetadata {
            name: "orders".to_string(),
            partition_count: 3,
            replication_factor: 3,
            cleanup_policy: None,
            retention_ms: None,
            under_replicated_partitions: Some(2),
            leaderless_partitions: Some(1),
        });

        assert_eq!(mapped.under_replicated_partitions, Some(2));
        assert_eq!(mapped.leaderless_partitions, Some(1));
    }
}
