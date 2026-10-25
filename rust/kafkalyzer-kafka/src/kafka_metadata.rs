use crate::kafka_utils::create_config;
use anyhow::Result;
use kafkalyzer_core::consumer_group_protocol::{
    parse_assignment, parse_subscription, TopicPartition,
};
use kafkalyzer_core::kafka_types::{ClusterProfile, ConsumerGroupMember};
use kafkalyzer_core::partition_health::{summarize_topic_health, PartitionMetadata};
use rdkafka::admin::{AdminClient, AdminOptions, OwnedResourceSpecifier, ResourceSpecifier};
use rdkafka::client::DefaultClientContext;
use rdkafka::consumer::{BaseConsumer, Consumer};
use tokio::runtime::Runtime;

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

#[derive(Debug, Clone)]
pub struct BrokerEndpoint {
    pub id: i32,
    pub host: String,
    pub port: i32,
}

#[derive(Debug, Clone)]
pub struct TopicPartitionDetails {
    pub topic: String,
    pub partitions: Vec<PartitionMetadata>,
    pub brokers: Vec<BrokerEndpoint>,
}

fn partition_metadata(p: &rdkafka::metadata::MetadataPartition) -> PartitionMetadata {
    PartitionMetadata {
        partition: p.id(),
        // Kafka reports "no leader" as -1.
        leader: if p.leader() >= 0 {
            Some(p.leader())
        } else {
            None
        },
        replicas: p.replicas().to_vec(),
        in_sync_replicas: p.isr().to_vec(),
    }
}

pub fn validate_connection(profile: ClusterProfile) -> Result<bool> {
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;

    let _ = consumer.fetch_metadata(None, std::time::Duration::from_secs(5))?;
    Ok(true)
}

pub fn fetch_topics(profile: ClusterProfile) -> Result<Vec<TopicMetadata>> {
    let config = create_config(&profile);

    // Create Consumer for Metadata
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer.fetch_metadata(None, std::time::Duration::from_secs(10))?;

    // Create Admin Client for Configs
    // AdminClient requires async, so we need a runtime
    let rt = Runtime::new()?;
    let admin_client: AdminClient<DefaultClientContext> = config.create()?;

    let mut topics = Vec::new();
    let mut resource_specs = Vec::new();
    let mut topic_names = Vec::new();

    // 1. Collect basic metadata
    for topic_meta in metadata.topics() {
        if topic_meta.error().is_none() {
            topic_names.push(topic_meta.name().to_string());
            resource_specs.push(ResourceSpecifier::Topic(topic_meta.name()));
        }
    }

    // 2. Fetch Configs in bulk
    let admin_options =
        AdminOptions::new().operation_timeout(Some(std::time::Duration::from_secs(10)));

    // We might have too many topics to fetch in one go, but let's try.
    // If it fails, we might need to chunk. For now, assuming reasonable count.
    let configs_result =
        rt.block_on(admin_client.describe_configs(&resource_specs, &admin_options));

    // Map configs by topic name for easy lookup
    let mut config_map: std::collections::HashMap<String, (Option<String>, Option<String>)> =
        std::collections::HashMap::new();

    if let Ok(configs) = configs_result {
        for config_resource in configs {
            if let Ok(resource) = config_resource {
                // Determine topic name from the resource (specifier)
                let topic_name = match &resource.specifier {
                    OwnedResourceSpecifier::Topic(name) => name.clone(),
                    _ => continue, // Should not happen as we requested topics
                };

                let mut retention = None;
                let mut cleanup = None;

                for entry in resource.entries {
                    if entry.name == "retention.ms" {
                        retention = Some(entry.value.unwrap_or_default().to_string());
                    } else if entry.name == "cleanup.policy" {
                        cleanup = Some(entry.value.unwrap_or_default().to_string());
                    }
                }
                config_map.insert(topic_name, (cleanup, retention));
            }
        }
    }

    // 3. Build final TopicMetadata
    for topic_meta in metadata.topics() {
        if topic_meta.error().is_none() {
            let partitions = topic_meta.partitions();
            let partition_count = partitions.len() as i32;
            let replication_factor = if !partitions.is_empty() {
                partitions[0].replicas().len() as i32
            } else {
                0
            };

            let (cleanup, retention) = config_map
                .get(topic_meta.name())
                .cloned()
                .unwrap_or((None, None));

            let health = summarize_topic_health(
                &topic_meta
                    .partitions()
                    .iter()
                    .map(partition_metadata)
                    .collect::<Vec<_>>(),
            );

            topics.push(TopicMetadata {
                name: topic_meta.name().to_string(),
                partition_count,
                replication_factor,
                cleanup_policy: cleanup,
                retention_ms: retention,
                under_replicated_partitions: health.map(|h| h.under_replicated_partitions),
                leaderless_partitions: health.map(|h| h.leaderless_partitions),
            });
        }
    }

    topics.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(topics)
}

