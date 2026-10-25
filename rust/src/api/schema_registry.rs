use crate::api::kafka_types::ClusterProfile;
use anyhow::Result;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SchemaCompatibilityResult {
    pub is_compatible: bool,
    pub messages: Vec<String>,
}

impl From<kafkalyzer_core::kafka_types::SchemaCompatibilityResult> for SchemaCompatibilityResult {
    fn from(r: kafkalyzer_core::kafka_types::SchemaCompatibilityResult) -> Self {
        Self {
            is_compatible: r.is_compatible,
            messages: r.messages,
        }
    }
}

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

pub fn check_schema_compatibility(
    profile: ClusterProfile,
    subject: String,
    version: Option<i32>,
    schema: String,
) -> Result<SchemaCompatibilityResult> {
    let domain_profile = profile.to_domain();
    let res = kafkalyzer_kafka::schema_registry::check_schema_compatibility(
        domain_profile,
        subject,
        version,
        schema,
    )?;
    Ok(SchemaCompatibilityResult::from(res))
}

pub fn resolve_associated_topics_for_subject(
    subject: String,
    available_topics: Vec<String>,
) -> Vec<String> {
    kafkalyzer_kafka::schema_registry::resolve_associated_topics_for_subject(
        &subject,
        &available_topics,
    )
}
