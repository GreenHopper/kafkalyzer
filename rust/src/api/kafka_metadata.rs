use crate::api::kafka_types::ClusterProfile;
use anyhow::Result;

#[derive(Debug, Clone)]
pub struct TopicMetadata {
    pub name: String,
    pub partition_count: i32,
    pub replication_factor: i32,
    pub cleanup_policy: Option<String>,
    pub retention_ms: Option<String>,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicMetadata> for TopicMetadata {
    fn from(meta: kafkalyzer_kafka::kafka_metadata::TopicMetadata) -> Self {
        Self {
            name: meta.name,
            partition_count: meta.partition_count,
            replication_factor: meta.replication_factor,
            cleanup_policy: meta.cleanup_policy,
            retention_ms: meta.retention_ms,
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