pub fn fetch_topic_partitions(
    profile: ClusterProfile,
    topic: String,
) -> Result<TopicPartitionDetails> {
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer.fetch_metadata(Some(&topic), std::time::Duration::from_secs(10))?;

    let topic_meta = metadata
        .topics()
        .iter()
        .find(|t| t.name() == topic)
        .ok_or_else(|| anyhow::anyhow!("Topic not found: {}", topic))?;

    if let Some(error) = topic_meta.error() {
        return Err(anyhow::anyhow!(
            "Metadata for topic {} failed: {:?}",
            topic,
            error
        ));
    }

    Ok(TopicPartitionDetails {
        topic,
        partitions: topic_meta
            .partitions()
            .iter()
            .map(partition_metadata)
            .collect(),
        brokers: metadata
            .brokers()
            .iter()
            .map(|b| BrokerEndpoint {
                id: b.id(),
                host: b.host().to_string(),
                port: b.port(),
            })
            .collect(),
    })
}

fn collect_members(members: &[rdkafka::groups::GroupMemberInfo]) -> Vec<ConsumerGroupMember> {
    members
        .iter()
        .map(|member| {
            let subscriptions =
                parse_subscription(member.metadata().unwrap_or(&[])).unwrap_or_default();
            let assignment = member.assignment().and_then(parse_assignment);
            let assignment_decodable = assignment.is_some();
            ConsumerGroupMember {
                member_id: member.id().to_string(),
                client_id: member.client_id().to_string(),
                client_host: member.client_host().to_string(),
                subscriptions,
                assignments: assignment.unwrap_or_default(),
                assignment_decodable,
            }
        })
        .collect()
}

fn subscribed_topics(members: &[ConsumerGroupMember]) -> std::collections::HashSet<String> {
    let mut topics = std::collections::HashSet::new();
    for member in members {
        topics.extend(member.subscriptions.iter().cloned());
        topics.extend(member.assignments.iter().map(|a| a.topic.clone()));
    }
    topics
}

fn unassigned_partitions(
    topic_partitions: &std::collections::HashMap<String, Vec<i32>>,
    members: &[ConsumerGroupMember],
) -> Vec<TopicPartition> {
    let owned: std::collections::HashSet<(String, i32)> = members
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
    result
}

