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
    // Schema Registry Auth
    pub schema_registry_username: Option<String>,
    pub schema_registry_password: Option<String>,
    // Advanced SASL
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
            schema_registry_username: self.schema_registry_username.clone(),
            schema_registry_password: self.schema_registry_password.clone(),
            sasl_kerberos_service_name: self.sasl_kerberos_service_name.clone(),
            sasl_kerberos_keytab: self.sasl_kerberos_keytab.clone(),
            sasl_kerberos_principal: self.sasl_kerberos_principal.clone(),
            sasl_kerberos_conf: self.sasl_kerberos_conf.clone(),
            sasl_oauthbearer_token: self.sasl_oauthbearer_token.clone(),
            ssl_pem_certificate_location: self.ssl_pem_certificate_location.clone(),
            ssl_pem_key_location: self.ssl_pem_key_location.clone(),
            ssl_pem_key_password: self.ssl_pem_key_password.clone(),
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
    pub members_count: i32,
    pub topics_count: i32,
}

impl From<kafkalyzer_core::kafka_types::TopicPartitionLag> for TopicPartitionLag {
    fn from(lag: kafkalyzer_core::kafka_types::TopicPartitionLag) -> Self {
        Self {
            topic: lag.topic,
            partition: lag.partition,
            log_end_offset: lag.log_end_offset,
            current_offset: lag.current_offset,
            lag: lag.lag,
        }
    }
}

impl From<kafkalyzer_core::kafka_types::ConsumerGroupLag> for ConsumerGroupLag {
    fn from(group: kafkalyzer_core::kafka_types::ConsumerGroupLag) -> Self {
        Self {
            group_id: group.group_id,
            state: group.state,
            protocol_type: group.protocol_type,
            partition_lags: group
                .partition_lags
                .into_iter()
                .map(TopicPartitionLag::from)
                .collect(),
            members_count: group.members_count,
            topics_count: group.topics_count,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HourlyCount {
    pub hour: i32,
    pub count: i64,
    pub percentage: f64,
}

impl From<kafkalyzer_core::kafka_types::HourlyCount> for HourlyCount {
    fn from(h: kafkalyzer_core::kafka_types::HourlyCount) -> Self {
        Self {
            hour: h.hour,
            count: h.count,
            percentage: h.percentage,
        }
    }
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

impl From<kafkalyzer_core::kafka_types::PartitionAnalysis> for PartitionAnalysis {
    fn from(p: kafkalyzer_core::kafka_types::PartitionAnalysis) -> Self {
        Self {
            partition: p.partition,
            message_count: p.message_count,
            byte_size: p.byte_size,
            percentage: p.percentage,
            earliest_offset: p.earliest_offset,
            latest_offset: p.latest_offset,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyOccurrence {
    pub key: String,
    pub count: i64,
    pub percentage: f64,
}

impl From<kafkalyzer_core::kafka_types::KeyOccurrence> for KeyOccurrence {
    fn from(k: kafkalyzer_core::kafka_types::KeyOccurrence) -> Self {
        Self {
            key: k.key,
            count: k.count,
            percentage: k.percentage,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TypeOccurrence {
    pub type_name: String,
    pub count: i64,
    pub percentage: f64,
}

impl From<kafkalyzer_core::kafka_types::TypeOccurrence> for TypeOccurrence {
    fn from(t: kafkalyzer_core::kafka_types::TypeOccurrence) -> Self {
        Self {
            type_name: t.type_name,
            count: t.count,
            percentage: t.percentage,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldValueOccurrence {
    pub value: String,
    pub count: i64,
    pub percentage: f64,
}

impl From<kafkalyzer_core::kafka_types::FieldValueOccurrence> for FieldValueOccurrence {
    fn from(f: kafkalyzer_core::kafka_types::FieldValueOccurrence) -> Self {
        Self {
            value: f.value,
            count: f.count,
            percentage: f.percentage,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldOccurrence {
    pub field_name: String,
    pub count: i64,
    pub percentage: f64,
    pub top_values: Vec<FieldValueOccurrence>,
}

impl From<kafkalyzer_core::kafka_types::FieldOccurrence> for FieldOccurrence {
    fn from(f: kafkalyzer_core::kafka_types::FieldOccurrence) -> Self {
        Self {
            field_name: f.field_name,
            count: f.count,
            percentage: f.percentage,
            top_values: f
                .top_values
                .into_iter()
                .map(FieldValueOccurrence::from)
                .collect(),
        }
    }
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
}

impl From<kafkalyzer_core::kafka_types::TopicAnalysisReport> for TopicAnalysisReport {
    fn from(r: kafkalyzer_core::kafka_types::TopicAnalysisReport) -> Self {
        Self {
            topic: r.topic,
            total_messages: r.total_messages,
            total_bytes: r.total_bytes,
            min_message_size: r.min_message_size,
            max_message_size: r.max_message_size,
            avg_message_size: r.avg_message_size,
            tombstones_count: r.tombstones_count,
            is_compacted: r.is_compacted,
            null_keys_count: r.null_keys_count,
            partition_stats: r
                .partition_stats
                .into_iter()
                .map(PartitionAnalysis::from)
                .collect(),
            hourly_distribution: r
                .hourly_distribution
                .into_iter()
                .map(HourlyCount::from)
                .collect(),
            top_keys: r.top_keys.into_iter().map(KeyOccurrence::from).collect(),
            content_type_distribution: r
                .content_type_distribution
                .into_iter()
                .map(TypeOccurrence::from)
                .collect(),
            field_frequencies: r
                .field_frequencies
                .into_iter()
                .map(FieldOccurrence::from)
                .collect(),
            scan_duration_ms: r.scan_duration_ms,
        }
    }
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

impl From<kafkalyzer_core::kafka_types::TopicAnalysisProgress> for TopicAnalysisProgress {
    fn from(p: kafkalyzer_core::kafka_types::TopicAnalysisProgress) -> Self {
        Self {
            scanned_messages: p.scanned_messages,
            total_messages_to_scan: p.total_messages_to_scan,
            progress: p.progress,
            messages_per_second: p.messages_per_second,
            current_partition: p.current_partition,
            is_complete: p.is_complete,
            error_message: p.error_message,
            partial_report: p.partial_report.map(TopicAnalysisReport::from),
        }
    }
}
