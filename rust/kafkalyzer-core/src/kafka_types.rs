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

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum FilterType {
    Contains,
    Regex,
    Exact,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum SearchScope {
    Key,
    Value,
    Both,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KafkaMessage {
    pub topic: String,
    pub partition: i32,
    pub offset: i64,
    pub key: Option<String>,
    pub payload: Option<String>,
    pub timestamp: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopicPartitionLag {
    pub topic: String,
    pub partition: i32,
    pub log_end_offset: i64,
    pub current_offset: i64,
    pub lag: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConsumerGroupLag {
    pub group_id: String,
    pub state: String,
    pub protocol_type: String,
    pub partition_lags: Vec<TopicPartitionLag>,
}