pub fn fetch_consumer_lags(
    profile: ClusterProfile,
) -> Result<Vec<kafkalyzer_core::kafka_types::ConsumerGroupLag>> {
    let timeout = std::time::Duration::from_secs(5);
    let config = create_config(&profile);
    let main_consumer: BaseConsumer = config.create()?;

    // Warm up the client connection using __consumer_offsets metadata fetch
    let _ = main_consumer.fetch_metadata(Some("__consumer_offsets"), timeout);

    // Fetch list of consumer groups with retries for transient Partial responses
    let mut group_list = None;
    for attempt in 1..=3 {
        match main_consumer.fetch_group_list(None, timeout) {
            Ok(gl) => {
                group_list = Some(gl);
                break;
            }
            Err(rdkafka::error::KafkaError::GroupListFetch(
                rdkafka::types::RDKafkaErrorCode::Partial,
            )) => {
                if attempt == 3 {
                    return Err(anyhow::anyhow!(
                        "Group list fetch failed: \
                         Partial response after 3 attempts"
                    ));
                }
                std::thread::sleep(std::time::Duration::from_millis(500 * attempt));
            }
            Err(e) => {
                return Err(anyhow::Error::from(e));
            }
        }
    }
    let group_list = group_list.unwrap();
    let mut results = Vec::new();

    // 2. Collect all topics consumed by active (Stable) groups
    let mut active_groups = Vec::new();
    let mut all_needed_topics = std::collections::HashSet::new();

    for group in group_list.groups() {
        let group_id = group.name();
        let state = group.state();
        let protocol_type = group.protocol_type();

        // Standard consumer groups only
        if protocol_type != "consumer" && !protocol_type.is_empty() {
            continue;
        }

        let is_stable = state.eq_ignore_ascii_case("stable");

        let mut group_topics = std::collections::HashSet::new();
        let mut members_count = 0;
        let mut members = Vec::new();
        if is_stable {
            members_count = group.members().len() as i32;
            members = collect_members(group.members());
            group_topics = subscribed_topics(&members);
            all_needed_topics.extend(group_topics.iter().cloned());
        }

        active_groups.push((
            group_id.to_string(),
            state.to_string(),
            protocol_type.to_string(),
            group_topics,
            members_count,
            members,
        ));
    }

    // 3. Fetch metadata for only the needed topics
    let mut topic_partitions: std::collections::HashMap<String, Vec<i32>> =
        std::collections::HashMap::new();

    for topic_name in &all_needed_topics {
        if let Ok(md) = main_consumer.fetch_metadata(Some(topic_name), timeout) {
            for topic_meta in md.topics() {
                if topic_meta.name() == topic_name && topic_meta.error().is_none() {
                    let parts: Vec<i32> = topic_meta.partitions().iter().map(|p| p.id()).collect();
                    topic_partitions.insert(topic_name.clone(), parts);
                }
            }
        }
    }

    // 4. Cache watermarks to prevent redundant coordinator requests
    let mut watermark_cache: std::collections::HashMap<(String, i32), (i64, i64)> =
        std::collections::HashMap::new();

    // 5. Query committed offsets and build results
    for (group_id, state, protocol_type, group_topics, members_count, members) in active_groups {
        let mut partitions_to_query = rdkafka::TopicPartitionList::new();
        for topic_name in &group_topics {
            if let Some(partitions) = topic_partitions.get(topic_name) {
                for &partition_id in partitions {
                    partitions_to_query.add_partition(topic_name, partition_id);
                }
            }
        }

        if partitions_to_query.count() == 0 {
            results.push(kafkalyzer_core::kafka_types::ConsumerGroupLag {
                group_id,
                state,
                protocol_type,
                partition_lags: Vec::new(),
                members_count,
                topics_count: group_topics.len() as i32,
                unassigned_partitions: unassigned_partitions(&topic_partitions, &members),
                members,
            });
            continue;
        }

        // Create temporary consumer configuration for the specific group ID
        let mut group_config = create_config(&profile);
        group_config.set("group.id", &group_id);
        let group_consumer: BaseConsumer = match group_config.create() {
            Ok(c) => c,
            Err(_) => continue,
        };

        // Query committed offsets for specified partitions
        let committed_tpl = match group_consumer.committed_offsets(partitions_to_query, timeout) {
            Ok(tpl) => tpl,
            Err(_) => continue,
        };

        let mut partition_lags = Vec::new();

        // Calculate lag for each partition with committed offset
        for elem in committed_tpl.elements() {
            if let rdkafka::Offset::Offset(current_offset) = elem.offset() {
                let topic = elem.topic();
                let partition = elem.partition();

                let cache_key = (topic.to_string(), partition);
                let high_offset = if let Some(&(_, high)) = watermark_cache.get(&cache_key) {
                    Some(high)
                } else {
                    match main_consumer.fetch_watermarks(topic, partition, timeout) {
                        Ok((low, high)) => {
                            watermark_cache.insert(cache_key, (low, high));
                            Some(high)
                        }
                        Err(_) => None,
                    }
                };

                if let Some(high_offset) = high_offset {
                    let lag = calculate_lag(high_offset, current_offset);

                    partition_lags.push(kafkalyzer_core::kafka_types::TopicPartitionLag {
                        topic: topic.to_string(),
                        partition,
                        log_end_offset: high_offset,
                        current_offset,
                        lag,
                    });
                }
            }
        }

        results.push(kafkalyzer_core::kafka_types::ConsumerGroupLag {
            group_id,
            state,
            protocol_type,
            partition_lags,
            members_count,
            topics_count: group_topics.len() as i32,
            unassigned_partitions: unassigned_partitions(&topic_partitions, &members),
            members,
        });
    }

    Ok(results)
}

