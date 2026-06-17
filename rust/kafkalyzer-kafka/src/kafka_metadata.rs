use crate::kafka_utils::create_config;
use anyhow::Result;
use kafkalyzer_core::kafka_types::ClusterProfile;
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

            topics.push(TopicMetadata {
                name: topic_meta.name().to_string(),
                partition_count,
                replication_factor,
                cleanup_policy: cleanup,
                retention_ms: retention,
            });
        }
    }

    topics.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(topics)
}

fn parse_member_subscription(metadata: &[u8]) -> Option<Vec<String>> {
    use std::io::Read;
    let mut cursor = std::io::Cursor::new(metadata);

    // Read version (2 bytes)
    let mut version_bytes = [0; 2];
    cursor.read_exact(&mut version_bytes).ok()?;
    let _version = i16::from_be_bytes(version_bytes);

    // Read topics array length (4 bytes)
    let mut topics_len_bytes = [0; 4];
    cursor.read_exact(&mut topics_len_bytes).ok()?;
    let topics_len = i32::from_be_bytes(topics_len_bytes);
    if topics_len < 0 || topics_len > 100_000 {
        return None;
    }

    let mut topics = Vec::new();
    for _ in 0..topics_len {
        // Read topic name length (2 bytes)
        let mut name_len_bytes = [0; 2];
        cursor.read_exact(&mut name_len_bytes).ok()?;
        let name_len = i16::from_be_bytes(name_len_bytes);
        if name_len < 0 || name_len > 10_000 {
            return None;
        }

        // Read topic name bytes
        let mut name_bytes = vec![0; name_len as usize];
        cursor.read_exact(&mut name_bytes).ok()?;
        let topic_name = String::from_utf8(name_bytes).ok()?;
        topics.push(topic_name);
    }

    Some(topics)
}

