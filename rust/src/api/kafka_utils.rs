use crate::api::kafka_types::ClusterProfile;
pub use kafkalyzer_kafka::kafka_utils::ClientConfig;

pub fn murmur2(data: &[u8]) -> u32 {
    kafkalyzer_kafka::kafka_utils::murmur2(data)
}

pub fn to_positive(number: u32) -> u32 {
    kafkalyzer_kafka::kafka_utils::to_positive(number)
}

pub fn create_config(profile: &ClusterProfile) -> ClientConfig {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::kafka_utils::create_config(&domain_profile)
}
