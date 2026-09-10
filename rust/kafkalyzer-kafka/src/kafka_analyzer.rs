use anyhow::Result;
use chrono::{DateTime, Timelike};
use kafkalyzer_core::kafka_types::{
    ClusterProfile, FieldOccurrence, FieldValueOccurrence, HourlyCount, KeyOccurrence,
    PartitionAnalysis, TopicAnalysisProgress, TopicAnalysisReport, TypeOccurrence,
};
use rdkafka::admin::{AdminClient, AdminOptions, ResourceSpecifier};
use rdkafka::client::DefaultClientContext;
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::topic_partition_list::{Offset, TopicPartitionList};
use rdkafka::Message as KafkaMessageTrait;
use serde_json::Value;
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crate::kafka_consumer::{
    create_sr_settings, decode_message_component, decode_message_to_value, setup_schema_registry,
    StreamSink,
};
use crate::kafka_utils::create_config;

#[derive(Clone)]
pub struct AnalyzerAccumulator {
    pub topic: String,
    pub is_compacted: bool,
    pub total_messages: i64,
    pub total_bytes: i64,
    pub min_message_size: i64,
    pub max_message_size: i64,
    pub tombstones_count: i64,
    pub null_keys_count: i64,
    pub partition_stats: HashMap<i32, PartitionStatsAccumulator>,
    pub hourly_counts: [i64; 24],
    pub unknown_timestamp_count: i64,
    pub key_counts: HashMap<String, i64>,
    pub content_type_counts: HashMap<String, i64>,
    pub field_counts: HashMap<String, i64>,
    pub field_value_counts: HashMap<String, HashMap<String, i64>>,
}

#[derive(Clone)]
pub struct PartitionStatsAccumulator {
    pub message_count: i64,
    pub byte_size: i64,
    pub earliest_offset: i64,
    pub latest_offset: i64,
}

impl AnalyzerAccumulator {
    pub fn new(topic: String, is_compacted: bool) -> Self {
        Self {
            topic,
            is_compacted,
            total_messages: 0,
            total_bytes: 0,
            min_message_size: i64::MAX,
            max_message_size: 0,
            tombstones_count: 0,
            null_keys_count: 0,
            partition_stats: HashMap::new(),
            hourly_counts: [0; 24],
            unknown_timestamp_count: 0,
            key_counts: HashMap::new(),
            content_type_counts: HashMap::new(),
            field_counts: HashMap::new(),
            field_value_counts: HashMap::new(),
        }
    }

    pub fn merge(&mut self, other: &AnalyzerAccumulator) {
        self.total_messages += other.total_messages;
        self.total_bytes += other.total_bytes;
        if other.total_messages > 0 {
            self.min_message_size = self.min_message_size.min(other.min_message_size);
            self.max_message_size = self.max_message_size.max(other.max_message_size);
        }
        self.tombstones_count += other.tombstones_count;
        self.null_keys_count += other.null_keys_count;
        self.unknown_timestamp_count += other.unknown_timestamp_count;

        for i in 0..24 {
            self.hourly_counts[i] += other.hourly_counts[i];
        }

        for (p, p_stat) in &other.partition_stats {
            let entry = self
                .partition_stats
                .entry(*p)
                .or_insert(PartitionStatsAccumulator {
                    message_count: 0,
                    byte_size: 0,
                    earliest_offset: p_stat.earliest_offset,
                    latest_offset: p_stat.latest_offset,
                });
            if p_stat.message_count > 0 {
                if entry.message_count == 0 {
                    entry.earliest_offset = p_stat.earliest_offset;
                    entry.latest_offset = p_stat.latest_offset;
                } else {
                    entry.earliest_offset = entry.earliest_offset.min(p_stat.earliest_offset);
                    entry.latest_offset = entry.latest_offset.max(p_stat.latest_offset);
                }
            }
            entry.message_count += p_stat.message_count;
            entry.byte_size += p_stat.byte_size;
        }

        for (k, count) in &other.key_counts {
            if self.key_counts.len() < 10000 || self.key_counts.contains_key(k) {
                *self.key_counts.entry(k.clone()).or_insert(0) += count;
            }
        }

        for (ct, count) in &other.content_type_counts {
            *self.content_type_counts.entry(ct.clone()).or_insert(0) += count;
        }

        for (f, count) in &other.field_counts {
            if self.field_counts.len() < 500 || self.field_counts.contains_key(f) {
                *self.field_counts.entry(f.clone()).or_insert(0) += count;
            }
        }

        for (f, val_map) in &other.field_value_counts {
            let self_val_map = self.field_value_counts.entry(f.clone()).or_default();
            for (v, count) in val_map {
                if self_val_map.len() < 200 || self_val_map.contains_key(v) {
                    *self_val_map.entry(v.clone()).or_insert(0) += count;
                }
            }
        }
    }

