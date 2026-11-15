use crate::api::kafka_types::ClusterProfile;
use anyhow::Result;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TlsProbeOutcome {
    NoTls,
    Verified,
    CertificateRejected,
    Inconclusive,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TlsProbeResult {
    pub outcome: TlsProbeOutcome,
    pub message: Option<String>,
}

pub fn probe_tls_verification(profile: ClusterProfile) -> TlsProbeResult {
    match kafkalyzer_kafka::kafka_metadata::probe_tls_verification(&profile.to_domain()) {
        kafkalyzer_kafka::kafka_metadata::TlsProbe::NoTls => TlsProbeResult {
            outcome: TlsProbeOutcome::NoTls,
            message: None,
        },
        kafkalyzer_kafka::kafka_metadata::TlsProbe::Verified => TlsProbeResult {
            outcome: TlsProbeOutcome::Verified,
            message: None,
        },
        kafkalyzer_kafka::kafka_metadata::TlsProbe::CertificateRejected(msg) => TlsProbeResult {
            outcome: TlsProbeOutcome::CertificateRejected,
            message: Some(msg),
        },
        kafkalyzer_kafka::kafka_metadata::TlsProbe::Inconclusive(msg) => TlsProbeResult {
            outcome: TlsProbeOutcome::Inconclusive,
            message: Some(msg),
        },
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicMetadataErrorKind {
    NotAuthorized,
    NotFound,
    Other,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicMetadataError {
    pub kind: TopicMetadataErrorKind,
    pub message: String,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicMetadataErrorKind> for TopicMetadataErrorKind {
    fn from(kind: kafkalyzer_kafka::kafka_metadata::TopicMetadataErrorKind) -> Self {
        match kind {
            kafkalyzer_kafka::kafka_metadata::TopicMetadataErrorKind::NotAuthorized => {
                Self::NotAuthorized
            }
            kafkalyzer_kafka::kafka_metadata::TopicMetadataErrorKind::NotFound => Self::NotFound,
            kafkalyzer_kafka::kafka_metadata::TopicMetadataErrorKind::Other => Self::Other,
        }
    }
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicMetadataError> for TopicMetadataError {
    fn from(err: kafkalyzer_kafka::kafka_metadata::TopicMetadataError) -> Self {
        Self {
            kind: err.kind.into(),
            message: err.message,
        }
    }
}

#[derive(Debug, Clone)]
pub struct TopicMetadata {
    pub name: String,
    pub partition_count: i32,
    pub replication_factor: i32,
    pub cleanup_policy: Option<String>,
    pub retention_ms: Option<String>,
    /// `None` when the broker gave no usable partition list for this topic.
    pub under_replicated_partitions: Option<i32>,
    pub leaderless_partitions: Option<i32>,
    pub metadata_error: Option<TopicMetadataError>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicConfigStatus {
    Available,
    NotReadable,
    Failed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicConfigSource {
    Unknown,
    DynamicTopic,
    DynamicBroker,
    DynamicDefaultBroker,
    StaticBroker,
    Default,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicConfigSource> for TopicConfigSource {
    fn from(src: kafkalyzer_kafka::kafka_metadata::TopicConfigSource) -> Self {
        match src {
            kafkalyzer_kafka::kafka_metadata::TopicConfigSource::Unknown => Self::Unknown,
            kafkalyzer_kafka::kafka_metadata::TopicConfigSource::DynamicTopic => Self::DynamicTopic,
            kafkalyzer_kafka::kafka_metadata::TopicConfigSource::DynamicBroker => {
                Self::DynamicBroker
            }
            kafkalyzer_kafka::kafka_metadata::TopicConfigSource::DynamicDefaultBroker => {
                Self::DynamicDefaultBroker
            }
            kafkalyzer_kafka::kafka_metadata::TopicConfigSource::StaticBroker => Self::StaticBroker,
            kafkalyzer_kafka::kafka_metadata::TopicConfigSource::Default => Self::Default,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigEntry {
    pub name: String,
    pub value: Option<String>,
    pub source: TopicConfigSource,
    pub is_default: bool,
    pub is_sensitive: bool,
    pub is_read_only: bool,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicConfigEntry> for TopicConfigEntry {
    fn from(entry: kafkalyzer_kafka::kafka_metadata::TopicConfigEntry) -> Self {
        Self {
            name: entry.name,
            value: entry.value,
            source: entry.source.into(),
            is_default: entry.is_default,
            is_sensitive: entry.is_sensitive,
            is_read_only: entry.is_read_only,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigResult {
    pub topic: String,
    pub status: TopicConfigStatus,
    pub message: Option<String>,
    pub entries: Vec<TopicConfigEntry>,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicConfigResult> for TopicConfigResult {
    fn from(res: kafkalyzer_kafka::kafka_metadata::TopicConfigResult) -> Self {
        match res.outcome {
            kafkalyzer_kafka::kafka_metadata::TopicConfigOutcome::Available(entries) => Self {
                topic: res.topic,
                status: TopicConfigStatus::Available,
                message: None,
                entries: entries.into_iter().map(TopicConfigEntry::from).collect(),
            },
            kafkalyzer_kafka::kafka_metadata::TopicConfigOutcome::NotReadable(msg) => Self {
                topic: res.topic,
                status: TopicConfigStatus::NotReadable,
                message: Some(msg),
                entries: Vec::new(),
            },
            kafkalyzer_kafka::kafka_metadata::TopicConfigOutcome::Failed(msg) => Self {
                topic: res.topic,
                status: TopicConfigStatus::Failed,
                message: Some(msg),
                entries: Vec::new(),
            },
        }
    }
}

/// One partition of one topic, with the health flags already decided in Rust so
/// the Dart side never has to re-implement the classification.
#[derive(Debug, Clone)]
pub struct PartitionRow {
    pub partition: i32,
    pub leader: Option<i32>,
    pub replicas: Vec<i32>,
    pub in_sync_replicas: Vec<i32>,
    pub under_replicated: bool,
    pub leaderless: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BrokerEndpoint {
    pub id: i32,
    pub host: String,
    pub port: i32,
}

impl From<kafkalyzer_kafka::kafka_metadata::BrokerEndpoint> for BrokerEndpoint {
    fn from(b: kafkalyzer_kafka::kafka_metadata::BrokerEndpoint) -> Self {
        Self {
            id: b.id,
            host: b.host,
            port: b.port,
        }
    }
}

#[derive(Debug, Clone)]
pub struct TopicPartitionDetails {
    pub topic: String,
    pub partitions: Vec<PartitionRow>,
    pub brokers: Vec<BrokerEndpoint>,
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicMetadata> for TopicMetadata {
    fn from(meta: kafkalyzer_kafka::kafka_metadata::TopicMetadata) -> Self {
        Self {
            name: meta.name,
            partition_count: meta.partition_count,
            replication_factor: meta.replication_factor,
            cleanup_policy: meta.cleanup_policy,
            retention_ms: meta.retention_ms,
            under_replicated_partitions: meta.under_replicated_partitions,
            leaderless_partitions: meta.leaderless_partitions,
            metadata_error: meta.metadata_error.map(TopicMetadataError::from),
        }
    }
}

impl From<kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails> for TopicPartitionDetails {
    fn from(details: kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails) -> Self {
        Self {
            topic: details.topic,
            partitions: details
                .partitions
                .into_iter()
                .map(|p| {
                    let under_replicated = p.is_under_replicated();
                    let leaderless = p.is_leaderless();
                    PartitionRow {
                        partition: p.partition,
                        leader: p.leader,
                        replicas: p.replicas,
                        in_sync_replicas: p.in_sync_replicas,
                        under_replicated,
                        leaderless,
                    }
                })
                .collect(),
            brokers: details
                .brokers
                .into_iter()
                .map(|b| BrokerEndpoint {
                    id: b.id,
                    host: b.host,
                    port: b.port,
                })
                .collect(),
        }
    }
}

pub fn validate_connection(profile: ClusterProfile) -> Result<bool> {
    let domain_profile = profile.to_domain();
    kafkalyzer_kafka::kafka_metadata::validate_connection(domain_profile)
}

pub fn fetch_topics(profile: ClusterProfile) -> Result<Vec<TopicMetadata>> {
    let domain_profile = profile.to_domain();
    let topics = kafkalyzer_kafka::kafka_metadata::fetch_topics(domain_profile)?;
    Ok(topics.into_iter().map(TopicMetadata::from).collect())
}

pub fn fetch_topic_metadata(profile: ClusterProfile, topic: String) -> Result<TopicMetadata> {
    let domain_profile = profile.to_domain();
    let meta = kafkalyzer_kafka::kafka_metadata::fetch_topic_metadata(domain_profile, topic)?;
    Ok(TopicMetadata::from(meta))
}

pub fn describe_topic_configs(
    profile: ClusterProfile,
    topics: Vec<String>,
) -> Result<Vec<TopicConfigResult>> {
    let domain_profile = profile.to_domain();
    let results = kafkalyzer_kafka::kafka_metadata::describe_topic_configs(domain_profile, topics)?;
    Ok(results.into_iter().map(TopicConfigResult::from).collect())
}

pub fn fetch_topic_partitions(
    profile: ClusterProfile,
    topic: String,
) -> Result<TopicPartitionDetails> {
    let domain_profile = profile.to_domain();
    let details = kafkalyzer_kafka::kafka_metadata::fetch_topic_partitions(domain_profile, topic)?;
    Ok(TopicPartitionDetails::from(details))
}

pub fn fetch_consumer_lags(
    profile: ClusterProfile,
) -> Result<Vec<crate::api::kafka_types::ConsumerGroupLag>> {
    let domain_profile = profile.to_domain();
    let group_lags = kafkalyzer_kafka::kafka_metadata::fetch_consumer_lags(domain_profile)?;
    Ok(group_lags
        .into_iter()
        .map(crate::api::kafka_types::ConsumerGroupLag::from)
        .collect())
}

pub fn fetch_consumer_groups(
    profile: ClusterProfile,
) -> Result<Vec<crate::api::kafka_types::ConsumerGroupLag>> {
    let domain_profile = profile.to_domain();
    let groups = kafkalyzer_kafka::kafka_metadata::fetch_consumer_groups(domain_profile)?;
    Ok(groups
        .into_iter()
        .map(crate::api::kafka_types::ConsumerGroupLag::from)
        .collect())
}

pub fn fetch_consumer_group_lag(
    profile: ClusterProfile,
    group_id: String,
) -> Result<crate::api::kafka_types::ConsumerGroupLag> {
    let domain_profile = profile.to_domain();
    let group_lag =
        kafkalyzer_kafka::kafka_metadata::fetch_consumer_group_lag(domain_profile, group_id)?;
    Ok(crate::api::kafka_types::ConsumerGroupLag::from(group_lag))
}

pub fn fetch_consumer_group_lags(
    profile: ClusterProfile,
    group_ids: Vec<String>,
) -> Result<Vec<crate::api::kafka_types::ConsumerGroupLag>> {
    let domain_profile = profile.to_domain();
    let group_lags =
        kafkalyzer_kafka::kafka_metadata::fetch_consumer_group_lags(domain_profile, group_ids)?;
    Ok(group_lags
        .into_iter()
        .map(crate::api::kafka_types::ConsumerGroupLag::from)
        .collect())
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum PartitionOffsetState {
    Known,
    NotReadable,
    Failed,
    TimedOut,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OffsetSkewStatus {
    NotRequested,
    SinglePartition,
    Incomplete,
    Empty,
    Balanced,
    Skewed,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PartitionOffsetRow {
    pub partition: i32,
    pub state: PartitionOffsetState,
    pub error: Option<String>,
    pub low: Option<i64>,
    pub high: Option<i64>,
    pub span: Option<i64>,
    pub share_percent: Option<f64>,
    pub skewed: bool,
}

#[derive(Debug, Clone, PartialEq)]
pub struct PartitionOffsetDistribution {
    pub topic: String,
    pub read_at_ms: i64,
    pub partitions: Vec<PartitionOffsetRow>,
    pub total_span: Option<i64>,
    pub known_span: i64,
    pub complete: bool,
    pub skew_status: OffsetSkewStatus,
    pub skew_threshold_percent: Option<u32>,
}

impl From<&kafkalyzer_core::offset_distribution::PartitionShare> for PartitionOffsetRow {
    fn from(share: &kafkalyzer_core::offset_distribution::PartitionShare) -> Self {
        use kafkalyzer_core::offset_distribution::WatermarkRead;
        let (state, error, low, high) = match &share.read {
            WatermarkRead::Known { low, high } => {
                (PartitionOffsetState::Known, None, Some(*low), Some(*high))
            }
            WatermarkRead::NotReadable(msg) => (
                PartitionOffsetState::NotReadable,
                Some(msg.clone()),
                None,
                None,
            ),
            WatermarkRead::Failed(msg) => {
                (PartitionOffsetState::Failed, Some(msg.clone()), None, None)
            }
            WatermarkRead::TimedOut => (PartitionOffsetState::TimedOut, None, None, None),
        };
        Self {
            partition: share.partition,
            state,
            error,
            low,
            high,
            span: share.span,
            share_percent: share.share_percent,
            skewed: share.skewed,
        }
    }
}

impl From<&kafkalyzer_core::offset_distribution::SkewStatus> for OffsetSkewStatus {
    fn from(status: &kafkalyzer_core::offset_distribution::SkewStatus) -> Self {
        use kafkalyzer_core::offset_distribution::{SkewSkipReason, SkewStatus};
        match status {
            SkewStatus::NotRequested => Self::NotRequested,
            SkewStatus::NotEvaluated(SkewSkipReason::SinglePartition) => Self::SinglePartition,
            SkewStatus::NotEvaluated(SkewSkipReason::Incomplete) => Self::Incomplete,
            SkewStatus::NotEvaluated(SkewSkipReason::Empty) => Self::Empty,
            SkewStatus::Balanced => Self::Balanced,
            SkewStatus::Skewed(_) => Self::Skewed,
        }
    }
}

impl PartitionOffsetDistribution {
    fn from_domain(
        topic: String,
        read_at_ms: i64,
        distribution: kafkalyzer_core::offset_distribution::OffsetDistribution,
        skew_threshold_percent: Option<u8>,
    ) -> Self {
        Self {
            topic,
            read_at_ms,
            partitions: distribution
                .rows
                .iter()
                .map(PartitionOffsetRow::from)
                .collect(),
            total_span: distribution.total_span,
            known_span: distribution.known_span,
            complete: distribution.complete,
            skew_status: OffsetSkewStatus::from(&distribution.skew),
            skew_threshold_percent: skew_threshold_percent.map(u32::from),
        }
    }
}

fn validate_skew_threshold(skew_threshold_percent: Option<u32>) -> Result<Option<u8>> {
    match skew_threshold_percent {
        None => Ok(None),
        Some(t) if (1..=100).contains(&t) => Ok(Some(t as u8)),
        Some(t) => anyhow::bail!("skew_threshold_percent must be between 1 and 100, got {t}"),
    }
}

pub fn fetch_partition_offsets(
    profile: ClusterProfile,
    topic: String,
    skew_threshold_percent: Option<u32>,
) -> Result<PartitionOffsetDistribution> {
    let threshold = validate_skew_threshold(skew_threshold_percent)?;
    let offsets =
        kafkalyzer_kafka::kafka_metadata::fetch_partition_offsets(&profile.to_domain(), &topic)?;
    let distribution =
        kafkalyzer_core::offset_distribution::summarize_offsets(&offsets.partitions, threshold);
    Ok(PartitionOffsetDistribution::from_domain(
        offsets.topic,
        offsets.read_at_ms,
        distribution,
        threshold,
    ))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClusterOverview {
    pub brokers: Vec<BrokerEndpoint>,
    pub cluster_id: Option<String>,
    pub controller_id: Option<i32>,
}

impl From<kafkalyzer_kafka::kafka_metadata::ClusterOverview> for ClusterOverview {
    fn from(overview: kafkalyzer_kafka::kafka_metadata::ClusterOverview) -> Self {
        Self {
            brokers: overview
                .brokers
                .into_iter()
                .map(BrokerEndpoint::from)
                .collect(),
            cluster_id: overview.cluster_id,
            controller_id: overview.controller_id,
        }
    }
}

pub fn fetch_cluster_overview(profile: ClusterProfile) -> Result<ClusterOverview> {
    let overview = kafkalyzer_kafka::kafka_metadata::fetch_cluster_overview(&profile.to_domain())?;
    Ok(ClusterOverview::from(overview))
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TimeRangeTimestampKind {
    CreateTime,
    LogAppendTime,
}

impl From<kafkalyzer_core::topic_time_range::TimestampKind> for TimeRangeTimestampKind {
    fn from(kind: kafkalyzer_core::topic_time_range::TimestampKind) -> Self {
        match kind {
            kafkalyzer_core::topic_time_range::TimestampKind::CreateTime => Self::CreateTime,
            kafkalyzer_core::topic_time_range::TimestampKind::LogAppendTime => Self::LogAppendTime,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ProbeOutcomeKind {
    Found,
    Empty,
    NotFoundInWindow,
    NoTimestamp,
    TimedOut,
    Unreadable,
    Failed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PartitionTimestamp {
    pub partition: i32,
    pub offset: i64,
    pub timestamp_ms: i64,
    pub timestamp_type: TimeRangeTimestampKind,
}

impl From<kafkalyzer_core::topic_time_range::PartitionTimestamp> for PartitionTimestamp {
    fn from(ts: kafkalyzer_core::topic_time_range::PartitionTimestamp) -> Self {
        Self {
            partition: ts.partition,
            offset: ts.offset,
            timestamp_ms: ts.timestamp_ms,
            timestamp_type: TimeRangeTimestampKind::from(ts.timestamp_type),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PartitionTimeProbeOutcome {
    pub kind: ProbeOutcomeKind,
    pub offset: Option<i64>,
    pub timestamp_ms: Option<i64>,
    pub timestamp_type: Option<TimeRangeTimestampKind>,
    pub reason: Option<String>,
}

impl From<&kafkalyzer_core::topic_time_range::ProbeOutcome> for PartitionTimeProbeOutcome {
    fn from(outcome: &kafkalyzer_core::topic_time_range::ProbeOutcome) -> Self {
        use kafkalyzer_core::topic_time_range::ProbeOutcome;
        match outcome {
            ProbeOutcome::Found {
                offset,
                timestamp_ms,
                timestamp_type,
            } => Self {
                kind: ProbeOutcomeKind::Found,
                offset: Some(*offset),
                timestamp_ms: Some(*timestamp_ms),
                timestamp_type: Some(TimeRangeTimestampKind::from(*timestamp_type)),
                reason: None,
            },
            ProbeOutcome::Empty => Self {
                kind: ProbeOutcomeKind::Empty,
                offset: None,
                timestamp_ms: None,
                timestamp_type: None,
                reason: None,
            },
            ProbeOutcome::NotFoundInWindow => Self {
                kind: ProbeOutcomeKind::NotFoundInWindow,
                offset: None,
                timestamp_ms: None,
                timestamp_type: None,
                reason: None,
            },
            ProbeOutcome::NoTimestamp => Self {
                kind: ProbeOutcomeKind::NoTimestamp,
                offset: None,
                timestamp_ms: None,
                timestamp_type: None,
                reason: None,
            },
            ProbeOutcome::TimedOut => Self {
                kind: ProbeOutcomeKind::TimedOut,
                offset: None,
                timestamp_ms: None,
                timestamp_type: None,
                reason: None,
            },
            ProbeOutcome::Unreadable(reason) => Self {
                kind: ProbeOutcomeKind::Unreadable,
                offset: None,
                timestamp_ms: None,
                timestamp_type: None,
                reason: Some(reason.clone()),
            },
            ProbeOutcome::Failed(reason) => Self {
                kind: ProbeOutcomeKind::Failed,
                offset: None,
                timestamp_ms: None,
                timestamp_type: None,
                reason: Some(reason.clone()),
            },
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PartitionTimeProbe {
    pub partition: i32,
    pub oldest: PartitionTimeProbeOutcome,
    pub newest: PartitionTimeProbeOutcome,
}

impl From<&kafkalyzer_core::topic_time_range::PartitionProbe> for PartitionTimeProbe {
    fn from(probe: &kafkalyzer_core::topic_time_range::PartitionProbe) -> Self {
        Self {
            partition: probe.partition,
            oldest: PartitionTimeProbeOutcome::from(&probe.oldest),
            newest: PartitionTimeProbeOutcome::from(&probe.newest),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicTimeRange {
    pub oldest: Option<PartitionTimestamp>,
    pub newest: Option<PartitionTimestamp>,
    pub partitions_total: u32,
    pub partitions_empty: u32,
    pub oldest_known: u32,
    pub newest_known: u32,
    pub all_empty: bool,
    pub probes: Vec<PartitionTimeProbe>,
}

impl From<kafkalyzer_core::topic_time_range::TopicTimeRange> for TopicTimeRange {
    fn from(range: kafkalyzer_core::topic_time_range::TopicTimeRange) -> Self {
        Self {
            oldest: range.oldest.map(PartitionTimestamp::from),
            newest: range.newest.map(PartitionTimestamp::from),
            partitions_total: range.partitions_total as u32,
            partitions_empty: range.partitions_empty as u32,
            oldest_known: range.oldest_known as u32,
            newest_known: range.newest_known as u32,
            all_empty: range.all_empty,
            probes: range.probes.iter().map(PartitionTimeProbe::from).collect(),
        }
    }
}

pub fn fetch_topic_time_range(profile: ClusterProfile, topic: String) -> Result<TopicTimeRange> {
    let range = kafkalyzer_kafka::topic_time_range::fetch_topic_time_range(
        &profile.to_domain(),
        &topic,
        std::time::Duration::from_secs(15),
    )?;
    Ok(TopicTimeRange::from(range))
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_core::partition_health::PartitionMetadata;

    fn details() -> kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails {
        kafkalyzer_kafka::kafka_metadata::TopicPartitionDetails {
            topic: "orders".to_string(),
            partitions: vec![
                PartitionMetadata {
                    partition: 0,
                    leader: Some(1),
                    replicas: vec![1, 2, 3],
                    in_sync_replicas: vec![1, 2, 3],
                },
                PartitionMetadata {
                    partition: 1,
                    leader: Some(2),
                    replicas: vec![1, 2, 3],
                    in_sync_replicas: vec![1, 2],
                },
                PartitionMetadata {
                    partition: 2,
                    leader: None,
                    replicas: vec![1, 2, 3],
                    in_sync_replicas: vec![1],
                },
            ],
            brokers: vec![kafkalyzer_kafka::kafka_metadata::BrokerEndpoint {
                id: 1,
                host: "kafka1".to_string(),
                port: 9092,
            }],
        }
    }

    #[test]
    fn partition_rows_keep_leader_replicas_and_isr() {
        let mapped = TopicPartitionDetails::from(details());

        assert_eq!(mapped.partitions.len(), 3);
        assert_eq!(mapped.partitions[0].leader, Some(1));
        assert_eq!(mapped.partitions[0].replicas, vec![1, 2, 3]);
        assert_eq!(mapped.partitions[0].in_sync_replicas, vec![1, 2, 3]);
        assert!(!mapped.partitions[0].under_replicated);
        assert_eq!(mapped.brokers[0].host, "kafka1");
    }

    #[test]
    fn partition_health_flags_are_decided_in_rust() {
        let mapped = TopicPartitionDetails::from(details());

        assert!(mapped.partitions[1].under_replicated);
        assert!(!mapped.partitions[1].leaderless);
        assert!(mapped.partitions[2].leaderless);
    }

    #[test]
    fn topic_metadata_carries_health_counters() {
        let mapped = TopicMetadata::from(kafkalyzer_kafka::kafka_metadata::TopicMetadata {
            name: "orders".to_string(),
            partition_count: 3,
            replication_factor: 3,
            cleanup_policy: None,
            retention_ms: None,
            under_replicated_partitions: Some(2),
            leaderless_partitions: Some(1),
            metadata_error: None,
        });

        assert_eq!(mapped.under_replicated_partitions, Some(2));
        assert_eq!(mapped.leaderless_partitions, Some(1));
        assert_eq!(mapped.metadata_error, None);
    }

    #[test]
    fn metadata_error_and_config_result_mappings_cover_all_variants() {
        use kafkalyzer_kafka::kafka_metadata as domain;

        assert_eq!(
            TopicMetadataErrorKind::from(domain::TopicMetadataErrorKind::NotAuthorized),
            TopicMetadataErrorKind::NotAuthorized
        );
        assert_eq!(
            TopicMetadataErrorKind::from(domain::TopicMetadataErrorKind::NotFound),
            TopicMetadataErrorKind::NotFound
        );
        assert_eq!(
            TopicMetadataErrorKind::from(domain::TopicMetadataErrorKind::Other),
            TopicMetadataErrorKind::Other
        );

        for (src, dst) in [
            (
                domain::TopicConfigSource::Unknown,
                TopicConfigSource::Unknown,
            ),
            (
                domain::TopicConfigSource::DynamicTopic,
                TopicConfigSource::DynamicTopic,
            ),
            (
                domain::TopicConfigSource::DynamicBroker,
                TopicConfigSource::DynamicBroker,
            ),
            (
                domain::TopicConfigSource::DynamicDefaultBroker,
                TopicConfigSource::DynamicDefaultBroker,
            ),
            (
                domain::TopicConfigSource::StaticBroker,
                TopicConfigSource::StaticBroker,
            ),
            (
                domain::TopicConfigSource::Default,
                TopicConfigSource::Default,
            ),
        ] {
            assert_eq!(TopicConfigSource::from(src), dst);
        }

        let avail = TopicConfigResult::from(domain::TopicConfigResult {
            topic: "orders".to_string(),
            outcome: domain::TopicConfigOutcome::Available(vec![domain::TopicConfigEntry {
                name: "retention.ms".to_string(),
                value: Some("604800000".to_string()),
                source: domain::TopicConfigSource::DynamicTopic,
                is_default: false,
                is_sensitive: false,
                is_read_only: false,
            }]),
        });
        assert_eq!(avail.status, TopicConfigStatus::Available);
        assert_eq!(avail.message, None);
        assert_eq!(avail.entries.len(), 1);
        assert_eq!(avail.entries[0].source, TopicConfigSource::DynamicTopic);

        let not_readable = TopicConfigResult::from(domain::TopicConfigResult {
            topic: "secret".to_string(),
            outcome: domain::TopicConfigOutcome::NotReadable("denied".to_string()),
        });
        assert_eq!(not_readable.status, TopicConfigStatus::NotReadable);
        assert_eq!(not_readable.message.as_deref(), Some("denied"));

        let failed = TopicConfigResult::from(domain::TopicConfigResult {
            topic: "broken".to_string(),
            outcome: domain::TopicConfigOutcome::Failed("timeout".to_string()),
        });
        assert_eq!(failed.status, TopicConfigStatus::Failed);
        assert_eq!(failed.message.as_deref(), Some("timeout"));
    }

    #[test]
    fn partition_offset_distribution_maps_known_and_unreadable_rows() {
        use kafkalyzer_core::offset_distribution::{
            summarize_offsets, PartitionWatermarks, WatermarkRead,
        };

        let dist = summarize_offsets(
            &[
                PartitionWatermarks {
                    partition: 0,
                    read: WatermarkRead::Known { low: 10, high: 90 },
                },
                PartitionWatermarks {
                    partition: 1,
                    read: WatermarkRead::Known { low: 0, high: 20 },
                },
                PartitionWatermarks {
                    partition: 2,
                    read: WatermarkRead::NotReadable("not authorized".to_string()),
                },
                PartitionWatermarks {
                    partition: 3,
                    read: WatermarkRead::Failed("broker error".to_string()),
                },
                PartitionWatermarks {
                    partition: 4,
                    read: WatermarkRead::TimedOut,
                },
            ],
            Some(50),
        );

        let dto = PartitionOffsetDistribution::from_domain(
            "orders".to_string(),
            1_700_000_000_000,
            dist,
            Some(50),
        );
        assert_eq!(dto.topic, "orders");
        assert_eq!(dto.read_at_ms, 1_700_000_000_000);
        assert_eq!(dto.total_span, None);
        assert_eq!(dto.known_span, 100);
        assert!(!dto.complete);
        assert_eq!(dto.skew_status, OffsetSkewStatus::Incomplete);
        assert_eq!(dto.skew_threshold_percent, Some(50));

        assert_eq!(dto.partitions[0].state, PartitionOffsetState::Known);
        assert_eq!(dto.partitions[0].low, Some(10));
        assert_eq!(dto.partitions[0].high, Some(90));
        assert_eq!(dto.partitions[0].span, Some(80));
        assert_eq!(dto.partitions[0].share_percent, None);
        assert!(!dto.partitions[0].skewed);
        assert_eq!(dto.partitions[0].error, None);

        assert_eq!(dto.partitions[2].state, PartitionOffsetState::NotReadable);
        assert_eq!(dto.partitions[2].error.as_deref(), Some("not authorized"));
        assert_eq!(dto.partitions[2].low, None);
        assert_eq!(dto.partitions[2].high, None);
        assert_eq!(dto.partitions[2].span, None);
        assert_eq!(dto.partitions[2].share_percent, None);
        assert!(!dto.partitions[2].skewed);

        assert_eq!(dto.partitions[3].state, PartitionOffsetState::Failed);
        assert_eq!(dto.partitions[3].error.as_deref(), Some("broker error"));

        assert_eq!(dto.partitions[4].state, PartitionOffsetState::TimedOut);
        assert_eq!(dto.partitions[4].error, None);
    }

    #[test]
    fn partition_offset_distribution_maps_skewed_and_threshold_validation() {
        use kafkalyzer_core::offset_distribution::{
            summarize_offsets, PartitionWatermarks, WatermarkRead,
        };

        let dist = summarize_offsets(
            &[
                PartitionWatermarks {
                    partition: 0,
                    read: WatermarkRead::Known { low: 0, high: 80 },
                },
                PartitionWatermarks {
                    partition: 1,
                    read: WatermarkRead::Known { low: 0, high: 20 },
                },
            ],
            Some(50),
        );
        let dto =
            PartitionOffsetDistribution::from_domain("orders".to_string(), 123, dist, Some(50));
        assert_eq!(dto.skew_status, OffsetSkewStatus::Skewed);
        assert_eq!(dto.partitions[0].share_percent, Some(80.0));
        assert!(dto.partitions[0].skewed);
        assert!(!dto.partitions[1].skewed);
        assert_eq!(dto.total_span, Some(100));
        assert!(dto.complete);

        assert!(validate_skew_threshold(Some(0)).is_err());
        assert!(validate_skew_threshold(Some(101)).is_err());
        assert_eq!(validate_skew_threshold(Some(1)).unwrap(), Some(1));
        assert_eq!(validate_skew_threshold(Some(100)).unwrap(), Some(100));
        assert_eq!(validate_skew_threshold(None).unwrap(), None);
    }

    #[test]
    fn cluster_overview_and_topic_time_range_dtos_map_all_variants() {
        use kafkalyzer_core::topic_time_range as core_tr;

        let overview = ClusterOverview::from(kafkalyzer_kafka::kafka_metadata::ClusterOverview {
            brokers: vec![kafkalyzer_kafka::kafka_metadata::BrokerEndpoint {
                id: 1,
                host: "b1".to_string(),
                port: 9092,
            }],
            cluster_id: Some("cid".to_string()),
            controller_id: None,
        });
        assert_eq!(overview.brokers.len(), 1);
        assert_eq!(overview.cluster_id.as_deref(), Some("cid"));
        assert_eq!(overview.controller_id, None);

        let range = core_tr::aggregate(&[
            core_tr::PartitionProbe {
                partition: 0,
                oldest: core_tr::ProbeOutcome::Found {
                    offset: 1,
                    timestamp_ms: 1_000,
                    timestamp_type: core_tr::TimestampKind::CreateTime,
                },
                newest: core_tr::ProbeOutcome::NotFoundInWindow,
            },
            core_tr::PartitionProbe {
                partition: 1,
                oldest: core_tr::ProbeOutcome::Unreadable("denied".to_string()),
                newest: core_tr::ProbeOutcome::TimedOut,
            },
        ]);
        let dto = TopicTimeRange::from(range);
        assert_eq!(dto.partitions_total, 2);
        assert_eq!(dto.oldest_known, 1);
        assert_eq!(dto.newest_known, 0);
        assert_eq!(dto.probes[0].oldest.kind, ProbeOutcomeKind::Found);
        assert_eq!(
            dto.probes[0].newest.kind,
            ProbeOutcomeKind::NotFoundInWindow
        );
        assert_eq!(dto.probes[1].oldest.kind, ProbeOutcomeKind::Unreadable);
        assert_eq!(dto.probes[1].oldest.reason.as_deref(), Some("denied"));
        assert_eq!(dto.probes[1].newest.kind, ProbeOutcomeKind::TimedOut);
    }
}
