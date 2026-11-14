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
use kafkalyzer_core::partition_health::{summarize_topic_health, PartitionMetadata};
use kafkalyzer_core::tls::{classify_tls_failure, TlsFailureClassification};
use rdkafka::admin::{AdminClient, AdminOptions, OwnedResourceSpecifier, ResourceSpecifier};
use rdkafka::client::{ClientContext, DefaultClientContext};
use rdkafka::config::RDKafkaLogLevel;
use rdkafka::consumer::{BaseConsumer, Consumer, ConsumerContext};
use rdkafka::error::KafkaError;
use std::collections::{HashMap, HashSet, VecDeque};
use std::ffi::{CStr, CString};
use std::ptr;
use std::sync::Mutex;
use std::time::Duration;
use tokio::runtime::Runtime;

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
}

#[derive(Debug, Clone)]
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

pub fn fetch_topics(profile: ClusterProfile) -> Result<Vec<TopicMetadata>> {
    let config = create_config(&profile);

    // Create Consumer for Metadata
    let consumer: BaseConsumer = config.create()?;
    let metadata = consumer.fetch_metadata(None, std::time::Duration::from_secs(10))?;

    // Create Admin Client for Configs
    // AdminClient requires async, so we need a runtime
    let rt = Runtime::new()?;
    let admin_client: AdminClient<DefaultClientContext> = config.create()?;

    let mut topics = Vec::new();
    let mut resource_specs = Vec::new();
    let mut topic_names = Vec::new();

    // 1. Collect basic metadata
    for topic_meta in metadata.topics() {
        if topic_meta.error().is_none() {
            topic_names.push(topic_meta.name().to_string());
            resource_specs.push(ResourceSpecifier::Topic(topic_meta.name()));
        }
    }

    // 2. Fetch Configs in bulk
    let admin_options =
        AdminOptions::new().operation_timeout(Some(std::time::Duration::from_secs(10)));

    // We might have too many topics to fetch in one go, but let's try.
    // If it fails, we might need to chunk. For now, assuming reasonable count.
    let configs_result =
        rt.block_on(admin_client.describe_configs(&resource_specs, &admin_options));

    // Map configs by topic name for easy lookup
    let mut config_map: std::collections::HashMap<String, (Option<String>, Option<String>)> =
        std::collections::HashMap::new();

    if let Ok(configs) = configs_result {
        for config_resource in configs {
            if let Ok(resource) = config_resource {
                // Determine topic name from the resource (specifier)
                let topic_name = match &resource.specifier {
                    OwnedResourceSpecifier::Topic(name) => name.clone(),
                    _ => continue, // Should not happen as we requested topics
                };

                let mut retention = None;
                let mut cleanup = None;

                for entry in resource.entries {
                    if entry.name == "retention.ms" {
                        retention = Some(entry.value.unwrap_or_default().to_string());
                    } else if entry.name == "cleanup.policy" {
                        cleanup = Some(entry.value.unwrap_or_default().to_string());
                    }
                }
                config_map.insert(topic_name, (cleanup, retention));
            }
        }
    }

    // 3. Build final TopicMetadata
    for topic_meta in metadata.topics() {
        if topic_meta.error().is_none() {
            let partitions = topic_meta.partitions();
            let partition_count = partitions.len() as i32;
            let replication_factor = if !partitions.is_empty() {
                partitions[0].replicas().len() as i32
            } else {
                0
            };

            let (cleanup, retention) = config_map
                .get(topic_meta.name())
                .cloned()
                .unwrap_or((None, None));

            let health = summarize_topic_health(
                &topic_meta
                    .partitions()
                    .iter()
                    .map(partition_metadata)
                    .collect::<Vec<_>>(),
            );

            topics.push(TopicMetadata {
                name: topic_meta.name().to_string(),
                partition_count,
                replication_factor,
                cleanup_policy: cleanup,
                retention_ms: retention,
                under_replicated_partitions: health.map(|h| h.under_replicated_partitions),
                leaderless_partitions: health.map(|h| h.leaderless_partitions),
            });
        }
    }

    topics.sort_by(|a, b| a.name.cmp(&b.name));
    Ok(topics)
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
}
