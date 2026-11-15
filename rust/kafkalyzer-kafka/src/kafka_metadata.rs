use crate::kafka_utils::create_config;
use anyhow::Result;
use kafkalyzer_core::connection_diagnostics::CapturedLine;
use kafkalyzer_core::consumer_group_protocol::{parse_assignment, parse_subscription};
use kafkalyzer_core::consumer_lag::{
    calculate_lag as core_calculate_lag, classify_partition, unassigned_partitions,
};
use kafkalyzer_core::kafka_types::{
    ClusterProfile, ConsumerGroupLag, ConsumerGroupMember, PartitionLagStatus, TopicPartitionLag,
};
use kafkalyzer_core::offset_distribution::{PartitionWatermarks, WatermarkRead};
use kafkalyzer_core::partition_health::{summarize_topic_health, PartitionMetadata};
use kafkalyzer_core::tls::{classify_tls_failure, TlsFailureClassification};
use kafkalyzer_core::topic_config::{
    TopicConfigEntry as CoreTopicConfigEntry, TopicConfigSource as CoreTopicConfigSource,
    TopicConfigUnavailable,
};
use rdkafka::admin::{
    AdminClient, AdminOptions, ConfigEntry as RdkafkaConfigEntry, ConfigResourceResult,
    ConfigSource, OwnedResourceSpecifier, ResourceSpecifier,
};
use rdkafka::client::{ClientContext, DefaultClientContext};
use rdkafka::config::RDKafkaLogLevel;
use rdkafka::consumer::{BaseConsumer, Consumer, ConsumerContext};
use rdkafka::error::KafkaError;
use rdkafka::types::{RDKafkaErrorCode, RDKafkaRespErr};
use std::collections::{HashMap, HashSet, VecDeque};
use std::ffi::{CStr, CString};
use std::ptr;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::runtime::Runtime;

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

#[derive(Debug, Clone)]
pub struct TopicMetadata {
    pub name: String,
    pub partition_count: i32,
    pub replication_factor: i32,
    /// Deprecated on `fetch_topics`; use `describe_topic_configs` instead.
    pub cleanup_policy: Option<String>,
    /// Deprecated on `fetch_topics`; use `describe_topic_configs` instead.
    pub retention_ms: Option<String>,
    /// `None` when the broker gave no usable partition list for this topic.
    pub under_replicated_partitions: Option<i32>,
    pub leaderless_partitions: Option<i32>,
    pub metadata_error: Option<TopicMetadataError>,
}

pub const CONFIG_CHUNK_SIZE: usize = 100;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TopicConfigSource {
    Unknown,
    DynamicTopic,
    DynamicBroker,
    DynamicDefaultBroker,
    StaticBroker,
    Default,
}