    pub fn record_message(
        &mut self,
        partition: i32,
        offset: i64,
        timestamp_ms: i64,
        key_bytes: Option<&[u8]>,
        payload_bytes: Option<&[u8]>,
        decoded_key: Option<&str>,
        parsed_payload: Option<&Value>,
        is_sr_encoded: bool,
    ) {
        self.total_messages += 1;

        let key_len = key_bytes.map(|k| k.len() as i64).unwrap_or(0);
        let payload_len = payload_bytes.map(|p| p.len() as i64).unwrap_or(0);
        let msg_size = key_len + payload_len;

        self.total_bytes += msg_size;
        if msg_size < self.min_message_size {
            self.min_message_size = msg_size;
        }
        if msg_size > self.max_message_size {
            self.max_message_size = msg_size;
        }

        // Partition Stats
        let p_stat = self
            .partition_stats
            .entry(partition)
            .or_insert(PartitionStatsAccumulator {
                message_count: 0,
                byte_size: 0,
                earliest_offset: offset,
                latest_offset: offset,
            });
        p_stat.message_count += 1;
        p_stat.byte_size += msg_size;
        if offset < p_stat.earliest_offset {
            p_stat.earliest_offset = offset;
        }
        if offset > p_stat.latest_offset {
            p_stat.latest_offset = offset;
        }

        // Timestamp / Hourly Bucketing
        if timestamp_ms > 0 {
            if let Some(dt) = DateTime::from_timestamp_millis(timestamp_ms) {
                let hour = dt.hour() as usize;
                if hour < 24 {
                    self.hourly_counts[hour] += 1;
                } else {
                    self.unknown_timestamp_count += 1;
                }
            } else {
                self.unknown_timestamp_count += 1;
            }
        } else {
            self.unknown_timestamp_count += 1;
        }

        // Key Analysis
        let key_str = if let Some(dk) = decoded_key {
            if dk.is_empty() {
                None
            } else {
                Some(dk.to_string())
            }
        } else {
            match key_bytes {
                None => None,
                Some(bytes) => {
                    if bytes.is_empty() {
                        None
                    } else {
                        Some(match std::str::from_utf8(bytes) {
                            Ok(s) => s.to_string(),
                            Err(_) => format!("[Binary 0x{}]", hex_preview(bytes)),
                        })
                    }
                }
            }
        };

        match key_str {
            None => {
                self.null_keys_count += 1;
            }
            Some(k) => {
                // Bounded tracking up to 10,000 unique keys
                if self.key_counts.len() < 10000 || self.key_counts.contains_key(&k) {
                    *self.key_counts.entry(k).or_insert(0) += 1;
                }
            }
        }

        // Tombstone check
        let is_tombstone = payload_bytes.is_none_or(|p| p.is_empty());
        if is_tombstone {
            self.tombstones_count += 1;
            *self
                .content_type_counts
                .entry("Tombstone".to_string())
                .or_insert(0) += 1;
            return;
        }

        // Try parsed payload or parse JSON from raw payload
        let fallback_json;
        let json_ref = if let Some(val) = parsed_payload {
            Some(val)
        } else if let Some(payload) = payload_bytes {
            if let Ok(json_val) = serde_json::from_slice::<Value>(payload) {
                fallback_json = json_val;
                Some(&fallback_json)
            } else {
                None
            }
        } else {
            None
        };

        if let Some(json_val) = json_ref {
            let type_label = if is_sr_encoded {
                "Avro / Schema Registry"
            } else {
                "JSON"
            };
            *self
                .content_type_counts
                .entry(type_label.to_string())
                .or_insert(0) += 1;

            if let Value::Object(map) = json_val {
                for (field_name, field_val) in map {
                    // Record field occurrence
                    if self.field_counts.len() < 500
                        || self.field_counts.contains_key(field_name.as_str())
                    {
                        *self.field_counts.entry(field_name.clone()).or_insert(0) += 1;
                    }

                    // For all scalar fields (string, number, boolean, null), track top values
                    let val_str = match field_val {
                        Value::String(s) => {
                            if s.len() <= 80 {
                                Some(s.clone())
                            } else {
                                Some(format!("{}...", &s[..77]))
                            }
                        }
                        Value::Number(n) => Some(n.to_string()),
                        Value::Bool(b) => Some(b.to_string()),
                        Value::Null => Some("null".to_string()),
                        _ => None,
                    };

                    if let Some(v_str) = val_str {
                        let val_map = self
                            .field_value_counts
                            .entry(field_name.clone())
                            .or_default();
                        if val_map.len() < 200 || val_map.contains_key(&v_str) {
                            *val_map.entry(v_str).or_insert(0) += 1;
                        }
                    }
                }
            }
        } else if is_sr_encoded {
            *self
                .content_type_counts
                .entry("Schema Registry (Avro/Proto)".to_string())
                .or_insert(0) += 1;
        } else if let Some(payload) = payload_bytes {
            if std::str::from_utf8(payload).is_ok() {
                *self
                    .content_type_counts
                    .entry("Text".to_string())
                    .or_insert(0) += 1;
            } else {
                *self
                    .content_type_counts
                    .entry("Binary".to_string())
                    .or_insert(0) += 1;
            }
        }
    }

