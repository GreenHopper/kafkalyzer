use anyhow::Result;
use rdkafka::admin::{AdminClient, AdminOptions, ResourceSpecifier, OwnedResourceSpecifier};
use rdkafka::client::DefaultClientContext;
use rdkafka::consumer::{BaseConsumer, Consumer};
use tokio::runtime::Runtime;
use kafkalyzer_core::kafka_types::ClusterProfile;
use crate::kafka_utils::create_config;

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
    let admin_options = AdminOptions::new().operation_timeout(Some(std::time::Duration::from_secs(10)));
    
    // We might have too many topics to fetch in one go, but let's try. 
    // If it fails, we might need to chunk. For now, assuming reasonable count.
    let configs_result = rt.block_on(admin_client.describe_configs(&resource_specs, &admin_options));

    // Map configs by topic name for easy lookup
    let mut config_map: std::collections::HashMap<String, (Option<String>, Option<String>)> = std::collections::HashMap::new();

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
             
             let (cleanup, retention) = config_map.get(topic_meta.name()).cloned().unwrap_or((None, None));

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