impl From<ConfigSource> for TopicConfigSource {
    fn from(src: ConfigSource) -> Self {
        match src {
            ConfigSource::Unknown => Self::Unknown,
            ConfigSource::DynamicTopic => Self::DynamicTopic,
            ConfigSource::DynamicBroker => Self::DynamicBroker,
            ConfigSource::DynamicDefaultBroker => Self::DynamicDefaultBroker,
            ConfigSource::StaticBroker => Self::StaticBroker,
            ConfigSource::Default => Self::Default,
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

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TopicConfigOutcome {
    Available(Vec<TopicConfigEntry>),
    NotReadable(String),
    Failed(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigResult {
    pub topic: String,
    pub outcome: TopicConfigOutcome,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BrokerEndpoint {
    pub id: i32,
    pub host: String,
    pub port: i32,
}

#[derive(Debug, Clone)]
pub struct TopicPartitionDetails {
    pub topic: String,
    pub partitions: Vec<PartitionMetadata>,
    pub brokers: Vec<BrokerEndpoint>,
}

fn partition_metadata(p: &rdkafka::metadata::MetadataPartition) -> PartitionMetadata {
    PartitionMetadata {
        partition: p.id(),
        // Kafka reports "no leader" as -1.
        leader: if p.leader() >= 0 {
            Some(p.leader())
        } else {
            None
        },
        replicas: p.replicas().to_vec(),
        in_sync_replicas: p.isr().to_vec(),
    }
}

pub const OFFSET_READ_MAX_WORKERS: usize = 8;
pub const OFFSET_READ_METADATA_TIMEOUT: Duration = Duration::from_secs(10);
pub const OFFSET_READ_PER_PARTITION_TIMEOUT: Duration = Duration::from_secs(5);
pub const OFFSET_READ_OVERALL_DEADLINE: Duration = Duration::from_secs(30);

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicPartitionOffsets {
    pub topic: String,
    pub read_at_ms: i64,
    pub partitions: Vec<PartitionWatermarks>,
}

pub fn classify_watermark_error(err: &KafkaError) -> WatermarkRead {
    match err.rdkafka_error_code() {
        Some(
            RDKafkaErrorCode::TopicAuthorizationFailed
            | RDKafkaErrorCode::ClusterAuthorizationFailed,
        ) => WatermarkRead::NotReadable(err.to_string()),
        _ => WatermarkRead::Failed(err.to_string()),
    }
}

fn read_partitions_with_deadline<F>(
    partitions: &[i32],
    max_workers: usize,
    per_read_timeout: Duration,
    overall_deadline: Duration,
    reader: F,
) -> Vec<PartitionWatermarks>
where
    F: Fn(i32, Duration) -> WatermarkRead + Sync,
{
    if partitions.is_empty() {
        return Vec::new();
    }

    let worker_count = max_workers.min(partitions.len()).max(1);
    let deadline = Instant::now() + overall_deadline;
    let next_idx = AtomicUsize::new(0);
    let slots: Vec<Mutex<Option<WatermarkRead>>> =
        (0..partitions.len()).map(|_| Mutex::new(None)).collect();

    std::thread::scope(|scope| {
        for _ in 0..worker_count {
            scope.spawn(|| loop {
                let remaining = deadline.saturating_duration_since(Instant::now());
                if remaining.is_zero() {
                    break;
                }
                let idx = next_idx.fetch_add(1, Ordering::Relaxed);
                if idx >= partitions.len() {
                    break;
                }
                let timeout = per_read_timeout.min(remaining);
                let read = reader(partitions[idx], timeout);
                *slots[idx].lock().unwrap() = Some(read);
            });
        }
    });

    let mut out: Vec<PartitionWatermarks> = partitions
        .iter()
        .enumerate()
        .map(|(i, &partition)| PartitionWatermarks {
            partition,
            read: slots[i]
                .lock()
                .unwrap()
                .take()
                .unwrap_or(WatermarkRead::TimedOut),
        })
        .collect();
    out.sort_by_key(|p| p.partition);
    out
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClusterOverview {
    pub brokers: Vec<BrokerEndpoint>,
    pub cluster_id: Option<String>,
    pub controller_id: Option<i32>,
}

fn map_cluster_overview(
    mut brokers: Vec<BrokerEndpoint>,
    cluster_id: Option<String>,
    raw_controller_id: i32,
) -> ClusterOverview {
    brokers.sort_by_key(|b| b.id);
    ClusterOverview {
        brokers,
        cluster_id: cluster_id.filter(|s| !s.is_empty()),
        controller_id: if raw_controller_id >= 0 {
            Some(raw_controller_id)
        } else {
            None
        },
    }
}

/// Fetches cluster broker endpoints, cluster ID, and controller ID using a
/// single read-only metadata request (`fetch_metadata(None)` + cached client
/// cluster/controller IDs).
pub fn fetch_cluster_overview(profile: &ClusterProfile) -> Result<ClusterOverview> {
    let config = create_config(profile);
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer
        .fetch_metadata(None, Duration::from_secs(10))
        .map_err(|e| {
            let msg = e.to_string();
            let is_auth = matches!(
                e,
                rdkafka::error::KafkaError::MetadataFetch(
                    rdkafka::types::RDKafkaErrorCode::ClusterAuthorizationFailed
                        | rdkafka::types::RDKafkaErrorCode::TopicAuthorizationFailed
                )
            ) || msg.to_lowercase().contains("authorization");
            if is_auth {
                anyhow::anyhow!("not readable: {msg}")
            } else {
                anyhow::anyhow!("Failed to fetch cluster metadata: {msg}")
            }
        })?;

    let brokers: Vec<BrokerEndpoint> = metadata
        .brokers()
        .iter()
        .map(|b| BrokerEndpoint {
            id: b.id(),
            host: b.host().to_string(),
            port: b.port(),
        })
        .collect();

    let client_ptr = consumer.client().native_ptr();
    // SAFETY: `client_ptr` is a valid librdkafka handle owned by `consumer` for
    // the duration of this call; timeout 0 reads the response cached by
    // `fetch_metadata` above, and any non-null cluster ID string is freed via
    // `rd_kafka_mem_free`.
    let (cluster_id, raw_controller_id) = unsafe {
        let cid_ptr = rdkafka::bindings::rd_kafka_clusterid(client_ptr, 0);
        let cluster_id = if cid_ptr.is_null() {
            None
        } else {
            let s = std::ffi::CStr::from_ptr(cid_ptr)
                .to_string_lossy()
                .into_owned();
            rdkafka::bindings::rd_kafka_mem_free(client_ptr, cid_ptr as *mut std::ffi::c_void);
            Some(s)
        };
        let controller_id = rdkafka::bindings::rd_kafka_controllerid(client_ptr, 0);
        (cluster_id, controller_id)
    };

    Ok(map_cluster_overview(brokers, cluster_id, raw_controller_id))
}

pub fn fetch_partition_offsets(
    profile: &ClusterProfile,
    topic: &str,
) -> Result<TopicPartitionOffsets> {
    let mut config = create_config(profile);
    config.set("enable.auto.commit", "false");
    let consumer: BaseConsumer = config.create()?;

    let metadata = consumer.fetch_metadata(Some(topic), OFFSET_READ_METADATA_TIMEOUT)?;
    let topic_meta = metadata
        .topics()
        .iter()
        .find(|t| t.name() == topic)
        .ok_or_else(|| anyhow::anyhow!("Topic '{topic}' not found in broker metadata"))?;

    if let Some(err) = topic_meta.error() {
        return Err(anyhow::anyhow!("Topic '{topic}' metadata error: {err:?}"));
    }

    let partitions: Vec<i32> = topic_meta.partitions().iter().map(|p| p.id()).collect();
    if partitions.is_empty() {
        return Err(anyhow::anyhow!("Topic '{topic}' has no partitions"));
    }

    let rows = read_partitions_with_deadline(
        &partitions,
        OFFSET_READ_MAX_WORKERS,
        OFFSET_READ_PER_PARTITION_TIMEOUT,
        OFFSET_READ_OVERALL_DEADLINE,
        |partition, timeout| match consumer.fetch_watermarks(topic, partition, timeout) {
            Ok((low, high)) => WatermarkRead::Known { low, high },
            Err(e) => classify_watermark_error(&e),
        },
    );

    let read_at_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default()
        .as_millis() as i64;

    Ok(TopicPartitionOffsets {
        topic: topic.to_string(),
        read_at_ms,
        partitions: rows,
    })
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TlsProbe {
    NoTls,
    Verified,
    CertificateRejected(String),
    Inconclusive(String),
}

pub(crate) struct ProbeClientContext {
    lines: Mutex<VecDeque<CapturedLine>>,
}

impl ProbeClientContext {
    pub(crate) fn new() -> Self {
        Self {
            lines: Mutex::new(VecDeque::with_capacity(20)),
        }
    }

    #[cfg_attr(not(test), allow(dead_code))]
    pub(crate) fn push_line(&self, line: String) {
        self.push_entry(None, line);
    }

    pub(crate) fn push_entry(&self, code: Option<i32>, text: String) {
        if let Ok(mut guard) = self.lines.lock() {
            if guard.len() >= 20 {
                guard.pop_front();
            }
            guard.push_back(CapturedLine { code, text });
        }
    }

    pub(crate) fn snapshot(&self) -> Vec<String> {
        self.lines
            .lock()
            .map(|g| g.iter().map(|c| c.text.clone()).collect())
            .unwrap_or_default()
    }

    pub(crate) fn snapshot_captured(&self) -> Vec<CapturedLine> {
        self.lines
            .lock()
            .map(|g| g.iter().cloned().collect())
            .unwrap_or_default()
    }
}

impl ClientContext for ProbeClientContext {
    fn log(&self, _level: RDKafkaLogLevel, fac: &str, log_message: &str) {
        self.push_entry(None, format!("{fac}: {log_message}"));
    }

    fn error(&self, error: KafkaError, reason: &str) {
        let code = match &error {
            KafkaError::Global(c) | KafkaError::MetadataFetch(c) => Some(*c as i32),
            _ => None,
        };
        let text = if reason.trim().is_empty() {
            error.to_string()
        } else {
            reason.to_string()
        };
        self.push_entry(code, text);
    }
}

impl ConsumerContext for ProbeClientContext {}

/// Probes a cluster profile with TLS verification forced on, classifying
/// failures as certificate/hostname rejections vs inconclusive errors.
pub fn probe_tls_verification(profile: &ClusterProfile) -> TlsProbe {
    if !profile.uses_tls() {
        return TlsProbe::NoTls;
    }

    let mut verified_profile = profile.clone();
    verified_profile.ssl_verification_disabled = false;
    let config = create_config(&verified_profile);
    let context = ProbeClientContext::new();

    let consumer: BaseConsumer<ProbeClientContext> = match config.create_with_context(context) {
        Ok(c) => c,
        Err(e) => {
            return match classify_tls_failure(&[e.to_string()]) {
                TlsFailureClassification::CertificateRejected(msg) => {
                    TlsProbe::CertificateRejected(msg)
                }
                TlsFailureClassification::Inconclusive(msg) => TlsProbe::Inconclusive(msg),
            };
        }
    };

    match consumer.fetch_metadata(None, std::time::Duration::from_secs(10)) {
        Ok(_) => TlsProbe::Verified,
        Err(err) => {
            let mut lines = consumer.context().snapshot();
            lines.push(err.to_string());
            match classify_tls_failure(&lines) {
                TlsFailureClassification::CertificateRejected(msg) => {
                    TlsProbe::CertificateRejected(msg)
                }
                TlsFailureClassification::Inconclusive(msg) => TlsProbe::Inconclusive(msg),
            }
        }
    }
}

pub fn validate_connection(profile: ClusterProfile) -> Result<bool> {
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;

    let _ = consumer.fetch_metadata(None, std::time::Duration::from_secs(5))?;
    Ok(true)
}

pub fn classify_topic_error(err: RDKafkaRespErr) -> TopicMetadataError {
    let code = RDKafkaErrorCode::from(err);
    let kind = match err {
        RDKafkaRespErr::RD_KAFKA_RESP_ERR_TOPIC_AUTHORIZATION_FAILED => {
            TopicMetadataErrorKind::NotAuthorized
        }
        RDKafkaRespErr::RD_KAFKA_RESP_ERR_UNKNOWN_TOPIC_OR_PART => TopicMetadataErrorKind::NotFound,
        _ => TopicMetadataErrorKind::Other,
    };
    TopicMetadataError {
        kind,
        message: code.to_string(),
    }
}

fn topic_metadata_from(topic_meta: &rdkafka::metadata::MetadataTopic) -> TopicMetadata {
    if let Some(err) = topic_meta.error() {
        return TopicMetadata {
            name: topic_meta.name().to_string(),
            partition_count: 0,
            replication_factor: 0,
            cleanup_policy: None,
            retention_ms: None,
            under_replicated_partitions: None,
            leaderless_partitions: None,
            metadata_error: Some(classify_topic_error(err)),
        };
    }

    let partitions = topic_meta.partitions();
    let partition_count = partitions.len() as i32;
    let replication_factor = if !partitions.is_empty() {
        partitions[0].replicas().len() as i32
    } else {
        0
    };

    let health = summarize_topic_health(
        &partitions
            .iter()
            .map(partition_metadata)
            .collect::<Vec<_>>(),
    );

    TopicMetadata {
        name: topic_meta.name().to_string(),
        partition_count,
        replication_factor,
        cleanup_policy: None,
        retention_ms: None,
        under_replicated_partitions: health.map(|h| h.under_replicated_partitions),
        leaderless_partitions: health.map(|h| h.leaderless_partitions),
        metadata_error: None,
    }
}

pub fn fetch_topics(profile: ClusterProfile) -> Result<Vec<TopicMetadata>> {
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer.fetch_metadata(None, Duration::from_secs(10))?;

    let mut topics: Vec<TopicMetadata> =
        metadata.topics().iter().map(topic_metadata_from).collect();
    topics.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(topics)
}

pub fn fetch_topic_metadata(profile: ClusterProfile, topic: String) -> Result<TopicMetadata> {
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer.fetch_metadata(Some(&topic), Duration::from_secs(10))?;

    if let Some(topic_meta) = metadata.topics().iter().find(|t| t.name() == topic) {
        Ok(topic_metadata_from(topic_meta))
    } else {
        Ok(TopicMetadata {
            name: topic.clone(),
            partition_count: 0,
            replication_factor: 0,
            cleanup_policy: None,
            retention_ms: None,
            under_replicated_partitions: None,
            leaderless_partitions: None,
            metadata_error: Some(TopicMetadataError {
                kind: TopicMetadataErrorKind::NotFound,
                message: format!("Topic '{topic}' not found in cluster metadata"),
            }),
        })
    }
}

#[derive(Debug, Clone)]
pub(crate) struct RawConfigResource {
    pub(crate) topic: String,
    pub(crate) entries: Vec<TopicConfigEntry>,
}

pub(crate) fn classify_chunk_raw(
    requested: &[&str],
    result: std::result::Result<
        Vec<std::result::Result<RawConfigResource, RDKafkaErrorCode>>,
        KafkaError,
    >,
) -> Vec<TopicConfigResult> {
    match result {
        Err(KafkaError::AdminOp(code))
            if matches!(
                code,
                RDKafkaErrorCode::TopicAuthorizationFailed
                    | RDKafkaErrorCode::ClusterAuthorizationFailed
            ) =>
        {
            let msg = code.to_string();
            requested
                .iter()
                .map(|t| TopicConfigResult {
                    topic: (*t).to_string(),
                    outcome: TopicConfigOutcome::NotReadable(msg.clone()),
                })
                .collect()
        }
        Err(err) => {
            let msg = err.to_string();
            requested
                .iter()
                .map(|t| TopicConfigResult {
                    topic: (*t).to_string(),
                    outcome: TopicConfigOutcome::Failed(msg.clone()),
                })
                .collect()
        }
        Ok(resources) => {
            let mut by_topic: HashMap<String, TopicConfigOutcome> =
                HashMap::with_capacity(resources.len());
            for res in resources {
                match res {
                    Ok(mut raw) => {
                        for entry in &mut raw.entries {
                            if entry.is_sensitive {
                                entry.value = None;
                            }
                        }
                        let outcome = if raw.entries.is_empty() {
                            TopicConfigOutcome::NotReadable(
                                "broker returned no configuration entries".to_string(),
                            )
                        } else {
                            TopicConfigOutcome::Available(raw.entries)
                        };
                        by_topic.insert(raw.topic, outcome);
                    }
                    Err(_) => {}
                }
            }
            requested
                .iter()
                .map(|t| {
                    let outcome = by_topic.remove(*t).unwrap_or_else(|| {
                        TopicConfigOutcome::Failed("no result for topic".to_string())
                    });
                    TopicConfigResult {
                        topic: (*t).to_string(),
                        outcome,
                    }
                })
                .collect()
        }
    }
}

fn classify_chunk(
    requested: &[&str],
    result: std::result::Result<Vec<ConfigResourceResult>, KafkaError>,
) -> Vec<TopicConfigResult> {
    let mapped = result.map(|resources| {
        resources
            .into_iter()
            .filter_map(|res| match res {
                Ok(cfg) => {
                    let topic = match cfg.specifier {
                        OwnedResourceSpecifier::Topic(name) => name,
                        _ => return None,
                    };
                    let entries = cfg
                        .entries
                        .into_iter()
                        .map(|e| TopicConfigEntry {
                            name: e.name,
                            value: if e.is_sensitive { None } else { e.value },
                            source: TopicConfigSource::from(e.source),
                            is_default: e.is_default,
                            is_sensitive: e.is_sensitive,
                            is_read_only: e.is_read_only,
                        })
                        .collect();
                    Some(Ok(RawConfigResource { topic, entries }))
                }
                Err(code) => Some(Err(code)),
            })
            .collect()
    });
    classify_chunk_raw(requested, mapped)
}

pub fn describe_topic_configs(
    profile: ClusterProfile,
    topics: Vec<String>,
) -> Result<Vec<TopicConfigResult>> {
    let mut seen = HashSet::with_capacity(topics.len());
    let mut unique = Vec::with_capacity(topics.len());
    for t in topics {
        if seen.insert(t.clone()) {
            unique.push(t);
        }
    }
    if unique.is_empty() {
        return Ok(Vec::new());
    }

    let config = create_config(&profile);
    let rt = Runtime::new()?;
    let admin_client: AdminClient<DefaultClientContext> = config.create()?;
    let admin_options = AdminOptions::new()
        .operation_timeout(Some(Duration::from_secs(10)))
        .request_timeout(Some(Duration::from_secs(15)));

    let mut out = Vec::with_capacity(unique.len());
    for chunk in unique.chunks(CONFIG_CHUNK_SIZE) {
        let requested: Vec<&str> = chunk.iter().map(|s| s.as_str()).collect();
        let specs: Vec<ResourceSpecifier<'_>> = requested
            .iter()
            .map(|t| ResourceSpecifier::Topic(t))
            .collect();
        let res = rt.block_on(admin_client.describe_configs(&specs, &admin_options));
        out.extend(classify_chunk(&requested, res));
    }

    Ok(out)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TopicConfigs {
    pub topic: String,
    pub result: std::result::Result<Vec<CoreTopicConfigEntry>, TopicConfigUnavailable>,
}

/// Maps an rdkafka `ConfigSource` into `kafkalyzer_core::topic_config::TopicConfigSource`.
pub fn map_config_source(src: ConfigSource) -> CoreTopicConfigSource {
    match src {
        ConfigSource::DynamicTopic => CoreTopicConfigSource::DynamicTopic,
        ConfigSource::DynamicBroker => CoreTopicConfigSource::DynamicBroker,
        ConfigSource::DynamicDefaultBroker => CoreTopicConfigSource::DynamicDefaultBroker,
        ConfigSource::StaticBroker => CoreTopicConfigSource::StaticBroker,
        ConfigSource::Default => CoreTopicConfigSource::Default,
        ConfigSource::Unknown => CoreTopicConfigSource::Unknown,
    }
}

/// Maps an rdkafka `ConfigEntry` into `CoreTopicConfigEntry`, redacting sensitive
/// values at the earliest point and dropping `is_read_only`.
pub fn map_config_entry(entry: RdkafkaConfigEntry) -> CoreTopicConfigEntry {
    CoreTopicConfigEntry {
        name: entry.name,
        value: if entry.is_sensitive {
            None
        } else {
            entry.value
        },
        source: map_config_source(entry.source),
        is_default: entry.is_default,
        is_sensitive: entry.is_sensitive,
    }
}

/// Classifies a per-resource `RDKafkaErrorCode` from `describe_configs` into
/// `TopicConfigUnavailable`.
pub fn classify_config_error(code: RDKafkaErrorCode) -> TopicConfigUnavailable {
    match code {
        RDKafkaErrorCode::TopicAuthorizationFailed
        | RDKafkaErrorCode::ClusterAuthorizationFailed => TopicConfigUnavailable::NotAuthorized,
        RDKafkaErrorCode::UnknownTopicOrPartition | RDKafkaErrorCode::UnknownTopic => {
            TopicConfigUnavailable::TopicNotFound
        }
        other => TopicConfigUnavailable::Failed(other.to_string()),
    }
}

pub(crate) fn assemble_detailed_config_chunk(
    requested: &[&str],
    result: std::result::Result<
        Vec<std::result::Result<(String, Vec<CoreTopicConfigEntry>), RDKafkaErrorCode>>,
        String,
    >,
) -> Vec<TopicConfigs> {
    match result {
        Err(msg) => requested
            .iter()
            .map(|t| TopicConfigs {
                topic: (*t).to_string(),
                result: Err(TopicConfigUnavailable::Failed(msg.clone())),
            })
            .collect(),
        Ok(resources) => {
            let mut by_topic: HashMap<
                String,
                std::result::Result<Vec<CoreTopicConfigEntry>, TopicConfigUnavailable>,
            > = HashMap::with_capacity(resources.len());

            // Note: rdkafka 0.36 does not attach a topic name to `Err(RDKafkaErrorCode)`
            // in `ConfigResourceResult`; for single-topic requests we can attribute it
            // directly, and for multi-topic requests a single error is recorded if
            // the topic is missing.
            let mut single_err: Option<TopicConfigUnavailable> = None;
            for res in resources {
                match res {
                    Ok((topic, mut entries)) => {
                        if entries.is_empty() {
                            by_topic.insert(topic, Err(TopicConfigUnavailable::TopicNotFound));
                        } else {
                            entries.sort_by(|a, b| a.name.cmp(&b.name));
                            by_topic.insert(topic, Ok(entries));
                        }
                    }
                    Err(code) => {
                        single_err = Some(classify_config_error(code));
                    }
                }
            }

            requested
                .iter()
                .map(|t| {
                    let res = by_topic.remove(*t).unwrap_or_else(|| {
                        if requested.len() == 1 {
                            if let Some(err) = single_err.clone() {
                                return Err(err);
                            }
                        }
                        Err(TopicConfigUnavailable::Failed(
                            "no result for topic".to_string(),
                        ))
                    });
                    if let Err(ref err) = res {
                        let kind = match err {
                            TopicConfigUnavailable::NotAuthorized => "not_authorized",
                            TopicConfigUnavailable::TopicNotFound => "topic_not_found",
                            TopicConfigUnavailable::Failed(_) => "failed",
                        };
                        log::warn!(
                            "describe_topic_configs_detailed: topic={} status={}",
                            t,
                            kind
                        );
                    }
                    TopicConfigs {
                        topic: (*t).to_string(),
                        result: res,
                    }
                })
                .collect()
        }
    }
}

/// Reads full topic configurations in chunks of up to 100 topics on the shared
/// Tokio runtime with a 10 s request/operation timeout.
pub fn describe_topic_configs_detailed(
    profile: &ClusterProfile,
    topics: &[String],
) -> Vec<TopicConfigs> {
    if topics.is_empty() {
        return Vec::new();
    }

    let config = create_config(profile);
    let admin_client: AdminClient<DefaultClientContext> = match config.create() {
        Ok(client) => client,
        Err(err) => {
            let msg = err.to_string();
            return topics
                .iter()
                .map(|t| {
                    log::warn!("describe_topic_configs_detailed: topic={} status=failed", t);
                    TopicConfigs {
                        topic: t.clone(),
                        result: Err(TopicConfigUnavailable::Failed(msg.clone())),
                    }
                })
                .collect();
        }
    };

    let admin_options = AdminOptions::new()
        .operation_timeout(Some(Duration::from_secs(10)))
        .request_timeout(Some(Duration::from_secs(10)));
    let rt = crate::kafka_consumer::shared_runtime();

    let mut out = Vec::with_capacity(topics.len());
    for chunk in topics.chunks(CONFIG_CHUNK_SIZE) {
        let requested: Vec<&str> = chunk.iter().map(|s| s.as_str()).collect();
        let specs: Vec<ResourceSpecifier<'_>> = requested
            .iter()
            .map(|t| ResourceSpecifier::Topic(t))
            .collect();
        let res = rt.block_on(admin_client.describe_configs(&specs, &admin_options));
        let mapped = res
            .map(|resources| {
                resources
                    .into_iter()
                    .filter_map(|r| match r {
                        Ok(cfg) => match cfg.specifier {
                            OwnedResourceSpecifier::Topic(name) => Some(Ok((
                                name,
                                cfg.entries.into_iter().map(map_config_entry).collect(),
                            ))),
                            _ => None,
                        },
                        Err(code) => Some(Err(code)),
                    })
                    .collect()
            })
            .map_err(|e| e.to_string());
        out.extend(assemble_detailed_config_chunk(&requested, mapped));
    }
    out
}

pub fn fetch_topic_partitions(
    profile: ClusterProfile,
    topic: String,
) -> Result<TopicPartitionDetails> {
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer.fetch_metadata(Some(&topic), std::time::Duration::from_secs(10))?;

    let topic_meta = metadata
        .topics()
        .iter()
        .find(|t| t.name() == topic)
        .ok_or_else(|| anyhow::anyhow!("Topic not found: {}", topic))?;

    if let Some(error) = topic_meta.error() {
        return Err(anyhow::anyhow!(
            "Metadata for topic {} failed: {:?}",
            topic,
            error
        ));
    }

    Ok(TopicPartitionDetails {
        topic,
        partitions: topic_meta
            .partitions()
            .iter()
            .map(partition_metadata)
            .collect(),
        brokers: metadata
            .brokers()
            .iter()
            .map(|b| BrokerEndpoint {
                id: b.id(),
                host: b.host().to_string(),
                port: b.port(),
            })
            .collect(),
    })
}

fn safe_collect_members(group: &rdkafka::groups::GroupInfo) -> Vec<ConsumerGroupMember> {
    // Work around rdkafka 0.36.2 calling slice::from_raw_parts(null, 0) when member_cnt == 0.
    let raw = unsafe {
        &*(group as *const rdkafka::groups::GroupInfo as *const rdkafka_sys::rd_kafka_group_info)
    };
    if raw.member_cnt <= 0 || raw.members.is_null() {
        Vec::new()
    } else {
        collect_members(group.members())
    }
}

fn collect_members(members: &[rdkafka::groups::GroupMemberInfo]) -> Vec<ConsumerGroupMember> {
    members
        .iter()
        .map(|member| {
            let subscriptions =
                parse_subscription(member.metadata().unwrap_or(&[])).unwrap_or_default();
            let assignment = member.assignment().and_then(parse_assignment);
            let assignment_decodable = assignment.is_some();
            ConsumerGroupMember {
                member_id: member.id().to_string(),
                client_id: member.client_id().to_string(),
                client_host: member.client_host().to_string(),
                subscriptions,
                assignments: assignment.unwrap_or_default(),
                assignment_decodable,
            }
        })
        .collect()
}

fn subscribed_topics(members: &[ConsumerGroupMember]) -> HashSet<String> {
    let mut topics = HashSet::new();
    for member in members {
        topics.extend(member.subscriptions.iter().cloned());
        topics.extend(member.assignments.iter().map(|a| a.topic.clone()));
    }
    topics
}

struct QueueGuard(*mut rdkafka_sys::rd_kafka_queue_t);
impl Drop for QueueGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { rdkafka_sys::rd_kafka_queue_destroy(self.0) };
        }
    }
}

struct ListGroupOffsetsReqGuard(*mut rdkafka_sys::rd_kafka_ListConsumerGroupOffsets_t);
impl Drop for ListGroupOffsetsReqGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { rdkafka_sys::rd_kafka_ListConsumerGroupOffsets_destroy(self.0) };
        }
    }
}

struct AdminOptionsGuard(*mut rdkafka_sys::rd_kafka_AdminOptions_t);
impl Drop for AdminOptionsGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { rdkafka_sys::rd_kafka_AdminOptions_destroy(self.0) };
        }
    }
}