pub fn fetch_consumer_groups(
    profile: ClusterProfile,
) -> Result<Vec<kafkalyzer_core::kafka_types::ConsumerGroupLag>> {
    let timeout = std::time::Duration::from_secs(5);
    let config = create_config(&profile);
    let main_consumer: BaseConsumer = config.create()?;

    // Warm up the client connection
    let _ = main_consumer.fetch_metadata(Some("__consumer_offsets"), timeout);

    // Fetch list of consumer groups with retries
    let mut group_list = None;
    for attempt in 1..=3 {
        match main_consumer.fetch_group_list(None, timeout) {
            Ok(gl) => {
                group_list = Some(gl);
                break;
            }
            Err(rdkafka::error::KafkaError::GroupListFetch(
                rdkafka::types::RDKafkaErrorCode::Partial,
            )) => {
                if attempt == 3 {
                    return Err(anyhow::anyhow!("Group list fetch failed: Partial response"));
                }
                std::thread::sleep(std::time::Duration::from_millis(500 * attempt));
            }
            Err(e) => {
                return Err(anyhow::Error::from(e));
            }
        }
    }
    let group_list = group_list.unwrap();
    let mut results = Vec::new();

    for group in group_list.groups() {
        let group_id = group.name();
        let state = group.state();
        let protocol_type = group.protocol_type();

        // Standard consumer groups only
        if protocol_type != "consumer" && !protocol_type.is_empty() {
            continue;
        }

        let is_stable = state.eq_ignore_ascii_case("stable");
        let mut members = Vec::new();
        let mut members_count = 0;
        if is_stable {
            members_count = group.members().len() as i32;
            members = collect_members(group.members());
        }

        results.push(kafkalyzer_core::kafka_types::ConsumerGroupLag {
            group_id: group_id.to_string(),
            state: state.to_string(),
            protocol_type: protocol_type.to_string(),
            partition_lags: Vec::new(),
            members_count,
            topics_count: subscribed_topics(&members).len() as i32,
            unassigned_partitions: Vec::new(),
            members,
        });
    }

    Ok(results)
}

