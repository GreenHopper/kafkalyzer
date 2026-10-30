use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
// `default` keeps profiles stored before the advanced auth fields existed readable.
#[serde(rename_all = "camelCase", default)]
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
pub struct TopicPartition {
    pub topic: String,
    pub partition: i32,
}

impl From<kafkalyzer_core::consumer_group_protocol::TopicPartition> for TopicPartition {
    fn from(p: kafkalyzer_core::consumer_group_protocol::TopicPartition) -> Self {
        Self {
            topic: p.topic,
            partition: p.partition,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConsumerGroupMember {
    pub member_id: String,
    pub client_id: String,
    pub client_host: String,
    pub subscriptions: Vec<String>,
    pub assignments: Vec<TopicPartition>,
    pub assignment_decodable: bool,
}

impl From<kafkalyzer_core::kafka_types::ConsumerGroupMember> for ConsumerGroupMember {
    fn from(m: kafkalyzer_core::kafka_types::ConsumerGroupMember) -> Self {
        Self {
            member_id: m.member_id,
            client_id: m.client_id,
            client_host: m.client_host,
            subscriptions: m.subscriptions,
            assignments: m
                .assignments
                .into_iter()
                .map(TopicPartition::from)
                .collect(),
            assignment_decodable: m.assignment_decodable,
        }
    }
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
    pub unassigned_partitions: Vec<TopicPartition>,
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
            members: group
                .members
                .into_iter()
                .map(ConsumerGroupMember::from)
                .collect(),
            unassigned_partitions: group
                .unassigned_partitions
                .into_iter()
                .map(TopicPartition::from)
                .collect(),
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct HourBucket {
    pub epoch_hour: i64,
    pub count: i64,
}

impl From<kafkalyzer_core::kafka_types::HourBucket> for HourBucket {
    fn from(b: kafkalyzer_core::kafka_types::HourBucket) -> Self {
        Self {
            epoch_hour: b.epoch_hour,
            count: b.count,
        }
    }
}

impl HourBucket {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::HourBucket {
        kafkalyzer_core::kafka_types::HourBucket {
            epoch_hour: self.epoch_hour,
            count: self.count,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct FieldValueFilter {
    pub field_path: String,
    pub value: String,
}

impl From<kafkalyzer_core::kafka_types::FieldValueFilter> for FieldValueFilter {
    fn from(f: kafkalyzer_core::kafka_types::FieldValueFilter) -> Self {
        Self {
            field_path: f.field_path,
            value: f.value,
        }
    }
}

impl FieldValueFilter {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::FieldValueFilter {
        kafkalyzer_core::kafka_types::FieldValueFilter {
            field_path: self.field_path.clone(),
            value: self.value.clone(),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum DuplicateDetectionScope {
    PayloadOnly,
    KeyAndPayload,
}

impl From<kafkalyzer_core::kafka_types::DuplicateDetectionScope> for DuplicateDetectionScope {
    fn from(s: kafkalyzer_core::kafka_types::DuplicateDetectionScope) -> Self {
        match s {
            kafkalyzer_core::kafka_types::DuplicateDetectionScope::PayloadOnly => Self::PayloadOnly,
            kafkalyzer_core::kafka_types::DuplicateDetectionScope::KeyAndPayload => {
                Self::KeyAndPayload
            }
        }
    }
}

impl DuplicateDetectionScope {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::DuplicateDetectionScope {
        match self {
            Self::PayloadOnly => kafkalyzer_core::kafka_types::DuplicateDetectionScope::PayloadOnly,
            Self::KeyAndPayload => {
                kafkalyzer_core::kafka_types::DuplicateDetectionScope::KeyAndPayload
            }
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct TopDuplicateOccurrence {
    pub key: Option<String>,
    pub payload_preview: String,
    pub count: i64,
    pub percentage: f64,
    pub sample_partition: i32,
    pub sample_offset: i64,
    pub sample_timestamp_ms: i64,
}

impl From<kafkalyzer_core::kafka_types::TopDuplicateOccurrence> for TopDuplicateOccurrence {
    fn from(o: kafkalyzer_core::kafka_types::TopDuplicateOccurrence) -> Self {
        Self {
            key: o.key,
            payload_preview: o.payload_preview,
            count: o.count,
            percentage: o.percentage,
            sample_partition: o.sample_partition,
            sample_offset: o.sample_offset,
            sample_timestamp_ms: o.sample_timestamp_ms,
        }
    }
}

impl TopDuplicateOccurrence {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::TopDuplicateOccurrence {
        kafkalyzer_core::kafka_types::TopDuplicateOccurrence {
            key: self.key.clone(),
            payload_preview: self.payload_preview.clone(),
            count: self.count,
            percentage: self.percentage,
            sample_partition: self.sample_partition,
            sample_offset: self.sample_offset,
            sample_timestamp_ms: self.sample_timestamp_ms,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct DuplicateAnalysisResult {
    pub scope: DuplicateDetectionScope,
    pub total_messages: i64,
    pub unique_messages: i64,
    pub duplicate_messages: i64,
    pub duplicate_rate: f64,
    pub top_duplicates: Vec<TopDuplicateOccurrence>,
}

impl From<kafkalyzer_core::kafka_types::DuplicateAnalysisResult> for DuplicateAnalysisResult {
    fn from(r: kafkalyzer_core::kafka_types::DuplicateAnalysisResult) -> Self {
        Self {
            scope: DuplicateDetectionScope::from(r.scope),
            total_messages: r.total_messages,
            unique_messages: r.unique_messages,
            duplicate_messages: r.duplicate_messages,
            duplicate_rate: r.duplicate_rate,
            top_duplicates: r
                .top_duplicates
                .into_iter()
                .map(TopDuplicateOccurrence::from)
                .collect(),
        }
    }
}

impl DuplicateAnalysisResult {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::DuplicateAnalysisResult {
        kafkalyzer_core::kafka_types::DuplicateAnalysisResult {
            scope: self.scope.to_domain(),
            total_messages: self.total_messages,
            unique_messages: self.unique_messages,
            duplicate_messages: self.duplicate_messages,
            duplicate_rate: self.duplicate_rate,
            top_duplicates: self.top_duplicates.iter().map(|d| d.to_domain()).collect(),
        }
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct TopicAnalysisOptions {
    pub max_messages: Option<i64>,
    pub sample_from_latest: bool,
    pub value_filter: Option<FieldValueFilter>,
    #[serde(default)]
    pub duplicate_scope: Option<DuplicateDetectionScope>,
}

impl TopicAnalysisOptions {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::TopicAnalysisOptions {
        kafkalyzer_core::kafka_types::TopicAnalysisOptions {
            max_messages: self.max_messages,
            sample_from_latest: self.sample_from_latest,
            value_filter: self.value_filter.as_ref().map(|f| f.to_domain()),
            duplicate_scope: self.duplicate_scope.map(|s| s.to_domain()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ValueFilterResult {
    pub field_path: String,
    pub value: String,
    pub messages_with_field: i64,
    pub matched_messages: i64,
    pub matched_timeline: Vec<HourBucket>,
}

impl From<kafkalyzer_core::kafka_types::ValueFilterResult> for ValueFilterResult {
    fn from(r: kafkalyzer_core::kafka_types::ValueFilterResult) -> Self {
        Self {
            field_path: r.field_path,
            value: r.value,
            messages_with_field: r.messages_with_field,
            matched_messages: r.matched_messages,
            matched_timeline: r
                .matched_timeline
                .into_iter()
                .map(HourBucket::from)
                .collect(),
        }
    }
}

impl ValueFilterResult {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::ValueFilterResult {
        kafkalyzer_core::kafka_types::ValueFilterResult {
            field_path: self.field_path.clone(),
            value: self.value.clone(),
            messages_with_field: self.messages_with_field,
            matched_messages: self.matched_messages,
            matched_timeline: self
                .matched_timeline
                .iter()
                .map(|b| b.to_domain())
                .collect(),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldValueOccurrence {
    pub value: String,
    pub count: i64,
    pub percentage: f64,
    #[serde(default)]
    pub truncated: bool,
}

impl From<kafkalyzer_core::kafka_types::FieldValueOccurrence> for FieldValueOccurrence {
    fn from(f: kafkalyzer_core::kafka_types::FieldValueOccurrence) -> Self {
        Self {
            value: f.value,
            count: f.count,
            percentage: f.percentage,
            truncated: f.truncated,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldOccurrence {
    pub field_name: String,
    pub count: i64,
    pub percentage: f64,
    pub top_values: Vec<FieldValueOccurrence>,
    #[serde(default)]
    pub values_capped: bool,
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
            values_capped: f.values_capped,
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
    /// p50 / p95 / p99 of message sizes; None when nothing was scanned.
    #[serde(default)]
    pub message_size_percentiles: Option<SizePercentiles>,
    #[serde(default)]
    pub size_percentiles_estimated: bool,
    #[serde(default)]
    pub estimated_distinct_keys: i64,
    #[serde(default)]
    pub key_cardinality_capped: bool,
    #[serde(default)]
    pub hourly_timeline: Vec<HourBucket>,
    #[serde(default)]
    pub scan_reference_time_ms: Option<i64>,
    #[serde(default)]
    pub complete_from_ms: Option<i64>,
    #[serde(default)]
    pub timeline_outside_count: i64,
    #[serde(default)]
    pub value_filter_result: Option<ValueFilterResult>,
    #[serde(default)]
    pub duplicate_analysis_result: Option<DuplicateAnalysisResult>,
}

/// Message-size percentiles at the bridge boundary.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SizePercentiles {
    pub p50: i64,
    pub p95: i64,
    pub p99: i64,
}

impl From<kafkalyzer_core::size_stats::SizePercentiles> for SizePercentiles {
    fn from(p: kafkalyzer_core::size_stats::SizePercentiles) -> Self {
        Self {
            p50: p.p50,
            p95: p.p95,
            p99: p.p99,
        }
    }
}

impl SizePercentiles {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::size_stats::SizePercentiles {
        kafkalyzer_core::size_stats::SizePercentiles {
            p50: self.p50,
            p95: self.p95,
            p99: self.p99,
        }
    }
}

impl TopicAnalysisReport {
    /// Turns a report that came back from Dart (an imported file) into the domain
    /// report so core logic can work on it.
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::TopicAnalysisReport {
        kafkalyzer_core::kafka_types::TopicAnalysisReport {
            topic: self.topic.clone(),
            total_messages: self.total_messages,
            total_bytes: self.total_bytes,
            min_message_size: self.min_message_size,
            max_message_size: self.max_message_size,
            avg_message_size: self.avg_message_size,
            tombstones_count: self.tombstones_count,
            is_compacted: self.is_compacted,
            null_keys_count: self.null_keys_count,
            partition_stats: self
                .partition_stats
                .iter()
                .map(|p| kafkalyzer_core::kafka_types::PartitionAnalysis {
                    partition: p.partition,
                    message_count: p.message_count,
                    byte_size: p.byte_size,
                    percentage: p.percentage,
                    earliest_offset: p.earliest_offset,
                    latest_offset: p.latest_offset,
                })
                .collect(),
            hourly_distribution: self
                .hourly_distribution
                .iter()
                .map(|h| kafkalyzer_core::kafka_types::HourlyCount {
                    hour: h.hour,
                    count: h.count,
                    percentage: h.percentage,
                })
                .collect(),
            top_keys: self
                .top_keys
                .iter()
                .map(|k| kafkalyzer_core::kafka_types::KeyOccurrence {
                    key: k.key.clone(),
                    count: k.count,
                    percentage: k.percentage,
                })
                .collect(),
            content_type_distribution: self
                .content_type_distribution
                .iter()
                .map(|t| kafkalyzer_core::kafka_types::TypeOccurrence {
                    type_name: t.type_name.clone(),
                    count: t.count,
                    percentage: t.percentage,
                })
                .collect(),
            field_frequencies: self
                .field_frequencies
                .iter()
                .map(|f| kafkalyzer_core::kafka_types::FieldOccurrence {
                    field_name: f.field_name.clone(),
                    count: f.count,
                    percentage: f.percentage,
                    top_values: f
                        .top_values
                        .iter()
                        .map(|v| kafkalyzer_core::kafka_types::FieldValueOccurrence {
                            value: v.value.clone(),
                            count: v.count,
                            percentage: v.percentage,
                            truncated: v.truncated,
                        })
                        .collect(),
                    values_capped: f.values_capped,
                })
                .collect(),
            scan_duration_ms: self.scan_duration_ms,
            message_size_percentiles: self
                .message_size_percentiles
                .as_ref()
                .map(|p| p.to_domain()),
            size_percentiles_estimated: self.size_percentiles_estimated,
            estimated_distinct_keys: self.estimated_distinct_keys,
            key_cardinality_capped: self.key_cardinality_capped,
            hourly_timeline: self.hourly_timeline.iter().map(|b| b.to_domain()).collect(),
            scan_reference_time_ms: self.scan_reference_time_ms,
            complete_from_ms: self.complete_from_ms,
            timeline_outside_count: self.timeline_outside_count,
            value_filter_result: self.value_filter_result.as_ref().map(|r| r.to_domain()),
            duplicate_analysis_result: self
                .duplicate_analysis_result
                .as_ref()
                .map(|d| d.to_domain()),
        }
    }
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
            message_size_percentiles: r.message_size_percentiles.map(SizePercentiles::from),
            size_percentiles_estimated: r.size_percentiles_estimated,
            estimated_distinct_keys: r.estimated_distinct_keys,
            key_cardinality_capped: r.key_cardinality_capped,
            hourly_timeline: r
                .hourly_timeline
                .into_iter()
                .map(HourBucket::from)
                .collect(),
            scan_reference_time_ms: r.scan_reference_time_ms,
            complete_from_ms: r.complete_from_ms,
            timeline_outside_count: r.timeline_outside_count,
            value_filter_result: r.value_filter_result.map(ValueFilterResult::from),
            duplicate_analysis_result: r
                .duplicate_analysis_result
                .map(DuplicateAnalysisResult::from),
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

#[cfg(test)]
mod tests {
    use kafkalyzer_core::consumer_group_protocol::TopicPartition as DomainTopicPartition;
    use kafkalyzer_core::kafka_types::{ConsumerGroupLag, ConsumerGroupMember};

    fn member(id: &str, partitions: &[(String, i32)]) -> ConsumerGroupMember {
        ConsumerGroupMember {
            member_id: id.to_string(),
            client_id: format!("{id}-client"),
            client_host: "10.0.0.1".to_string(),
            subscriptions: vec!["orders".to_string()],
            assignments: partitions
                .iter()
                .map(|(topic, partition)| DomainTopicPartition {
                    topic: topic.clone(),
                    partition: *partition,
                })
                .collect(),
            assignment_decodable: true,
        }
    }

    #[test]
    fn group_lag_carries_members_and_their_partitions() {
        let group = ConsumerGroupLag {
            group_id: "orders-consumers".to_string(),
            state: "Stable".to_string(),
            protocol_type: "consumer".to_string(),
            partition_lags: Vec::new(),
            members_count: 3,
            topics_count: 1,
            members: vec![
                member("m-1", &[("orders".to_string(), 0)]),
                member("m-2", &[("orders".to_string(), 1)]),
                member("m-3", &[]),
            ],
            unassigned_partitions: vec![DomainTopicPartition {
                topic: "orders".to_string(),
                partition: 2,
            }],
        };

        let mapped = ConsumerGroupLag::from(group);

        assert_eq!(mapped.members.len(), 3);
        assert_eq!(mapped.members[0].assignments[0].partition, 0);
        assert_eq!(mapped.members[1].client_id, "m-2-client");
        assert!(mapped.members[2].assignments.is_empty());
        assert_eq!(mapped.unassigned_partitions.len(), 1);
        assert_eq!(mapped.unassigned_partitions[0].partition, 2);
    }
}