    pub fn to_report(&self, scan_duration_ms: i64) -> TopicAnalysisReport {
        let total_msgs = self.total_messages;
        let avg_size = if total_msgs > 0 {
            self.total_bytes as f64 / total_msgs as f64
        } else {
            0.0
        };

        let min_size = if total_msgs > 0 {
            self.min_message_size
        } else {
            0
        };

        // Partition stats sorted by partition ID
        let mut partition_stats = Vec::new();
        let mut part_keys: Vec<i32> = self.partition_stats.keys().copied().collect();
        part_keys.sort();

        for p in part_keys {
            if let Some(stat) = self.partition_stats.get(&p) {
                let pct = if total_msgs > 0 {
                    (stat.message_count as f64 / total_msgs as f64) * 100.0
                } else {
                    0.0
                };
                partition_stats.push(PartitionAnalysis {
                    partition: p,
                    message_count: stat.message_count,
                    byte_size: stat.byte_size,
                    percentage: pct,
                    earliest_offset: stat.earliest_offset,
                    latest_offset: stat.latest_offset,
                });
            }
        }

        // Hourly distribution (0..23)
        let mut hourly_distribution = Vec::with_capacity(24);
        for hour in 0..24 {
            let count = self.hourly_counts[hour];
            let pct = if total_msgs > 0 {
                (count as f64 / total_msgs as f64) * 100.0
            } else {
                0.0
            };
            hourly_distribution.push(HourlyCount {
                hour: hour as i32,
                count,
                percentage: pct,
            });
        }

        // Top 20 Keys
        let mut top_keys_vec: Vec<(String, i64)> = self
            .key_counts
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        top_keys_vec.sort_by(|a, b| b.1.cmp(&a.1));
        top_keys_vec.truncate(20);

        let top_keys = top_keys_vec
            .into_iter()
            .map(|(key, count)| {
                let pct = if total_msgs > 0 {
                    (count as f64 / total_msgs as f64) * 100.0
                } else {
                    0.0
                };
                KeyOccurrence {
                    key,
                    count,
                    percentage: pct,
                }
            })
            .collect();

        // Content types
        let mut types_vec: Vec<(String, i64)> = self
            .content_type_counts
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        types_vec.sort_by(|a, b| b.1.cmp(&a.1));

        let content_type_distribution = types_vec
            .into_iter()
            .map(|(type_name, count)| {
                let pct = if total_msgs > 0 {
                    (count as f64 / total_msgs as f64) * 100.0
                } else {
                    0.0
                };
                TypeOccurrence {
                    type_name,
                    count,
                    percentage: pct,
                }
            })
            .collect();

        // Field Frequencies & Top 10 Values (Top 50 fields)
        let mut fields_vec: Vec<(String, i64)> = self
            .field_counts
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        fields_vec.sort_by(|a, b| b.1.cmp(&a.1));
        fields_vec.truncate(50);

        let field_frequencies = fields_vec
            .into_iter()
            .map(|(field_name, count)| {
                let pct = if total_msgs > 0 {
                    (count as f64 / total_msgs as f64) * 100.0
                } else {
                    0.0
                };

                let mut top_vals = Vec::new();
                if let Some(val_map) = self.field_value_counts.get(&field_name) {
                    let mut val_vec: Vec<(String, i64)> =
                        val_map.iter().map(|(k, v)| (k.clone(), *v)).collect();
                    val_vec.sort_by(|a, b| b.1.cmp(&a.1));
                    val_vec.truncate(10);

                    top_vals = val_vec
                        .into_iter()
                        .map(|(val, v_count)| {
                            let v_pct = if count > 0 {
                                (v_count as f64 / count as f64) * 100.0
                            } else {
                                0.0
                            };
                            FieldValueOccurrence {
                                value: val,
                                count: v_count,
                                percentage: v_pct,
                            }
                        })
                        .collect();
                }

                FieldOccurrence {
                    field_name,
                    count,
                    percentage: pct,
                    top_values: top_vals,
                }
            })
            .collect();

        TopicAnalysisReport {
            topic: self.topic.clone(),
            total_messages: total_msgs,
            total_bytes: self.total_bytes,
            min_message_size: min_size,
            max_message_size: self.max_message_size,
            avg_message_size: avg_size,
            tombstones_count: self.tombstones_count,
            is_compacted: self.is_compacted,
            null_keys_count: self.null_keys_count,
            partition_stats,
            hourly_distribution,
            top_keys,
            content_type_distribution,
            field_frequencies,
            scan_duration_ms,
        }
    }
}

/// Pure range check: is there anything left to read between the consumer's
/// next offset and the scan end target, given fresh watermarks?
fn remaining_range_nonempty(low: i64, high: i64, next_offset: i64, end_off: i64) -> bool {
    next_offset.max(low) < end_off.min(high)
}

