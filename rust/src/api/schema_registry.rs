use crate::api::kafka_types::ClusterProfile;
use anyhow::Result;

pub fn fetch_subjects(profile: ClusterProfile) -> Result<Vec<String>> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::schema_registry::fetch_subjects(domain_profile)
}

pub fn fetch_schema(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
) -> Result<String> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::schema_registry::fetch_schema(domain_profile, subject, version)
}

pub fn fetch_schema_versions(profile: ClusterProfile, subject: String) -> Result<Vec<i32>> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::schema_registry::fetch_schema_versions(domain_profile, subject)
}
