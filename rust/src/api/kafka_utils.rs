use crate::api::kafka_types::ClusterProfile;
pub use kafkalyzer_kafka::kafka_utils::ClientConfig;

pub fn murmur2(data: &[u8]) -> u32 {
    kafkalyzer_kafka::kafka_utils::murmur2(data)
}

pub fn to_positive(number: u32) -> u32 {
    kafkalyzer_kafka::kafka_utils::to_positive(number)
}

/// Predicts the target partition for a UTF-8 key using Kafka's Java default partitioner.
pub fn predict_default_partition(key: String, partition_count: i32) -> Option<i32> {
    kafkalyzer_core::partitioner::default_partition(key.as_bytes(), partition_count)
}

pub fn create_config(profile: &ClusterProfile) -> ClientConfig {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::kafka_utils::create_config(&domain_profile)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn predict_default_partition_delegates_to_core() {
        assert_eq!(
            predict_default_partition("order-4711".to_string(), 12),
            kafkalyzer_core::partitioner::default_partition(b"order-4711", 12)
        );
        assert_eq!(predict_default_partition("order-4711".to_string(), 0), None);
    }
}