pub fn fetch_consumer_group_lag(
    profile: ClusterProfile,
    group_id: String,
) -> Result<kafkalyzer_core::kafka_types::ConsumerGroupLag> {
    let timeout = std::time::Duration::from_secs(5);
    let config = create_config(&profile);
    let main_consumer: BaseConsumer = config.create()?;

    // Fetch list filtering for requested group ID
    let group_list = main_consumer.fetch_group_list(Some(&group_id), timeout)?;
    let group = group_list
        .groups()
        .iter()
        .find(|g| g.name() == group_id)
        .ok_or_else(|| anyhow::anyhow!("Group not found: {}", group_id))?;

    let state = group.state();
    let protocol_type = group.protocol_type();

    let is_stable = state.eq_ignore_ascii_case("stable");
    let mut members = Vec::new();
    let mut members_count = 0;
    if is_stable {
        members_count = group.members().len() as i32;
        members = collect_members(group.members());
    }
    let group_topics = subscribed_topics(&members);

    let mut topic_partitions = std::collections::HashMap::new();
    for topic_name in &group_topics {
        if let Ok(md) = main_consumer.fetch_metadata(Some(topic_name), timeout) {
            for topic_meta in md.topics() {
                if topic_meta.name() == topic_name && topic_meta.error().is_none() {
                    let parts: Vec<i32> = topic_meta.partitions().iter().map(|p| p.id()).collect();
                    topic_partitions.insert(topic_name.clone(), parts);
                }
            }
        }
    }

    let mut partitions_to_query = rdkafka::TopicPartitionList::new();
    for topic_name in &group_topics {
        if let Some(partitions) = topic_partitions.get(topic_name) {
            for &partition_id in partitions {
                partitions_to_query.add_partition(topic_name, partition_id);
            }
        }
    }

    if partitions_to_query.count() == 0 {
        return Ok(kafkalyzer_core::kafka_types::ConsumerGroupLag {
            group_id,
            state: state.to_string(),
            protocol_type: protocol_type.to_string(),
            partition_lags: Vec::new(),
            members_count,
            topics_count: group_topics.len() as i32,
            unassigned_partitions: unassigned_partitions(&topic_partitions, &members),
            members,
        });
    }

    let mut group_config = create_config(&profile);
    group_config.set("group.id", &group_id);
    let group_consumer: BaseConsumer = group_config.create()?;

    let committed_tpl = group_consumer.committed_offsets(partitions_to_query, timeout)?;
    let mut partition_lags = Vec::new();

    for elem in committed_tpl.elements() {
        if let rdkafka::Offset::Offset(current_offset) = elem.offset() {
            let topic = elem.topic();
            let partition = elem.partition();

            if let Ok((_, high_offset)) = main_consumer.fetch_watermarks(topic, partition, timeout)
            {
                let lag = calculate_lag(high_offset, current_offset);
                partition_lags.push(kafkalyzer_core::kafka_types::TopicPartitionLag {
                    topic: topic.to_string(),
                    partition,
                    log_end_offset: high_offset,
                    current_offset,
                    lag,
                });
            }
        }
    }

    Ok(kafkalyzer_core::kafka_types::ConsumerGroupLag {
        group_id,
        state: state.to_string(),
        protocol_type: protocol_type.to_string(),
        partition_lags,
        members_count,
        topics_count: group_topics.len() as i32,
        unassigned_partitions: unassigned_partitions(&topic_partitions, &members),
        members,
    })
}

pub fn calculate_lag(high_offset: i64, current_offset: i64) -> i64 {
    if high_offset >= current_offset {
        high_offset - current_offset
    } else {
        0
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_lag() {
        assert_eq!(calculate_lag(100, 90), 10);
        assert_eq!(calculate_lag(100, 100), 0);
        assert_eq!(calculate_lag(100, 110), 0);
    }

    #[test]
    fn one_replica_missing_from_isr_counts_as_under_replicated() {
        let partitions = vec![
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
                leader: Some(3),
                replicas: vec![1, 2, 3],
                in_sync_replicas: vec![1, 2, 3],
            },
        ];

        let health = summarize_topic_health(&partitions).unwrap();
        assert_eq!(health.under_replicated_partitions, 1);
        assert_eq!(health.leaderless_partitions, 0);
    }

    #[test]
    fn topic_without_usable_metadata_reports_no_healthy_partitions() {
        // An errored or empty topic must not be summarized as "0 problems".
        assert_eq!(summarize_topic_health(&[]), None);
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

        let partitions = std::collections::HashMap::from([("orders".to_string(), vec![0, 1])]);
        let unowned = unassigned_partitions(&partitions, &[member]);

        assert_eq!(unowned.len(), 2);
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

        let partitions = std::collections::HashMap::from([("orders".to_string(), vec![0, 1, 2])]);
        let unowned = unassigned_partitions(&partitions, &[member]);

        assert_eq!(unowned.len(), 2);
        assert_eq!(unowned[0].partition, 1);
    }
}
