use crate::consumer_group_protocol::TopicPartition;
use crate::size_stats::SizePercentiles;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
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
    // Schema Registry Auth
    pub schema_registry_username: Option<String>,
    pub schema_registry_password: Option<String>,
    // Advanced SASL (Kerberos, OAuth, MSK)
    pub sasl_kerberos_service_name: Option<String>,
    pub sasl_kerberos_keytab: Option<String>,
    pub sasl_kerberos_principal: Option<String>,
    pub sasl_kerberos_conf: Option<String>,
    pub sasl_oauthbearer_token: Option<String>,
    // PEM mTLS
    pub ssl_pem_certificate_location: Option<String>,
    pub ssl_pem_key_location: Option<String>,
    pub ssl_pem_key_password: Option<String>,
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
pub struct KafkaHeader {
    pub key: String,
    pub value: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct MessageSchema {
    pub schema_id: u32,
    /// Subject as registered in the Schema Registry. `None` when the registry
    /// could not be reached or the id is not registered under a subject.
    pub subject: Option<String>,
    pub version: Option<i32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KafkaMessage {
    pub topic: String,
    pub partition: i32,
    pub offset: i64,
    pub key: Option<String>,
    pub payload: Option<String>,
    pub timestamp: i64,
    pub headers: Option<Vec<KafkaHeader>>,
    /// Schema the key was encoded with, `None` for a key without registry encoding.
    pub key_schema: Option<MessageSchema>,
    /// Schema the value was encoded with, `None` for a plain payload.
    pub value_schema: Option<MessageSchema>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopicPartitionLag {
    pub topic: String,
    pub partition: i32,
    pub log_end_offset: i64,
    pub current_offset: i64,
    pub lag: i64,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ConsumerGroupMember {
    pub member_id: String,
    pub client_id: String,
    pub client_host: String,
    pub subscriptions: Vec<String>,
    pub assignments: Vec<TopicPartition>,
    /// False when the member's assignment bytes could not be decoded, which is
    /// different from "this member owns no partitions".
    pub assignment_decodable: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConsumerGroupLag {
    pub group_id: String,
    pub state: String,
    pub protocol_type: String,
    pub partition_lags: Vec<TopicPartitionLag>,
    pub members_count: i32,
    pub topics_count: i32,
    pub members: Vec<ConsumerGroupMember>,
    /// Partitions of the group's topics that no member owns.
    pub unassigned_partitions: Vec<TopicPartition>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HourlyCount {
    pub hour: i32,
    pub count: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PartitionAnalysis {
    pub partition: i32,
    pub message_count: i64,
    pub byte_size: i64,
    pub percentage: f64,
    pub earliest_offset: i64,
    pub latest_offset: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyOccurrence {
    pub key: String,
    pub count: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeOccurrence {
    pub type_name: String,
    pub count: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldValueOccurrence {
    pub value: String,
    pub count: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldOccurrence {
    pub field_name: String,
    pub count: i64,
    pub percentage: f64,
    pub top_values: Vec<FieldValueOccurrence>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopicAnalysisReport {
    pub topic: String,
    pub total_messages: i64,
    pub total_bytes: i64,
    pub min_message_size: i64,
    pub max_message_size: i64,
    pub avg_message_size: f64,
    pub tombstones_count: i64,
    pub is_compacted: bool,
    pub null_keys_count: i64,
    pub partition_stats: Vec<PartitionAnalysis>,
    pub hourly_distribution: Vec<HourlyCount>,
    pub top_keys: Vec<KeyOccurrence>,
    pub content_type_distribution: Vec<TypeOccurrence>,
    pub field_frequencies: Vec<FieldOccurrence>,
    pub scan_duration_ms: i64,
    /// p50 / p95 / p99 of message sizes, or None when nothing was scanned.
    #[serde(default)]
    pub message_size_percentiles: Option<SizePercentiles>,
    /// True when more messages were scanned than the percentile sample can hold.
    #[serde(default)]
    pub size_percentiles_estimated: bool,
    /// Distinct keys counted by the capped key map.
    #[serde(default)]
    pub estimated_distinct_keys: i64,
    /// True when the key map hit its size cap, so the distinct-key count is a
    /// lower bound rather than an exact number.
    #[serde(default)]
    pub key_cardinality_capped: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TopicAnalysisProgress {
    pub scanned_messages: i64,
    pub total_messages_to_scan: i64,
    pub progress: f64,
    pub messages_per_second: f64,
    pub current_partition: i32,
    pub is_complete: bool,
    pub error_message: Option<String>,
    pub partial_report: Option<TopicAnalysisReport>,
}
