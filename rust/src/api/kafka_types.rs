use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClusterProfile {
    pub name: String,
    pub bootstrap_servers: String,
    pub sasl_username: Option<String>,
    pub sasl_password: Option<String>,
    pub mechanism: Option<String>,
    pub security_protocol: Option<String>,
    pub schema_registry_url: Option<String>,
    pub ssl_keystore_location: Option<String>,
    pub ssl_keystore_password: Option<String>,
    pub ssl_truststore_location: Option<String>,
    pub ssl_truststore_password: Option<String>,
}

impl ClusterProfile {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::ClusterProfile {
        kafkalyzer_core::kafka_types::ClusterProfile {
            name: self.name.clone(),
            bootstrap_servers: self.bootstrap_servers.clone(),
            sasl_username: self.sasl_username.clone(),
            sasl_password: self.sasl_password.clone(),
            mechanism: self.mechanism.clone(),
            security_protocol: self.security_protocol.clone(),
            schema_registry_url: self.schema_registry_url.clone(),
            ssl_keystore_location: self.ssl_keystore_location.clone(),
            ssl_keystore_password: self.ssl_keystore_password.clone(),
            ssl_truststore_location: self.ssl_truststore_location.clone(),
            ssl_truststore_password: self.ssl_truststore_password.clone(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FilterType {
    Contains,
    Regex,
    Exact,
}

impl FilterType {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::FilterType {
        match self {
            FilterType::Contains => kafkalyzer_core::kafka_types::FilterType::Contains,
            FilterType::Regex => kafkalyzer_core::kafka_types::FilterType::Regex,
            FilterType::Exact => kafkalyzer_core::kafka_types::FilterType::Exact,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SearchScope {
    Key,
    Value,
    Both,
}

impl SearchScope {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::SearchScope {
        match self {
            SearchScope::Key => kafkalyzer_core::kafka_types::SearchScope::Key,
            SearchScope::Value => kafkalyzer_core::kafka_types::SearchScope::Value,
            SearchScope::Both => kafkalyzer_core::kafka_types::SearchScope::Both,
        }
    }
}