struct EventGuard(*mut rdkafka_sys::rd_kafka_event_t);
impl Drop for EventGuard {
    fn drop(&mut self) {
        if !self.0.is_null() {
            unsafe { rdkafka_sys::rd_kafka_event_destroy(self.0) };
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct RawCommittedEntry {
    topic: String,
    partition: i32,
    offset: i64,
    err: Option<String>,
}

type CommittedOffsetMap = HashMap<(String, i32), std::result::Result<i64, String>>;

fn map_raw_committed_entries(entries: Vec<RawCommittedEntry>) -> CommittedOffsetMap {
    let mut map = HashMap::new();
    for entry in entries {
        if let Some(err_msg) = entry.err {
            map.insert((entry.topic, entry.partition), Err(err_msg));
        } else if entry.offset >= 0 {
            map.insert((entry.topic, entry.partition), Ok(entry.offset));
        }
    }
    map
}

/// Lists all committed offsets for `group_id` using librdkafka's read-only
/// `rd_kafka_ListConsumerGroupOffsets` admin call (`partitions = NULL`).
fn list_consumer_group_offsets(
    admin: &AdminClient<DefaultClientContext>,
    group_id: &str,
    timeout: Duration,
) -> std::result::Result<CommittedOffsetMap, String> {
    let c_group = CString::new(group_id).map_err(|_| "Invalid group id".to_string())?;
    let rk = admin.inner().native_ptr();
    let timeout_ms = timeout.as_millis().min(i32::MAX as u128) as i32;

    unsafe {
        let queue = QueueGuard(rdkafka_sys::rd_kafka_queue_new(rk));
        if queue.0.is_null() {
            return Err("Failed to create librdkafka queue".to_string());
        }

        let req = ListGroupOffsetsReqGuard(rdkafka_sys::rd_kafka_ListConsumerGroupOffsets_new(
            c_group.as_ptr(),
            ptr::null(),
        ));
        if req.0.is_null() {
            return Err("Failed to allocate ListConsumerGroupOffsets request".to_string());
        }

        let options = AdminOptionsGuard(rdkafka_sys::rd_kafka_AdminOptions_new(
            rk,
            rdkafka_sys::rd_kafka_admin_op_t::RD_KAFKA_ADMIN_OP_LISTCONSUMERGROUPOFFSETS,
        ));
        if options.0.is_null() {
            return Err("Failed to allocate AdminOptions".to_string());
        }

        let mut err_buf = [0 as std::os::raw::c_char; 512];
        let opt_err = rdkafka_sys::rd_kafka_AdminOptions_set_request_timeout(
            options.0,
            timeout_ms,
            err_buf.as_mut_ptr(),
            err_buf.len(),
        );
        if opt_err != rdkafka_sys::rd_kafka_resp_err_t::RD_KAFKA_RESP_ERR_NO_ERROR {
            let msg = CStr::from_ptr(err_buf.as_ptr())
                .to_string_lossy()
                .into_owned();
            return Err(if msg.is_empty() {
                format!("AdminOptions error: {opt_err:?}")
            } else {
                msg
            });
        }

        let mut req_ptr = req.0;
        rdkafka_sys::rd_kafka_ListConsumerGroupOffsets(rk, &mut req_ptr, 1, options.0, queue.0);

        let rkev = loop {
            let ev = rdkafka_sys::rd_kafka_queue_poll(queue.0, timeout_ms);
            if ev.is_null() {
                return Err(format!(
                    "Timed out listing committed offsets for group '{group_id}'"
                ));
            }
            if rdkafka_sys::rd_kafka_event_type(ev)
                == rdkafka_sys::RD_KAFKA_EVENT_LISTCONSUMERGROUPOFFSETS_RESULT
            {
                break EventGuard(ev);
            }
            rdkafka_sys::rd_kafka_event_destroy(ev);
        };

        let ev_err = rdkafka_sys::rd_kafka_event_error(rkev.0);
        if ev_err != rdkafka_sys::rd_kafka_resp_err_t::RD_KAFKA_RESP_ERR_NO_ERROR {
            let msg = CStr::from_ptr(rdkafka_sys::rd_kafka_event_error_string(rkev.0))
                .to_string_lossy()
                .into_owned();
            return Err(msg);
        }

        let res = rdkafka_sys::rd_kafka_event_ListConsumerGroupOffsets_result(rkev.0);
        if res.is_null() {
            return Err("Missing ListConsumerGroupOffsets result".to_string());
        }

        let mut cnt: usize = 0;
        let groups = rdkafka_sys::rd_kafka_ListConsumerGroupOffsets_result_groups(res, &mut cnt);
        if groups.is_null() || cnt == 0 {
            return Ok(HashMap::new());
        }

        let g = *groups;
        let g_err = rdkafka_sys::rd_kafka_group_result_error(g);
        if !g_err.is_null() {
            let msg = CStr::from_ptr(rdkafka_sys::rd_kafka_error_string(g_err))
                .to_string_lossy()
                .into_owned();
            return Err(msg);
        }

        let tpl = rdkafka_sys::rd_kafka_group_result_partitions(g);
        if tpl.is_null() {
            return Ok(HashMap::new());
        }

        let mut raw = Vec::with_capacity((*tpl).cnt as usize);
        for j in 0..(*tpl).cnt {
            let elem = (*tpl).elems.add(j as usize);
            let topic = if (*elem).topic.is_null() {
                String::new()
            } else {
                CStr::from_ptr((*elem).topic).to_string_lossy().into_owned()
            };
            let err = if (*elem).err != rdkafka_sys::rd_kafka_resp_err_t::RD_KAFKA_RESP_ERR_NO_ERROR
            {
                let err_cstr = rdkafka_sys::rd_kafka_err2str((*elem).err);
                Some(if err_cstr.is_null() {
                    format!("{:?}", (*elem).err)
                } else {
                    CStr::from_ptr(err_cstr).to_string_lossy().into_owned()
                })
            } else {
                None
            };
            raw.push(RawCommittedEntry {
                topic,
                partition: (*elem).partition,
                offset: (*elem).offset,
                err,
            });
        }

        Ok(map_raw_committed_entries(raw))
    }
}

fn fetch_topic_partitions_cached(
    consumer: &BaseConsumer,
    topic_name: &str,
    timeout: Duration,
    cache: &mut HashMap<String, std::result::Result<Vec<i32>, String>>,
) -> std::result::Result<Vec<i32>, String> {
    if let Some(cached) = cache.get(topic_name) {
        return cached.clone();
    }

    let result = match consumer.fetch_metadata(Some(topic_name), timeout) {
        Ok(md) => {
            if let Some(topic_meta) = md.topics().iter().find(|t| t.name() == topic_name) {
                if let Some(err) = topic_meta.error() {
                    Err(format!("Topic not readable: {err:?}"))
                } else {
                    let mut parts: Vec<i32> =
                        topic_meta.partitions().iter().map(|p| p.id()).collect();
                    parts.sort_unstable();
                    Ok(parts)
                }
            } else {
                Err("Topic not found".to_string())
            }
        }
        Err(e) => Err(format!("Failed to describe topic: {e}")),
    };

    cache.insert(topic_name.to_string(), result.clone());
    result
}

fn fetch_watermark_cached(
    consumer: &BaseConsumer,
    topic: &str,
    partition: i32,
    timeout: Duration,
    cache: &mut HashMap<(String, i32), std::result::Result<i64, String>>,
) -> std::result::Result<i64, String> {
    let key = (topic.to_string(), partition);
    if let Some(cached) = cache.get(&key) {
        return cached.clone();
    }

    let result = match consumer.fetch_watermarks(topic, partition, timeout) {
        Ok((_, high)) => Ok(high),
        Err(e) => Err(format!("Log end offset unreadable: {e}")),
    };

    cache.insert(key, result.clone());
    result
}

/// Pure assembly of a `ConsumerGroupLag` from pre-fetched member info,
/// committed offsets, topic metadata, and log-end watermarks.
fn assemble_consumer_group_lag(
    group_id: String,
    state: String,
    protocol_type: String,
    members: Vec<ConsumerGroupMember>,
    committed: std::result::Result<CommittedOffsetMap, String>,
    topic_meta: &HashMap<String, std::result::Result<Vec<i32>, String>>,
    watermarks: &HashMap<(String, i32), std::result::Result<i64, String>>,
) -> ConsumerGroupLag {
    let members_count = members.len() as i32;
    let subscribed = subscribed_topics(&members);

    let committed_map = match committed {
        Ok(map) => map,
        Err(reason) => {
            let subscribed_meta: HashMap<String, Vec<i32>> = subscribed
                .iter()
                .filter_map(|t| {
                    topic_meta
                        .get(t)
                        .and_then(|res| res.as_ref().ok())
                        .map(|parts| (t.clone(), parts.clone()))
                })
                .collect();
            let (ownership_known, unassigned) = if state.eq_ignore_ascii_case("stable") {
                match unassigned_partitions(&subscribed_meta, &members) {
                    Some(u) => (true, u),
                    None => (false, Vec::new()),
                }
            } else {
                (false, Vec::new())
            };
            return ConsumerGroupLag {
                group_id,
                state,
                protocol_type,
                partition_lags: Vec::new(),
                members_count,
                topics_count: subscribed.len() as i32,
                members,
                unassigned_partitions: unassigned,
                lag_error: Some(reason),
                ownership_known,
            };
        }
    };

    let mut group_topics: HashSet<String> = subscribed.clone();
    for (topic, _) in committed_map.keys() {
        group_topics.insert(topic.clone());
    }
    let mut sorted_topics: Vec<String> = group_topics.iter().cloned().collect();
    sorted_topics.sort();

    let mut partition_lags = Vec::new();
    for topic in &sorted_topics {
        match topic_meta.get(topic) {
            Some(Ok(partitions)) => {
                let mut seen_parts = HashSet::new();
                for &partition in partitions {
                    seen_parts.insert(partition);
                    let wm = watermarks
                        .get(&(topic.clone(), partition))
                        .cloned()
                        .unwrap_or_else(|| Err("Watermark unavailable".to_string()));
                    match committed_map.get(&(topic.clone(), partition)) {
                        Some(Err(err_msg)) => partition_lags.push(TopicPartitionLag {
                            topic: topic.clone(),
                            partition,
                            log_end_offset: -1,
                            current_offset: -1,
                            lag: 0,
                            status: PartitionLagStatus::Unknown,
                            error: Some(err_msg.clone()),
                        }),
                        Some(Ok(offset)) => {
                            partition_lags.push(classify_partition(
                                topic,
                                partition,
                                Some(*offset),
                                wm,
                            ));
                        }
                        None => {
                            partition_lags.push(classify_partition(topic, partition, None, wm));
                        }
                    }
                }
                let mut extra_parts: Vec<i32> = committed_map
                    .keys()
                    .filter(|(t, p)| t == topic && !seen_parts.contains(p))
                    .map(|(_, p)| *p)
                    .collect();
                extra_parts.sort_unstable();
                for partition in extra_parts {
                    let wm = watermarks
                        .get(&(topic.clone(), partition))
                        .cloned()
                        .unwrap_or_else(|| Err("Watermark unavailable".to_string()));
                    match committed_map.get(&(topic.clone(), partition)) {
                        Some(Err(err_msg)) => partition_lags.push(TopicPartitionLag {
                            topic: topic.clone(),
                            partition,
                            log_end_offset: -1,
                            current_offset: -1,
                            lag: 0,
                            status: PartitionLagStatus::Unknown,
                            error: Some(err_msg.clone()),
                        }),
                        Some(Ok(offset)) => {
                            partition_lags.push(classify_partition(
                                topic,
                                partition,
                                Some(*offset),
                                wm,
                            ));
                        }
                        None => {}
                    }
                }
            }
            Some(Err(err_msg)) => {
                let mut committed_parts: Vec<i32> = committed_map
                    .keys()
                    .filter(|(t, _)| t == topic)
                    .map(|(_, p)| *p)
                    .collect();
                committed_parts.sort_unstable();
                if committed_parts.is_empty() {
                    partition_lags.push(TopicPartitionLag {
                        topic: topic.clone(),
                        partition: -1,
                        log_end_offset: -1,
                        current_offset: -1,
                        lag: 0,
                        status: PartitionLagStatus::Unknown,
                        error: Some(err_msg.clone()),
                    });
                } else {
                    for partition in committed_parts {
                        partition_lags.push(TopicPartitionLag {
                            topic: topic.clone(),
                            partition,
                            log_end_offset: -1,
                            current_offset: -1,
                            lag: 0,
                            status: PartitionLagStatus::Unknown,
                            error: Some(err_msg.clone()),
                        });
                    }
                }
            }
            None => {
                partition_lags.push(TopicPartitionLag {
                    topic: topic.clone(),
                    partition: -1,
                    log_end_offset: -1,
                    current_offset: -1,
                    lag: 0,
                    status: PartitionLagStatus::Unknown,
                    error: Some("Topic metadata unavailable".to_string()),
                });
            }
        }
    }

    let subscribed_meta: HashMap<String, Vec<i32>> = subscribed
        .iter()
        .filter_map(|t| {
            topic_meta
                .get(t)
                .and_then(|res| res.as_ref().ok())
                .map(|parts| (t.clone(), parts.clone()))
        })
        .collect();
    let (ownership_known, unassigned) = if state.eq_ignore_ascii_case("stable") {
        match unassigned_partitions(&subscribed_meta, &members) {
            Some(u) => (true, u),
            None => (false, Vec::new()),
        }
    } else {
        (false, Vec::new())
    };

    ConsumerGroupLag {
        group_id,
        state,
        protocol_type,
        partition_lags,
        members_count,
        topics_count: group_topics.len() as i32,
        members,
        unassigned_partitions: unassigned,
        lag_error: None,
        ownership_known,
    }
}

struct GroupSnapshot {
    group_id: String,
    state: String,
    protocol_type: String,
    members: Vec<ConsumerGroupMember>,
}

fn fetch_group_list_with_retry(
    main_consumer: &BaseConsumer,
    timeout: Duration,
) -> Result<rdkafka::groups::GroupList> {
    for attempt in 1..=3 {
        match main_consumer.fetch_group_list(None, timeout) {
            Ok(gl) => return Ok(gl),
            Err(KafkaError::GroupListFetch(rdkafka::types::RDKafkaErrorCode::Partial)) => {
                if attempt == 3 {
                    return Err(anyhow::anyhow!(
                        "Group list fetch failed: Partial response after 3 attempts"
                    ));
                }
                std::thread::sleep(Duration::from_millis(500 * attempt));
            }
            Err(e) => return Err(anyhow::Error::from(e)),
        }
    }
    unreachable!("group list retry loop always returns")
}

fn fetch_consumer_lags_for_targets(
    profile: ClusterProfile,
    target_group_ids: Option<Vec<String>>,
) -> Result<Vec<ConsumerGroupLag>> {
    let timeout = Duration::from_secs(5);
    let admin_config = create_config(&profile);
    let admin_client: AdminClient<DefaultClientContext> = admin_config.create()?;

    let mut consumer_config = create_config(&profile);
    consumer_config.set("enable.auto.commit", "false");
    consumer_config.set("enable.auto.offset.store", "false");
    let main_consumer: BaseConsumer = consumer_config.create()?;

    let _ = main_consumer.fetch_metadata(Some("__consumer_offsets"), timeout);
    let group_list = fetch_group_list_with_retry(&main_consumer, timeout)?;

    let mut group_snapshots: HashMap<String, GroupSnapshot> = HashMap::new();
    let mut listed_order: Vec<String> = Vec::new();
    for group in group_list.groups() {
        let protocol_type = group.protocol_type();
        if protocol_type == "consumer" || protocol_type.is_empty() {
            let group_id = group.name().to_string();
            listed_order.push(group_id.clone());
            group_snapshots.insert(
                group_id.clone(),
                GroupSnapshot {
                    group_id,
                    state: group.state().to_string(),
                    protocol_type: protocol_type.to_string(),
                    members: safe_collect_members(group),
                },
            );
        }
    }

    let ordered_ids = target_group_ids.unwrap_or(listed_order);
    let mut topic_meta_cache: HashMap<String, std::result::Result<Vec<i32>, String>> =
        HashMap::new();
    let mut watermark_cache: HashMap<(String, i32), std::result::Result<i64, String>> =
        HashMap::new();
    let mut results = Vec::with_capacity(ordered_ids.len());

    for group_id in ordered_ids {
        if let Some(snapshot) = group_snapshots.get(&group_id) {
            let committed = list_consumer_group_offsets(&admin_client, &snapshot.group_id, timeout);
            let mut needed_topics = subscribed_topics(&snapshot.members);
            if let Ok(ref map) = committed {
                for (topic, _) in map.keys() {
                    needed_topics.insert(topic.clone());
                }
            }

            for topic in &needed_topics {
                if let Ok(partitions) = fetch_topic_partitions_cached(
                    &main_consumer,
                    topic,
                    timeout,
                    &mut topic_meta_cache,
                ) {
                    for partition in partitions {
                        let _ = fetch_watermark_cached(
                            &main_consumer,
                            topic,
                            partition,
                            timeout,
                            &mut watermark_cache,
                        );
                    }
                }
            }

            results.push(assemble_consumer_group_lag(
                snapshot.group_id.clone(),
                snapshot.state.clone(),
                snapshot.protocol_type.clone(),
                snapshot.members.clone(),
                committed,
                &topic_meta_cache,
                &watermark_cache,
            ));
        } else {
            results.push(ConsumerGroupLag {
                group_id,
                state: "Unknown".to_string(),
                protocol_type: "consumer".to_string(),
                partition_lags: Vec::new(),
                members_count: 0,
                topics_count: 0,
                members: Vec::new(),
                unassigned_partitions: Vec::new(),
                lag_error: Some("group not found".to_string()),
                ownership_known: false,
            });
        }
    }

    Ok(results)
}

pub fn fetch_consumer_lags(profile: ClusterProfile) -> Result<Vec<ConsumerGroupLag>> {
    fetch_consumer_lags_for_targets(profile, None)
}

pub fn fetch_consumer_group_lags(
    profile: ClusterProfile,
    group_ids: Vec<String>,
) -> Result<Vec<ConsumerGroupLag>> {
    fetch_consumer_lags_for_targets(profile, Some(group_ids))
}

pub fn fetch_consumer_groups(profile: ClusterProfile) -> Result<Vec<ConsumerGroupLag>> {
    let timeout = Duration::from_secs(5);
    let mut config = create_config(&profile);
    config.set("enable.auto.commit", "false");
    config.set("enable.auto.offset.store", "false");
    let main_consumer: BaseConsumer = config.create()?;

    let _ = main_consumer.fetch_metadata(Some("__consumer_offsets"), timeout);
    let group_list = fetch_group_list_with_retry(&main_consumer, timeout)?;

    let mut results = Vec::new();
    for group in group_list.groups() {
        let protocol_type = group.protocol_type();
        if protocol_type == "consumer" || protocol_type.is_empty() {
            let members = safe_collect_members(group);
            let members_count = members.len() as i32;
            results.push(ConsumerGroupLag {
                group_id: group.name().to_string(),
                state: group.state().to_string(),
                protocol_type: protocol_type.to_string(),
                partition_lags: Vec::new(),
                members_count,
                topics_count: subscribed_topics(&members).len() as i32,
                members,
                unassigned_partitions: Vec::new(),
                lag_error: None,
                ownership_known: false,
            });
        }
    }

    Ok(results)
}

pub fn fetch_consumer_group_lag(
    profile: ClusterProfile,
    group_id: String,
) -> Result<ConsumerGroupLag> {
    let mut items = fetch_consumer_lags_for_targets(profile, Some(vec![group_id]))?;
    items
        .pop()
        .ok_or_else(|| anyhow::anyhow!("Consumer group lag missing from batch result"))
}

pub fn calculate_lag(high_offset: i64, current_offset: i64) -> i64 {
    core_calculate_lag(high_offset, current_offset)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_calculate_lag() {
        assert_eq!(calculate_lag(100, 90), 10);
        assert_eq!(calculate_lag(100, 100), 0);
        assert_eq!(calculate_lag(100, 110), 0);
    }

    #[test]
    fn one_replica_missing_from_isr_counts_as_under_replicated() {
        let partitions = vec![
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
                leader: Some(3),
                replicas: vec![1, 2, 3],
                in_sync_replicas: vec![1, 2, 3],
            },
        ];

        let health = summarize_topic_health(&partitions).unwrap();
        assert_eq!(health.under_replicated_partitions, 1);
        assert_eq!(health.leaderless_partitions, 0);
    }

    #[test]
    fn topic_without_usable_metadata_reports_no_healthy_partitions() {
        // An errored or empty topic must not be summarized as "0 problems".
        assert_eq!(summarize_topic_health(&[]), None);
    }

    #[test]
    fn map_raw_committed_entries_filters_invalid_and_keeps_errors() {
        let mapped = map_raw_committed_entries(vec![
            RawCommittedEntry {
                topic: "orders".to_string(),
                partition: 0,
                offset: 100,
                err: None,
            },
            RawCommittedEntry {
                topic: "orders".to_string(),
                partition: 1,
                offset: -1001,
                err: None,
            },
            RawCommittedEntry {
                topic: "orders".to_string(),
                partition: 2,
                offset: -1,
                err: Some("Topic authorization failed".to_string()),
            },
        ]);
        assert_eq!(mapped.get(&("orders".to_string(), 0)), Some(&Ok(100)));
        assert_eq!(mapped.get(&("orders".to_string(), 1)), None);
        assert_eq!(
            mapped.get(&("orders".to_string(), 2)),
            Some(&Err("Topic authorization failed".to_string()))
        );
    }

    #[test]
    fn assemble_consumer_group_lag_handles_empty_group_and_unreadable_topic() {
        let mut committed = HashMap::new();
        committed.insert(("lag-spike".to_string(), 0), Ok(0));
        committed.insert(("lag-spike".to_string(), 2), Ok(100));
        committed.insert(("secret".to_string(), 0), Ok(5));

        let topic_meta = HashMap::from([
            ("lag-spike".to_string(), Ok(vec![0, 1, 2])),
            (
                "secret".to_string(),
                Err("Topic not readable: TopicAuthorizationFailed".to_string()),
            ),
        ]);
        let watermarks = HashMap::from([
            (("lag-spike".to_string(), 0), Ok(0)),
            (("lag-spike".to_string(), 1), Ok(0)),
            (("lag-spike".to_string(), 2), Ok(150)),
        ]);

        let res = assemble_consumer_group_lag(
            "lag-spike-g".to_string(),
            "Empty".to_string(),
            "consumer".to_string(),
            Vec::new(),
            Ok(committed),
            &topic_meta,
            &watermarks,
        );

        assert_eq!(res.lag_error, None);
        assert!(!res.ownership_known);
        assert!(res.unassigned_partitions.is_empty());
        assert_eq!(res.topics_count, 2);
        assert_eq!(res.partition_lags.len(), 4);

        let p0 = res
            .partition_lags
            .iter()
            .find(|p| p.topic == "lag-spike" && p.partition == 0)
            .unwrap();
        assert_eq!(p0.status, PartitionLagStatus::Known);
        assert_eq!(p0.lag, 0);

        let p1 = res
            .partition_lags
            .iter()
            .find(|p| p.topic == "lag-spike" && p.partition == 1)
            .unwrap();
        assert_eq!(p1.status, PartitionLagStatus::NoCommit);

        let p2 = res
            .partition_lags
            .iter()
            .find(|p| p.topic == "lag-spike" && p.partition == 2)
            .unwrap();
        assert_eq!(p2.status, PartitionLagStatus::Known);
        assert_eq!(p2.lag, 50);

        let sec = res
            .partition_lags
            .iter()
            .find(|p| p.topic == "secret")
            .unwrap();
        assert_eq!(sec.status, PartitionLagStatus::Unknown);
    }

    #[test]
    fn assemble_consumer_group_lag_keeps_group_error() {
        let res = assemble_consumer_group_lag(
            "broken-g".to_string(),
            "Empty".to_string(),
            "consumer".to_string(),
            Vec::new(),
            Err("GroupAuthorizationFailed".to_string()),
            &HashMap::new(),
            &HashMap::new(),
        );
        assert_eq!(res.lag_error.as_deref(), Some("GroupAuthorizationFailed"));
        assert!(!res.ownership_known);
    }

    #[test]
    #[ignore = "Requires local docker compose kafka on localhost:9094 with lag-spike-g fixture"]
    fn integration_lag_spike_g_empty_group_has_accurate_lags() {
        let profile = ClusterProfile {
            name: "local".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };
        let lag = fetch_consumer_group_lag(profile, "lag-spike-g".to_string()).unwrap();
        assert_eq!(lag.state, "Empty");
        assert_eq!(lag.lag_error, None);
        assert!(!lag.ownership_known);
        let spike_parts: Vec<_> = lag
            .partition_lags
            .iter()
            .filter(|p| p.topic == "lag-spike")
            .collect();
        assert_eq!(spike_parts.len(), 3);
        assert_eq!(spike_parts[0].status, PartitionLagStatus::Known);
        assert_eq!(spike_parts[1].status, PartitionLagStatus::NoCommit);
        assert_eq!(spike_parts[2].status, PartitionLagStatus::Known);
        assert_eq!(spike_parts[2].lag, 50);
    }

    #[test]
    fn probe_tls_verification_returns_no_tls_for_plaintext_without_network() {
        let profile = ClusterProfile {
            name: "plain".to_string(),
            bootstrap_servers: "127.0.0.1:1".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };
        assert_eq!(probe_tls_verification(&profile), TlsProbe::NoTls);
    }

    #[test]
    fn probe_client_context_caps_captured_lines_and_classifies() {
        let ctx = ProbeClientContext::new();
        for i in 0..25 {
            ctx.push_line(format!("line {i}"));
        }
        let snap = ctx.snapshot();
        assert_eq!(snap.len(), 20);
        assert_eq!(snap.first().unwrap(), "line 5");

        ctx.push_line("SSL handshake failed: certificate verify failed".to_string());
        let classified = classify_tls_failure(&ctx.snapshot());
        assert!(matches!(
            classified,
            TlsFailureClassification::CertificateRejected(_)
        ));
    }

    #[test]
    #[ignore = "Spike 1.1: requires local docker compose kafka on localhost:9094 with 1000 spike-t-* topics"]
    fn spike_describe_configs_and_single_topic_metadata() {
        use std::time::Instant;

        let profile = ClusterProfile {
            name: "spike".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };

        let rt = Runtime::new().unwrap();
        let config = create_config(&profile);
        let admin: AdminClient<DefaultClientContext> = config.create().unwrap();
        let missing_name = "does-not-exist-spike-11-9f8e7d6c";

        // (a) describe_configs for [existing, missing]
        let existing_name = "spike-t-0000";
        let res_pair = rt.block_on(async {
            let specs = [
                ResourceSpecifier::Topic(existing_name),
                ResourceSpecifier::Topic(missing_name),
            ];
            let opts = AdminOptions::new()
                .operation_timeout(Some(Duration::from_secs(10)))
                .request_timeout(Some(Duration::from_secs(15)));
            admin.describe_configs(&specs, &opts).await
        });
        match &res_pair {
            Ok(results) => {
                for r in results {
                    match r {
                        Ok(cfg) => println!(
                            "SPIKE_A: Ok resource={:?} entries_len={}",
                            cfg.specifier,
                            cfg.entries.len()
                        ),
                        Err(e) => println!("SPIKE_A: per-item Err={e:?}"),
                    }
                }
            }
            Err(e) => println!("SPIKE_A: outer Err={e:?}"),
        }

        // (b) measure describe_configs for 100 and 500 topics
        let topics_500: Vec<String> = (0..500).map(|i| format!("spike-t-{i:04}")).collect();
        for count in [100usize, 500usize] {
            let start = Instant::now();
            let res = rt.block_on(async {
                let specs: Vec<ResourceSpecifier<'_>> = topics_500[..count]
                    .iter()
                    .map(|t| ResourceSpecifier::Topic(t.as_str()))
                    .collect();
                let opts = AdminOptions::new()
                    .operation_timeout(Some(Duration::from_secs(10)))
                    .request_timeout(Some(Duration::from_secs(15)));
                admin.describe_configs(&specs, &opts).await
            });
            let elapsed = start.elapsed();
            let ok_count = res.as_ref().map(|v| v.len()).unwrap_or(0);
            println!(
                "SPIKE_B: count={count} elapsed_ms={} ok={} len={ok_count}",
                elapsed.as_millis(),
                res.is_ok()
            );
        }

        // (c) fetch_metadata(Some(missing_name))
        let consumer: BaseConsumer = create_config(&profile).create().unwrap();
        let md = consumer
            .fetch_metadata(Some(missing_name), Duration::from_secs(10))
            .unwrap();
        for t in md.topics() {
            println!(
                "SPIKE_C: topic={} error={:?} partitions={}",
                t.name(),
                t.error(),
                t.partitions().len()
            );
        }
    }

    #[test]
    fn classify_topic_error_maps_auth_not_found_and_other() {
        let auth =
            classify_topic_error(RDKafkaRespErr::RD_KAFKA_RESP_ERR_TOPIC_AUTHORIZATION_FAILED);
        assert_eq!(auth.kind, TopicMetadataErrorKind::NotAuthorized);

        let not_found =
            classify_topic_error(RDKafkaRespErr::RD_KAFKA_RESP_ERR_UNKNOWN_TOPIC_OR_PART);
        assert_eq!(not_found.kind, TopicMetadataErrorKind::NotFound);

        let other = classify_topic_error(RDKafkaRespErr::RD_KAFKA_RESP_ERR_LEADER_NOT_AVAILABLE);
        assert_eq!(other.kind, TopicMetadataErrorKind::Other);
        assert_eq!(
            other.message,
            RDKafkaErrorCode::LeaderNotAvailable.to_string()
        );
    }

    #[test]
    fn classify_chunk_handles_errors_empty_missing_sensitive_and_order() {
        let req = ["b-topic", "a-topic"];

        // Request-level authorization errors -> NotReadable for every topic
        for code in [
            RDKafkaErrorCode::TopicAuthorizationFailed,
            RDKafkaErrorCode::ClusterAuthorizationFailed,
        ] {
            let res = classify_chunk_raw(&req, Err(KafkaError::AdminOp(code)));
            assert_eq!(res.len(), 2);
            assert_eq!(res[0].topic, "b-topic");
            assert_eq!(res[1].topic, "a-topic");
            assert!(matches!(res[0].outcome, TopicConfigOutcome::NotReadable(_)));
            assert!(matches!(res[1].outcome, TopicConfigOutcome::NotReadable(_)));
        }

        // OperationTimedOut -> Failed
        let timed_out = classify_chunk_raw(
            &req,
            Err(KafkaError::AdminOp(RDKafkaErrorCode::OperationTimedOut)),
        );
        assert!(matches!(
            timed_out[0].outcome,
            TopicConfigOutcome::Failed(_)
        ));
        assert!(matches!(
            timed_out[1].outcome,
            TopicConfigOutcome::Failed(_)
        ));

        // Empty entries -> NotReadable; missing topic -> Failed; sensitive -> value == None; input order preserved
        let raw = Ok(vec![
            Ok(RawConfigResource {
                topic: "a-topic".to_string(),
                entries: vec![],
            }),
            Ok(RawConfigResource {
                topic: "b-topic".to_string(),
                entries: vec![
                    TopicConfigEntry {
                        name: "cleanup.policy".to_string(),
                        value: Some("delete".to_string()),
                        source: TopicConfigSource::DynamicTopic,
                        is_default: false,
                        is_sensitive: false,
                        is_read_only: false,
                    },
                    TopicConfigEntry {
                        name: "secret.key".to_string(),
                        value: Some("supersecret".to_string()),
                        source: TopicConfigSource::StaticBroker,
                        is_default: false,
                        is_sensitive: true,
                        is_read_only: true,
                    },
                ],
            }),
        ]);
        let res = classify_chunk_raw(&["b-topic", "a-topic", "missing-topic"], raw);
        assert_eq!(res[0].topic, "b-topic");
        match &res[0].outcome {
            TopicConfigOutcome::Available(entries) => {
                assert_eq!(entries.len(), 2);
                assert_eq!(entries[0].value.as_deref(), Some("delete"));
                assert_eq!(entries[1].value, None);
            }
            other => panic!("expected Available, got {other:?}"),
        }
        assert_eq!(res[1].topic, "a-topic");
        assert!(matches!(res[1].outcome, TopicConfigOutcome::NotReadable(_)));
        assert_eq!(res[2].topic, "missing-topic");
        assert!(matches!(res[2].outcome, TopicConfigOutcome::Failed(_)));
    }

    #[test]
    #[ignore = "Requires local docker compose kafka on localhost:9094 with spike-t-0000"]
    fn integration_fetch_topic_metadata_existing_and_missing() {
        let profile = ClusterProfile {
            name: "local".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };

        let existing = fetch_topic_metadata(profile.clone(), "spike-t-000".to_string()).unwrap();
        assert!(existing.partition_count > 0);
        assert_eq!(existing.metadata_error, None);

        let missing_name = "does-not-exist-meta-test-9999";
        let missing = fetch_topic_metadata(profile.clone(), missing_name.to_string()).unwrap();
        assert_eq!(
            missing.metadata_error.as_ref().map(|e| e.kind),
            Some(TopicMetadataErrorKind::NotFound)
        );

        let topics = fetch_topics(profile).unwrap();
        assert!(!topics.iter().any(|t| t.name == missing_name));
    }

    #[test]
    #[ignore = "Requires local docker compose kafka on localhost:9094 with spike-t-0000"]
    fn integration_describe_topic_configs_returns_cleanup_policy() {
        let profile = ClusterProfile {
            name: "local".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };
        let res = describe_topic_configs(profile, vec!["spike-t-000".to_string()]).unwrap();
        assert_eq!(res.len(), 1);
        match &res[0].outcome {
            TopicConfigOutcome::Available(entries) => {
                assert!(entries.iter().any(|e| e.name == "cleanup.policy"));
            }
            other => panic!("expected Available, got {other:?}"),
        }
    }

    #[test]
    #[ignore = "Spike 1.1 (partition-offset-distribution): requires local kafka on localhost:9094 with spike-offset-dist-60p"]
    fn spike_parallel_fetch_watermarks() {
        use std::sync::atomic::{AtomicUsize, Ordering};
        use std::sync::Mutex;
        use std::time::Instant;

        let profile = ClusterProfile {
            name: "spike-offsets".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };
        let mut config = create_config(&profile);
        config.set("enable.auto.commit", "false");
        let consumer: BaseConsumer = config.create().unwrap();

        let topic = "spike-offset-dist-60p";
        let meta = consumer
            .fetch_metadata(Some(topic), Duration::from_secs(10))
            .unwrap();
        let t = meta.topics().iter().find(|t| t.name() == topic).unwrap();
        let partitions: Vec<i32> = t.partitions().iter().map(|p| p.id()).collect();
        assert_eq!(partitions.len(), 60);

        let seq_start = Instant::now();
        let mut seq_results = Vec::with_capacity(partitions.len());
        for &p in &partitions {
            seq_results.push((
                p,
                consumer
                    .fetch_watermarks(topic, p, Duration::from_secs(5))
                    .unwrap(),
            ));
        }
        let seq_ms = seq_start.elapsed().as_millis();

        let par_start = Instant::now();
        let next_idx = AtomicUsize::new(0);
        let par_results: Mutex<Vec<(i32, (i64, i64))>> =
            Mutex::new(Vec::with_capacity(partitions.len()));
        std::thread::scope(|s| {
            for _ in 0..8 {
                s.spawn(|| loop {
                    let idx = next_idx.fetch_add(1, Ordering::Relaxed);
                    if idx >= partitions.len() {
                        break;
                    }
                    let p = partitions[idx];
                    let wm = consumer
                        .fetch_watermarks(topic, p, Duration::from_secs(5))
                        .unwrap();
                    par_results.lock().unwrap().push((p, wm));
                });
            }
        });
        let par_ms = par_start.elapsed().as_millis();
        let mut par_vec = par_results.into_inner().unwrap();
        par_vec.sort_by_key(|(p, _)| *p);
        seq_results.sort_by_key(|(p, _)| *p);
        assert_eq!(seq_results, par_vec);
        println!(
            "SPIKE_WATERMARKS: partitions={} seq_ms={seq_ms} par_ms={par_ms}",
            partitions.len()
        );
    }

    #[test]
    fn classify_watermark_error_distinguishes_auth_from_other_errors() {
        assert!(matches!(
            classify_watermark_error(&KafkaError::MetadataFetch(
                RDKafkaErrorCode::TopicAuthorizationFailed
            )),
            WatermarkRead::NotReadable(_)
        ));
        assert!(matches!(
            classify_watermark_error(&KafkaError::MetadataFetch(
                RDKafkaErrorCode::ClusterAuthorizationFailed
            )),
            WatermarkRead::NotReadable(_)
        ));
        assert!(matches!(
            classify_watermark_error(&KafkaError::MetadataFetch(
                RDKafkaErrorCode::LeaderNotAvailable
            )),
            WatermarkRead::Failed(_)
        ));
    }

    #[test]
    fn read_partitions_with_deadline_marks_unclaimed_timed_out_and_bounds_workers() {
        use std::sync::atomic::AtomicUsize;

        let active = AtomicUsize::new(0);
        let peak = AtomicUsize::new(0);

        // 12 partitions with max_workers=8, each sleeping 40ms with a 50ms deadline:
        // only the first batch of <=8 workers can complete before the deadline expires,
        // leaving the rest TimedOut.
        let partitions: Vec<i32> = (0..12).rev().collect();
        let results = read_partitions_with_deadline(
            &partitions,
            OFFSET_READ_MAX_WORKERS,
            Duration::from_millis(50),
            Duration::from_millis(50),
            |p, _| {
                let cur = active.fetch_add(1, Ordering::SeqCst) + 1;
                peak.fetch_max(cur, Ordering::SeqCst);
                std::thread::sleep(Duration::from_millis(70));
                active.fetch_sub(1, Ordering::SeqCst);
                WatermarkRead::Known {
                    low: 0,
                    high: p as i64,
                }
            },
        );

        assert_eq!(results.len(), 12);
        // Sorted by partition id 0..12
        for (i, r) in results.iter().enumerate() {
            assert_eq!(r.partition, i as i32);
        }
        assert!(peak.load(Ordering::SeqCst) <= OFFSET_READ_MAX_WORKERS);
        assert!(
            results
                .iter()
                .any(|r| matches!(r.read, WatermarkRead::TimedOut)),
            "expected at least one TimedOut partition"
        );

        // Fewer partitions than max_workers -> peak <= P
        let active2 = AtomicUsize::new(0);
        let peak2 = AtomicUsize::new(0);
        let small = read_partitions_with_deadline(
            &[0, 1, 2],
            OFFSET_READ_MAX_WORKERS,
            Duration::from_secs(1),
            Duration::from_secs(1),
            |p, _| {
                let cur = active2.fetch_add(1, Ordering::SeqCst) + 1;
                peak2.fetch_max(cur, Ordering::SeqCst);
                std::thread::sleep(Duration::from_millis(10));
                active2.fetch_sub(1, Ordering::SeqCst);
                WatermarkRead::Known {
                    low: 0,
                    high: p as i64,
                }
            },
        );
        assert_eq!(small.len(), 3);
        assert!(peak2.load(Ordering::SeqCst) <= 3);
    }

    #[test]
    fn map_cluster_overview_sorts_brokers_and_maps_negative_controller_to_none() {
        let overview = map_cluster_overview(
            vec![
                BrokerEndpoint {
                    id: 3,
                    host: "b3".to_string(),
                    port: 9092,
                },
                BrokerEndpoint {
                    id: 1,
                    host: "b1".to_string(),
                    port: 9092,
                },
                BrokerEndpoint {
                    id: 2,
                    host: "b2".to_string(),
                    port: 9092,
                },
            ],
            Some("cluster-xyz".to_string()),
            -1,
        );
        assert_eq!(
            overview.brokers.iter().map(|b| b.id).collect::<Vec<_>>(),
            vec![1, 2, 3]
        );
        assert_eq!(overview.cluster_id.as_deref(), Some("cluster-xyz"));
        assert_eq!(overview.controller_id, None);

        let with_ctrl = map_cluster_overview(vec![], Some(String::new()), 2);
        assert_eq!(with_ctrl.cluster_id, None);
        assert_eq!(with_ctrl.controller_id, Some(2));
    }

    #[test]
    fn map_config_entry_redacts_sensitive_and_maps_all_sources() {
        let sensitive = map_config_entry(RdkafkaConfigEntry {
            name: "ssl.keystore.password".to_string(),
            value: Some("super-secret".to_string()),
            source: ConfigSource::DynamicTopic,
            is_read_only: true,
            is_default: false,
            is_sensitive: true,
        });
        assert_eq!(sensitive.value, None);
        assert!(sensitive.is_sensitive);
        assert_eq!(sensitive.source, CoreTopicConfigSource::DynamicTopic);

        let pairs = [
            (
                ConfigSource::DynamicTopic,
                CoreTopicConfigSource::DynamicTopic,
            ),
            (
                ConfigSource::DynamicBroker,
                CoreTopicConfigSource::DynamicBroker,
            ),
            (
                ConfigSource::DynamicDefaultBroker,
                CoreTopicConfigSource::DynamicDefaultBroker,
            ),
            (
                ConfigSource::StaticBroker,
                CoreTopicConfigSource::StaticBroker,
            ),
            (ConfigSource::Default, CoreTopicConfigSource::Default),
            (ConfigSource::Unknown, CoreTopicConfigSource::Unknown),
        ];
        for (src, expected) in pairs {
            assert_eq!(map_config_source(src), expected);
        }
    }

    #[test]
    fn classify_config_error_maps_auth_missing_and_other() {
        assert_eq!(
            classify_config_error(RDKafkaErrorCode::TopicAuthorizationFailed),
            TopicConfigUnavailable::NotAuthorized
        );
        assert_eq!(
            classify_config_error(RDKafkaErrorCode::ClusterAuthorizationFailed),
            TopicConfigUnavailable::NotAuthorized
        );
        assert_eq!(
            classify_config_error(RDKafkaErrorCode::UnknownTopicOrPartition),
            TopicConfigUnavailable::TopicNotFound
        );
        assert_eq!(
            classify_config_error(RDKafkaErrorCode::UnknownTopic),
            TopicConfigUnavailable::TopicNotFound
        );
        assert_eq!(
            classify_config_error(RDKafkaErrorCode::RequestTimedOut),
            TopicConfigUnavailable::Failed(RDKafkaErrorCode::RequestTimedOut.to_string())
        );
    }

    #[test]
    fn assemble_detailed_config_chunk_preserves_order_sorts_entries_and_fans_out_request_errors() {
        let fanout =
            assemble_detailed_config_chunk(&["b", "a"], Err("transport timeout".to_string()));
        assert_eq!(fanout.len(), 2);
        assert_eq!(fanout[0].topic, "b");
        assert_eq!(
            fanout[0].result,
            Err(TopicConfigUnavailable::Failed(
                "transport timeout".to_string()
            ))
        );
        assert_eq!(fanout[1].topic, "a");

        let ok = assemble_detailed_config_chunk(
            &["topic-b", "missing-topic", "topic-a"],
            Ok(vec![
                Ok((
                    "topic-a".to_string(),
                    vec![
                        CoreTopicConfigEntry {
                            name: "z.key".to_string(),
                            value: Some("2".to_string()),
                            source: CoreTopicConfigSource::Default,
                            is_default: true,
                            is_sensitive: false,
                        },
                        CoreTopicConfigEntry {
                            name: "a.key".to_string(),
                            value: Some("1".to_string()),
                            source: CoreTopicConfigSource::DynamicTopic,
                            is_default: false,
                            is_sensitive: false,
                        },
                    ],
                )),
                Ok(("topic-b".to_string(), vec![])),
            ]),
        );
        assert_eq!(ok.len(), 3);
        assert_eq!(ok[0].topic, "topic-b");
        assert_eq!(ok[0].result, Err(TopicConfigUnavailable::TopicNotFound));
        assert_eq!(ok[1].topic, "missing-topic");
        assert_eq!(
            ok[1].result,
            Err(TopicConfigUnavailable::Failed(
                "no result for topic".to_string()
            ))
        );
        assert_eq!(ok[2].topic, "topic-a");
        let entries = ok[2].result.as_ref().unwrap();
        assert_eq!(
            entries.iter().map(|e| e.name.as_str()).collect::<Vec<_>>(),
            vec!["a.key", "z.key"]
        );
    }

    #[test]
    #[ignore = "Requires local docker compose kafka on localhost:9094 with spike-t-000"]
    fn integration_describe_topic_configs_detailed_existing_and_missing() {
        let profile = ClusterProfile {
            name: "local".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };
        let res = describe_topic_configs_detailed(
            &profile,
            &[
                "spike-t-000".to_string(),
                "non-existent-510-xyz".to_string(),
            ],
        );
        assert_eq!(res.len(), 2);
        let entries = res[0]
            .result
            .as_ref()
            .expect("existing topic should succeed");
        assert!(entries.iter().any(|e| e.name == "cleanup.policy"));
        assert_eq!(res[1].result, Err(TopicConfigUnavailable::TopicNotFound));
    }
}
