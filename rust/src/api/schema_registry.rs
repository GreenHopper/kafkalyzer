use crate::api::kafka_types::ClusterProfile;
use anyhow::Result;

pub fn fetch_subjects(profile: ClusterProfile) -> Result<Vec<String>> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::schema_registry::fetch_subjects(domain_profile)
}

pub fn fetch_schema(profile: ClusterProfile, subject: String) -> Result<String> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::schema_registry::fetch_schema(domain_profile, subject)
}