/// Called when a worker has been idle for a while: re-query the broker's
/// watermarks to decide whether the partition still has data pending (broker
/// throttling / slow fetch) or whether the remaining range disappeared
/// (retention / compaction), in which case the partition can be finalized.
/// Transient errors keep the worker polling — PartitionEOF or the cancel flag
/// will terminate it.
fn partition_may_have_more_data(
    consumer: &BaseConsumer,
    topic: &str,
    partition: i32,
    next_offset: i64,
    end_off: i64,
) -> bool {
    match consumer.fetch_watermarks(topic, partition, Duration::from_secs(5)) {
        Ok((low, high)) => remaining_range_nonempty(low, high, next_offset, end_off),
        Err(_) => true,
    }
}

fn hex_preview(bytes: &[u8]) -> String {
    let len = bytes.len().min(8);
    bytes[..len]
        .iter()
        .map(|b| format!("{:02x}", b))
        .collect::<Vec<String>>()
        .join("")
}

pub fn analyze_topic_content(
    profile: ClusterProfile,
    topic: String,
    max_messages: Option<i64>,
    sample_from_latest: bool,
    sink: StreamSink<TopicAnalysisProgress>,
    cancel_flag: Arc<AtomicBool>,
) -> Result<()> {
    // 1. Setup Runtime & Schema Registry
    let tokio_runtime = crate::kafka_consumer::shared_runtime();
    let sr_settings = create_sr_settings(&profile);
    let (decoders, key_is_avro, value_is_avro) = if let Some(ref settings) = sr_settings {
        setup_schema_registry(tokio_runtime, settings, &topic).unwrap_or((None, false, false))
    } else {
        (None, false, false)
    };

    // 2. Setup Consumer with unique group.id and earliest reset
    let mut config = create_config(&profile);
    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis())
        .unwrap_or(0);
    let group_id = format!("kafkalyzer_analyzer_{}", timestamp);
    config.set("group.id", &group_id);
    config.set("enable.auto.commit", "false");
    config.set("enable.auto.offset.store", "false");
    config.set("auto.offset.reset", "earliest");
    // High-throughput configuration for bulk topic analysis
    config.set("fetch.wait.max.ms", "50");
    config.set("fetch.message.max.bytes", "10485760"); // 10MB
    config.set("queued.min.messages", "100000");
    // Cap prefetch memory per partition (librdkafka default is 64MB/partition)
    config.set("queued.max.messages.kbytes", "16384"); // 16MB

    // Deterministic per-partition end-of-log signal: workers terminate on
    // PartitionEOF instead of guessing completion from idle timeouts or offset
    // arithmetic (both unreliable on compacted / transactional topics).
    config.set("enable.partition.eof", "true");

    let consumer: BaseConsumer = config.create()?;

    // 3. Fetch topic metadata & cleanup policy
    let timeout = Duration::from_secs(10);
    let metadata = consumer.fetch_metadata(Some(&topic), timeout)?;

    let mut is_compacted = false;
    let admin_config = create_config(&profile);
    if let Ok(admin_client) = admin_config.create::<AdminClient<DefaultClientContext>>() {
        let resource = ResourceSpecifier::Topic(&topic);
        let admin_options = AdminOptions::new().operation_timeout(Some(Duration::from_secs(3)));
        if let Ok(configs) =
            tokio_runtime.block_on(admin_client.describe_configs(&[resource], &admin_options))
        {
            for config_res in configs.into_iter().flatten() {
                for entry in config_res.entries {
                    if entry.name == "cleanup.policy" {
                        if let Some(val) = entry.value {
                            if val.contains("compact") {
                                is_compacted = true;
                            }
                        }
                    }
                }
            }
        }
    }

    let mut accumulator = AnalyzerAccumulator::new(topic.clone(), is_compacted);

    // 4. Setup topic partition list and resolve watermark bounds
    let mut tpl = TopicPartitionList::new();
    let topic_meta = metadata
        .topics()
        .iter()
        .find(|t| t.name() == topic)
        .ok_or_else(|| anyhow::anyhow!("Topic '{}' not found in cluster metadata", topic))?;

    let mut end_offsets: HashMap<i32, i64> = HashMap::new();
    let mut start_offsets: HashMap<i32, i64> = HashMap::new();
    let mut completed_partitions = std::collections::HashSet::new();
    let mut total_messages_to_scan: i64 = 0;

    let part_count = topic_meta.partitions().len() as i64;
    for partition in topic_meta.partitions() {
        let p_id = partition.id();
        let (low, high) = consumer
            .fetch_watermarks(&topic, p_id, Duration::from_secs(5))
            .unwrap_or((0, 0));

        let available = (high - low).max(0);
        let mut start_off = low;
        let end_off = high;

        if let Some(max_msgs) = max_messages {
            let target_per_partition = (max_msgs / part_count.max(1)).max(1);
            if sample_from_latest && available > target_per_partition {
                start_off = (high - target_per_partition).max(low);
            }
        }

        let to_scan_p = (end_off - start_off).max(0);
        total_messages_to_scan += to_scan_p;

        start_offsets.insert(p_id, start_off);
        end_offsets.insert(p_id, end_off);

        // Pre-populate partition stats so all partitions are visible in the report from the beginning
        accumulator.partition_stats.insert(
            p_id,
            PartitionStatsAccumulator {
                message_count: 0,
                byte_size: 0,
                earliest_offset: start_off,
                latest_offset: start_off,
            },
        );

        if start_off >= end_off {
            completed_partitions.insert(p_id);
        }

        tpl.add_partition_offset(&topic, p_id, Offset::Offset(start_off))?;
    }

    if total_messages_to_scan == 0 || completed_partitions.len() >= topic_meta.partitions().len() {
        let report = accumulator.to_report(0);
        let progress = TopicAnalysisProgress {
            scanned_messages: 0,
            total_messages_to_scan: 0,
            progress: 1.0,
            messages_per_second: 0.0,
            current_partition: -1,
            is_complete: true,
            error_message: None,
            partial_report: Some(report),
        };
        sink.add(progress).ok();
        return Ok(());
    }

    // Assign partitions
    let consumer = Arc::new(consumer);
    consumer.assign(&tpl)?;

    // Split partition queues so partitions can be read concurrently in parallel
    let mut active_partition_queues = Vec::new();
    for partition in topic_meta.partitions() {
        let p_id = partition.id();
        let start_off = start_offsets.get(&p_id).copied().unwrap_or(0);
        let end_off = end_offsets.get(&p_id).copied().unwrap_or(0);
        if start_off < end_off {
            if let Some(queue) = consumer.split_partition_queue(&topic, p_id) {
                active_partition_queues.push((p_id, queue, start_off, end_off));
            }
        }
    }

    let active_count = active_partition_queues.len();
    if active_count == 0 {
        let report = accumulator.to_report(0);
        let progress = TopicAnalysisProgress {
            scanned_messages: 0,
            total_messages_to_scan: 0,
            progress: 1.0,
            messages_per_second: 0.0,
            current_partition: -1,
            is_complete: true,
            error_message: None,
            partial_report: Some(report),
        };
        sink.add(progress).ok();
        return Ok(());
    }

    let num_workers = active_count.min(64);
    let mut worker_tasks: Vec<
        Vec<(
            i32,
            rdkafka::consumer::base_consumer::PartitionQueue<
                rdkafka::consumer::DefaultConsumerContext,
            >,
            i64,
            i64,
        )>,
    > = (0..num_workers).map(|_| Vec::new()).collect();
    for (i, item) in active_partition_queues.into_iter().enumerate() {
        worker_tasks[i % num_workers].push(item);
    }

    let worker_accumulators: Vec<Arc<std::sync::Mutex<AnalyzerAccumulator>>> = (0..num_workers)
        .map(|_| {
            Arc::new(std::sync::Mutex::new(AnalyzerAccumulator::new(
                topic.clone(),
                is_compacted,
            )))
        })
        .collect();

    let active_workers = Arc::new(std::sync::atomic::AtomicUsize::new(num_workers));
    let scan_start = Instant::now();
    let mut main_acc = AnalyzerAccumulator::new(topic.clone(), is_compacted);

    std::thread::scope(|s| {
        for (w_idx, tasks) in worker_tasks.into_iter().enumerate() {
            let w_acc_arc = worker_accumulators[w_idx].clone();
            let active_workers = active_workers.clone();
            let cancel_flag = &cancel_flag;
            let tokio_runtime = &tokio_runtime;
            let decoders = &decoders;
            let topic = &topic;
            let worker_consumer = consumer.clone();

            s.spawn(move || {
                let mut local_acc = AnalyzerAccumulator::new(topic.clone(), is_compacted);
                let mut last_sync = Instant::now();
                let mut last_sync_msgs: i64 = 0;

                if tasks.len() == 1 {
                    let (p_id, queue, start_off, end_off) = &tasks[0];
                    let mut last_off = *start_off - 1;
                    let mut last_msg_time = Instant::now();

                    while !cancel_flag.load(Ordering::Relaxed) {
                        if last_off + 1 >= *end_off {
                            break;
                        }
                        match queue.poll(Duration::from_millis(50)) {
                            Some(Ok(msg)) => {
                                let off = msg.offset();
                                if off < *start_off {
                                    continue;
                                }
                                if off >= *end_off {
                                    break;
                                }
                                last_msg_time = Instant::now();
                                last_off = off;

                                let ts_ms = msg.timestamp().to_millis().unwrap_or(0);
                                let key = msg.key();
                                let payload = msg.payload();

                                let is_sr_encoded =
                                    payload.is_some_and(|b| b.len() >= 5 && b[0] == 0);

                                let parsed_payload = if value_is_avro || is_sr_encoded {
                                    decode_message_to_value(
                                        tokio_runtime,
                                        decoders,
                                        payload,
                                        value_is_avro || is_sr_encoded,
                                    )
                                } else {
                                    None
                                };

                                let decoded_key = if key_is_avro {
                                    decode_message_component(
                                        tokio_runtime,
                                        decoders,
                                        key,
                                        key_is_avro,
                                        "",
                                    )
                                } else {
                                    None
                                };

                                local_acc.record_message(
                                    *p_id,
                                    off,
                                    ts_ms,
                                    key,
                                    payload,
                                    decoded_key.as_deref(),
                                    parsed_payload.as_ref(),
                                    is_sr_encoded,
                                );

                                if off + 1 >= *end_off {
                                    break;
                                }

                                if last_sync.elapsed() >= Duration::from_millis(100)
                                    || (local_acc.total_messages - last_sync_msgs >= 2000)
                                {
                                    if let Ok(mut shared) = w_acc_arc.lock() {
                                        *shared = local_acc.clone();
                                    }
                                    last_sync = Instant::now();
                                    last_sync_msgs = local_acc.total_messages;
                                }
                            }
                            Some(Err(rdkafka::error::KafkaError::PartitionEOF(_))) => {
                                // Authoritative end-of-log signal — partition done.
                                break;
                            }
                            Some(Err(_)) => {}
                            None => {
                                // Idle is NOT treated as completion: under fetch
                                // skew or broker throttling a partition can starve
                                // for seconds while data is still pending. Only
                                // finalize if the remaining range is really gone.
                                if last_msg_time.elapsed() >= Duration::from_secs(5) {
                                    if partition_may_have_more_data(
                                        &worker_consumer,
                                        topic,
                                        *p_id,
                                        last_off + 1,
                                        *end_off,
                                    ) {
                                        last_msg_time = Instant::now();
                                    } else {
                                        break;
                                    }
                                }
                            }
                        }
                    }
                } else {
                    let mut remaining_tasks: Vec<_> = tasks
                        .into_iter()
                        .map(|(p, q, s, e)| (p, q, s, s - 1, e, Instant::now()))
                        .collect();

                    while !remaining_tasks.is_empty() && !cancel_flag.load(Ordering::Relaxed) {
                        let mut any_polled = false;
                        remaining_tasks.retain_mut(
                            |(p_id, queue, start_off, last_off, end_off, last_msg_time)| {
                                if *last_off + 1 >= *end_off {
                                    return false;
                                }
                                match queue.poll(Duration::from_millis(10)) {
                                    Some(Ok(msg)) => {
                                        any_polled = true;
                                        let off = msg.offset();
                                        if off < *start_off {
                                            return true;
                                        }
                                        if off >= *end_off {
                                            return false;
                                        }
                                        *last_msg_time = Instant::now();
                                        *last_off = off;

                                        let ts_ms = msg.timestamp().to_millis().unwrap_or(0);
                                        let key = msg.key();
                                        let payload = msg.payload();

                                        let is_sr_encoded =
                                            payload.is_some_and(|b| b.len() >= 5 && b[0] == 0);

                                        let parsed_payload = if value_is_avro || is_sr_encoded {
                                            decode_message_to_value(
                                                tokio_runtime,
                                                decoders,
                                                payload,
                                                value_is_avro || is_sr_encoded,
                                            )
                                        } else {
                                            None
                                        };

                                        let decoded_key = if key_is_avro {
                                            decode_message_component(
                                                tokio_runtime,
                                                decoders,
                                                key,
                                                key_is_avro,
                                                "",
                                            )
                                        } else {
                                            None
                                        };

                                        local_acc.record_message(
                                            *p_id,
                                            off,
                                            ts_ms,
                                            key,
                                            payload,
                                            decoded_key.as_deref(),
                                            parsed_payload.as_ref(),
                                            is_sr_encoded,
                                        );

                                        if off + 1 >= *end_off {
                                            return false;
                                        }
                                        true
                                    }
                                    Some(Err(rdkafka::error::KafkaError::PartitionEOF(_))) => false,
                                    Some(Err(_)) => true,
                                    None => {
                                        // Idle is NOT completion — recheck the
                                        // watermarks before finalizing a partition.
                                        if last_msg_time.elapsed() >= Duration::from_secs(5) {
                                            if partition_may_have_more_data(
                                                &worker_consumer,
                                                topic,
                                                *p_id,
                                                *last_off + 1,
                                                *end_off,
                                            ) {
                                                *last_msg_time = Instant::now();
                                                true
                                            } else {
                                                false
                                            }
                                        } else {
                                            true
                                        }
                                    }
                                }
                            },
                        );

                        if last_sync.elapsed() >= Duration::from_millis(100)
                            || (local_acc.total_messages - last_sync_msgs >= 2000)
                        {
                            if let Ok(mut shared) = w_acc_arc.lock() {
                                *shared = local_acc.clone();
                            }
                            last_sync = Instant::now();
                            last_sync_msgs = local_acc.total_messages;
                        }

                        if !any_polled {
                            std::thread::yield_now();
                        }
                    }
                }

                if let Ok(mut shared) = w_acc_arc.lock() {
                    *shared = local_acc;
                }
                active_workers.fetch_sub(1, Ordering::SeqCst);
            });
        }

        // Main thread: services consumer.poll and reports progress
        let mut last_emit = Instant::now();
        while active_workers.load(Ordering::SeqCst) > 0 && !cancel_flag.load(Ordering::Relaxed) {
            if let Some(Ok(msg)) = consumer.poll(Duration::from_millis(50)) {
                let p = msg.partition();
                let off = msg.offset();
                let end_off = end_offsets.get(&p).copied().unwrap_or(0);
                if off < end_off {
                    let ts_ms = msg.timestamp().to_millis().unwrap_or(0);
                    let key = msg.key();
                    let payload = msg.payload();
                    let is_sr_encoded = payload.is_some_and(|b| b.len() >= 5 && b[0] == 0);
                    let parsed_payload = if value_is_avro || is_sr_encoded {
                        decode_message_to_value(
                            tokio_runtime,
                            &decoders,
                            payload,
                            value_is_avro || is_sr_encoded,
                        )
                    } else {
                        None
                    };
                    let decoded_key = if key_is_avro {
                        decode_message_component(tokio_runtime, &decoders, key, key_is_avro, "")
                    } else {
                        None
                    };
                    main_acc.record_message(
                        p,
                        off,
                        ts_ms,
                        key,
                        payload,
                        decoded_key.as_deref(),
                        parsed_payload.as_ref(),
                        is_sr_encoded,
                    );
                }
            }

            if last_emit.elapsed() >= Duration::from_millis(250) {
                let mut snapshot = accumulator.clone();
                for shared in &worker_accumulators {
                    if let Ok(acc) = shared.lock() {
                        snapshot.merge(&acc);
                    }
                }
                snapshot.merge(&main_acc);

                let elapsed_sec = scan_start.elapsed().as_secs_f64();
                let scanned = snapshot.total_messages;
                let mps = if elapsed_sec > 0.0 {
                    scanned as f64 / elapsed_sec
                } else {
                    0.0
                };
                let pct = if total_messages_to_scan > 0 {
                    (scanned as f64 / total_messages_to_scan as f64).min(0.99)
                } else {
                    0.0
                };

                let partial_report = snapshot.to_report(scan_start.elapsed().as_millis() as i64);
                let progress = TopicAnalysisProgress {
                    scanned_messages: scanned,
                    total_messages_to_scan,
                    progress: pct,
                    messages_per_second: mps,
                    current_partition: -1,
                    is_complete: false,
                    error_message: None,
                    partial_report: Some(partial_report),
                };

                if sink.add(progress).is_err() {
                    cancel_flag.store(true, Ordering::Relaxed);
                    break;
                }
                last_emit = Instant::now();
            }
        }
    });

    // Final Report
    let mut final_acc = accumulator.clone();
    for shared in &worker_accumulators {
        if let Ok(acc) = shared.lock() {
            final_acc.merge(&acc);
        }
    }
    final_acc.merge(&main_acc);

    let total_duration_ms = scan_start.elapsed().as_millis() as i64;
    let final_report = final_acc.to_report(total_duration_ms);
    let final_progress = TopicAnalysisProgress {
        scanned_messages: final_acc.total_messages,
        total_messages_to_scan,
        progress: 1.0,
        messages_per_second: if total_duration_ms > 0 {
            (final_acc.total_messages as f64) / (total_duration_ms as f64 / 1000.0)
        } else {
            0.0
        },
        current_partition: -1,
        is_complete: true,
        error_message: None,
        partial_report: Some(final_report),
    };

    sink.add(final_progress).ok();
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_remaining_range_nonempty() {
        // Data pending between next offset and end target
        assert!(remaining_range_nonempty(0, 1000, 500, 1000));
        // Next offset reached the end target — done
        assert!(!remaining_range_nonempty(0, 1000, 1000, 1000));
        // Remaining range deleted by retention: low moved past end target
        assert!(!remaining_range_nonempty(900, 1000, 500, 800));
        // Low watermark moved ahead of next offset but data remains
        assert!(remaining_range_nonempty(600, 1000, 500, 1000));
        // Log end shrunk below the snapshot end target (e.g. stale target)
        assert!(!remaining_range_nonempty(0, 700, 700, 1000));
        // Empty partition
        assert!(!remaining_range_nonempty(0, 0, 0, 0));
    }

    #[test]
    fn test_accumulator_empty() {
        let acc = AnalyzerAccumulator::new("test-topic".to_string(), false);
        let report = acc.to_report(10);
        assert_eq!(report.total_messages, 0);
        assert_eq!(report.total_bytes, 0);
        assert_eq!(report.tombstones_count, 0);
        assert_eq!(report.hourly_distribution.len(), 24);
        assert_eq!(report.partition_stats.len(), 0);
    }

    #[test]
    fn test_accumulator_with_json_and_tombstone() {
        let mut acc = AnalyzerAccumulator::new("events".to_string(), true);

        // 1. JSON message with categorical field
        let json_payload = br#"{"eventType": "USER_SIGNUP", "userId": "123", "status": "active"}"#;
        let key = b"user-123";
        // 2026-03-15 14:30:00 UTC -> 1773585000000 ms
        let ts = 1773585000000_i64;

        acc.record_message(0, 100, ts, Some(key), Some(json_payload), None, None, false);

        // 2. Tombstone message (null payload)
        acc.record_message(1, 200, ts, Some(b"user-456"), None, None, None, false);

        let report = acc.to_report(50);
        assert_eq!(report.total_messages, 2);
        assert_eq!(report.tombstones_count, 1);
        assert_eq!(report.is_compacted, true);
        assert_eq!(report.partition_stats.len(), 2);

        if let Some(h) = report.hourly_distribution.iter().find(|h| h.hour == 14) {
            assert_eq!(h.count, 2);
        } else {
            panic!("Expected hour 14 to be present");
        }

        // Check JSON field frequency
        if let Some(event_type_field) = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "eventType")
        {
            let top_vals = &event_type_field.top_values;
            assert_eq!(top_vals.len(), 1);
            assert_eq!(top_vals[0].value, "USER_SIGNUP");
        } else {
            panic!("Expected eventType field to be present");
        }
    }

    #[test]
    fn test_accumulator_partition_balance() {
        let mut acc = AnalyzerAccumulator::new("multi-part".to_string(), false);

        for _ in 0..70 {
            acc.record_message(0, 0, 1000, Some(b"k1"), Some(b"val"), None, None, false);
        }
        for _ in 0..30 {
            acc.record_message(1, 0, 1000, Some(b"k2"), Some(b"val"), None, None, false);
        }

        let report = acc.to_report(20);
        assert_eq!(report.total_messages, 100);
        assert_eq!(report.partition_stats.len(), 2);

        let p0 = report.partition_stats.iter().find(|p| p.partition == 0);
        let p1 = report.partition_stats.iter().find(|p| p.partition == 1);

        assert!(p0.is_some());
        assert!(p1.is_some());

        if let (Some(part0), Some(part1)) = (p0, p1) {
            assert_eq!(part0.message_count, 70);
            assert_eq!(part0.percentage, 70.0);
            assert_eq!(part1.message_count, 30);
            assert_eq!(part1.percentage, 30.0);
        }
    }

    #[test]
    fn test_accumulator_top_10_field_values() {
        let mut acc = AnalyzerAccumulator::new("orders".to_string(), false);

        // Record 15 different values for "countryCode", some appearing more frequently
        for i in 1..=15 {
            let count = if i <= 10 { 20 - i } else { 1 };
            let country = format!("CC_{}", i);
            for _ in 0..count {
                let payload = format!(
                    r#"{{"countryCode": "{}", "amount": {}, "isVerified": true}}"#,
                    country,
                    i * 10
                );
                acc.record_message(
                    0,
                    0,
                    1000,
                    None,
                    Some(payload.as_bytes()),
                    None,
                    None,
                    false,
                );
            }
        }

        let report = acc.to_report(100);
        if let Some(country_field) = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "countryCode")
        {
            // Top values should be capped at 10
            assert_eq!(country_field.top_values.len(), 10);
            // First value should be CC_1 with highest count (19)
            assert_eq!(country_field.top_values[0].value, "CC_1");
            assert_eq!(country_field.top_values[0].count, 19);
        } else {
            panic!("countryCode should exist");
        }

        // Check number field
        if let Some(amount_field) = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "amount")
        {
            assert_eq!(amount_field.top_values.len(), 10);
        } else {
            panic!("amount should exist");
        }

        // Check boolean field
        if let Some(verified_field) = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "isVerified")
        {
            assert_eq!(verified_field.top_values.len(), 1);
            assert_eq!(verified_field.top_values[0].value, "true");
        } else {
            panic!("isVerified should exist");
        }
    }

    #[test]
    fn test_accumulator_merge() {
        let mut acc1 = AnalyzerAccumulator::new("test-topic".to_string(), false);
        let mut acc2 = AnalyzerAccumulator::new("test-topic".to_string(), false);

        let json1 = br#"{"category": "A", "count": 10}"#;
        let json2 = br#"{"category": "B", "count": 20}"#;

        acc1.record_message(
            0,
            10,
            1773585000000_i64,
            Some(b"key1"),
            Some(json1),
            None,
            None,
            false,
        );
        acc2.record_message(
            1,
            20,
            1773585000000_i64,
            Some(b"key2"),
            Some(json2),
            None,
            None,
            false,
        );

        acc1.merge(&acc2);

        let report = acc1.to_report(50);
        assert_eq!(report.total_messages, 2);
        assert_eq!(report.partition_stats.len(), 2);
        assert_eq!(report.top_keys.len(), 2);

        let p0 = report
            .partition_stats
            .iter()
            .find(|p| p.partition == 0)
            .unwrap();
        let p1 = report
            .partition_stats
            .iter()
            .find(|p| p.partition == 1)
            .unwrap();
        assert_eq!(p0.message_count, 1);
        assert_eq!(p1.message_count, 1);

        let cat_field = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "category")
            .unwrap();
        assert_eq!(cat_field.count, 2);
        assert_eq!(cat_field.top_values.len(), 2);
    }
}