fn parse_member_assignment(assignment: &[u8]) -> Option<Vec<String>> {
    use std::io::Read;
    let mut cursor = std::io::Cursor::new(assignment);

    // Read version (2 bytes)
    let mut version_bytes = [0; 2];
    cursor.read_exact(&mut version_bytes).ok()?;
    let _version = i16::from_be_bytes(version_bytes);

    // Read topic array length (4 bytes)
    let mut topics_len_bytes = [0; 4];
    cursor.read_exact(&mut topics_len_bytes).ok()?;
    let topics_len = i32::from_be_bytes(topics_len_bytes);
    if topics_len < 0 || topics_len > 100_000 {
        return None;
    }

    let mut topics = Vec::new();
    for _ in 0..topics_len {
        // Read topic name length (2 bytes)
        let mut name_len_bytes = [0; 2];
        cursor.read_exact(&mut name_len_bytes).ok()?;
        let name_len = i16::from_be_bytes(name_len_bytes);
        if name_len < 0 || name_len > 10_000 {
            return None;
        }

        // Read topic name bytes
        let mut name_bytes = vec![0; name_len as usize];
        cursor.read_exact(&mut name_bytes).ok()?;
        let topic_name = String::from_utf8(name_bytes).ok()?;
        topics.push(topic_name);

        // Read partition array length (4 bytes)
        let mut part_len_bytes = [0; 4];
        cursor.read_exact(&mut part_len_bytes).ok()?;
        let part_len = i32::from_be_bytes(part_len_bytes);
        if part_len < 0 || part_len > 100_000 {
            return None;
        }

        // Skip partitions (part_len * 4 bytes)
        let skip_len = part_len as usize * 4;
        let mut skip_buf = vec![0; skip_len];
        cursor.read_exact(&mut skip_buf).ok()?;
    }

    Some(topics)
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
        if is_stable {
            for member in group.members() {
                if let Some(metadata) = member.metadata() {
                    if let Some(topics) = parse_member_subscription(metadata) {
                        for topic in topics {
                            group_topics.insert(topic.clone());
                            all_needed_topics.insert(topic);
                        }
                    }
                }
                if let Some(assignment) = member.assignment() {
                    if let Some(topics) = parse_member_assignment(assignment) {
                        for topic in topics {
                            group_topics.insert(topic.clone());
                            all_needed_topics.insert(topic);
                        }
                    }
                }
            }
        }

        active_groups.push((
            group_id.to_string(),
            state.to_string(),
            protocol_type.to_string(),
            group_topics,
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
    for (group_id, state, protocol_type, group_topics) in active_groups {
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
                    return Err(anyhow::anyhow!(
                        "Group list fetch failed: Partial response"
                    ));
                }
                std::thread::sleep(std::time::Duration::from_millis(
                    500 * attempt,
                ));
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

        results.push(kafkalyzer_core::kafka_types::ConsumerGroupLag {
            group_id: group_id.to_string(),
            state: state.to_string(),
            protocol_type: protocol_type.to_string(),
            partition_lags: Vec::new(),
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
    let group_list =
        main_consumer.fetch_group_list(Some(&group_id), timeout)?;
    let group = group_list
        .groups()
        .iter()
        .find(|g| g.name() == group_id)
        .ok_or_else(|| anyhow::anyhow!("Group not found: {}", group_id))?;

    let state = group.state();
    let protocol_type = group.protocol_type();

    let is_stable = state.eq_ignore_ascii_case("stable");
    let mut group_topics = std::collections::HashSet::new();
    if is_stable {
        for member in group.members() {
            if let Some(metadata) = member.metadata() {
                if let Some(topics) = parse_member_subscription(metadata) {
                    for topic in topics {
                        group_topics.insert(topic);
                    }
                }
            }
            if let Some(assignment) = member.assignment() {
                if let Some(topics) = parse_member_assignment(assignment) {
                    for topic in topics {
                        group_topics.insert(topic);
                    }
                }
            }
        }
    }

    let mut topic_partitions = std::collections::HashMap::new();
    for topic_name in &group_topics {
        if let Ok(md) =
            main_consumer.fetch_metadata(Some(topic_name), timeout)
        {
            for topic_meta in md.topics() {
                if topic_meta.name() == topic_name
                    && topic_meta.error().is_none()
                {
                    let parts: Vec<i32> = topic_meta
                        .partitions()
                        .iter()
                        .map(|p| p.id())
                        .collect();
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
        });
    }

    let mut group_config = create_config(&profile);
    group_config.set("group.id", &group_id);
    let group_consumer: BaseConsumer = group_config.create()?;

    let committed_tpl = group_consumer.committed_offsets(
        partitions_to_query,
        timeout,
    )?;
    let mut partition_lags = Vec::new();

    for elem in committed_tpl.elements() {
        if let rdkafka::Offset::Offset(current_offset) = elem.offset() {
            let topic = elem.topic();
            let partition = elem.partition();

            if let Ok((_, high_offset)) =
                main_consumer.fetch_watermarks(topic, partition, timeout)
            {
                let lag = calculate_lag(high_offset, current_offset);
                partition_lags.push(
                    kafkalyzer_core::kafka_types::TopicPartitionLag {
                        topic: topic.to_string(),
                        partition,
                        log_end_offset: high_offset,
                        current_offset,
                        lag,
                    },
                );
            }
        }
    }

    Ok(kafkalyzer_core::kafka_types::ConsumerGroupLag {
        group_id,
        state: state.to_string(),
        protocol_type: protocol_type.to_string(),
        partition_lags,
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
    fn test_parse_member_subscription() {
        let bytes = vec![
            0, 0, // version
            0, 0, 0, 1, // topics len = 1
            0, 4, // topic name len = 4
            116, 101, 115, 116, // "test"
            0, 0, 0, 0, // user data len = 0
        ];
        let topics = parse_member_subscription(&bytes).unwrap();
        assert_eq!(topics, vec!["test".to_string()]);
    }

    #[test]
    fn test_parse_member_assignment() {
        let bytes = vec![
            0, 0, // version
            0, 0, 0, 1, // topics len = 1
            0, 4, // topic name len = 4
            116, 101, 115, 116, // "test"
            0, 0, 0, 2, // partitions len = 2
            0, 0, 0, 0, // partition 0
            0, 0, 0, 1, // partition 1
            0, 0, 0, 0, // user data len = 0
        ];
        let topics = parse_member_assignment(&bytes).unwrap();
        assert_eq!(topics, vec!["test".to_string()]);
    }
}
