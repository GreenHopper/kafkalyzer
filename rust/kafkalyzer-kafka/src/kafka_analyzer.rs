use anyhow::Result;
use chrono::{DateTime, Timelike};
use kafkalyzer_core::duplicate_fingerprint::{compute_message_fingerprint, MessageFingerprint};
use kafkalyzer_core::json_path::{build_canonical_path, render_for_statistics, FieldPath};
use kafkalyzer_core::kafka_types::{
    ClusterProfile, DuplicateAnalysisResult, DuplicateDetectionScope, FieldOccurrence,
    FieldValueFilter, FieldValueOccurrence, HourBucket, HourlyCount, KeyOccurrence,
    PartitionAnalysis, TopDuplicateOccurrence, TopicAnalysisOptions, TopicAnalysisProgress,
    TopicAnalysisReport, TypeOccurrence, ValueFilterResult,
};
use kafkalyzer_core::size_stats::SizeSample;
use rdkafka::admin::{AdminClient, AdminOptions, ResourceSpecifier};
use rdkafka::client::DefaultClientContext;
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::topic_partition_list::{Offset, TopicPartitionList};
use rdkafka::Message as KafkaMessageTrait;
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crate::kafka_consumer::{
    create_sr_settings, decode_message_component, decode_message_to_value, setup_schema_registry,
    StreamSink,
};
use crate::kafka_utils::create_config;

#[derive(Clone, Debug)]
pub struct CompiledValueFilter {
    pub path: FieldPath,
    pub target_value: String,
}

#[derive(Clone, Debug, Default)]
pub struct ValueFilterAccumulator {
    pub field_path: String,
    pub value: String,
    pub messages_with_field: i64,
    pub matched_messages: i64,
    pub matched_timeline: HashMap<i64, i64>,
}

#[derive(Clone, Debug)]
pub struct DuplicateSample {
    pub key: Option<String>,
    pub payload_preview: String,
    pub count: i64,
    pub sample_partition: i32,
    pub sample_offset: i64,
    pub sample_timestamp_ms: i64,
}

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
    /// Bounded sample of message sizes behind the reported percentiles.
    pub size_sample: SizeSample,
    /// Set once the capped key map had to drop a new key.
    pub key_cardinality_capped: bool,
    pub content_type_counts: HashMap<String, i64>,
    pub field_counts: HashMap<String, i64>,
    pub field_value_counts: HashMap<String, HashMap<String, i64>>,
    pub field_value_truncated: HashMap<String, HashMap<String, bool>>,
    pub capped_value_fields: HashSet<String>,
    pub hourly_timeline: HashMap<i64, i64>,
    pub scan_reference_time_ms: Option<i64>,
    pub timeline_outside_count: i64,
    pub sampled_partitions: HashSet<i32>,
    pub filter_accumulator: Option<ValueFilterAccumulator>,
    pub duplicate_scope: DuplicateDetectionScope,
    pub seen_fingerprints: HashSet<MessageFingerprint>,
    pub duplicate_samples: HashMap<MessageFingerprint, DuplicateSample>,
    pub recent_previews: HashMap<MessageFingerprint, (Option<String>, String, i32, i64, i64)>,
}

#[derive(Clone)]
pub struct PartitionStatsAccumulator {
    pub message_count: i64,
    pub byte_size: i64,
    pub earliest_offset: i64,
    pub latest_offset: i64,
    pub earliest_timestamp_ms: Option<i64>,
}

fn record_object_fields(
    field_counts: &mut HashMap<String, i64>,
    field_value_counts: &mut HashMap<String, HashMap<String, i64>>,
    field_value_truncated: &mut HashMap<String, HashMap<String, bool>>,
    capped_value_fields: &mut HashSet<String>,
    map: &serde_json::Map<String, Value>,
    segments: &mut Vec<String>,
    depth: usize,
) {
    if depth > 5 {
        return;
    }

    for (k, v) in map {
        segments.push(k.clone());
        let field_path = build_canonical_path(segments);

        // Record field occurrence (bounded up to 500 fields)
        if field_counts.len() < 500 || field_counts.contains_key(&field_path) {
            *field_counts.entry(field_path.clone()).or_insert(0) += 1;
        }

        // Check scalar value for top_values tracking
        let (val_str, truncated) = match v {
            Value::String(s) => {
                let char_count = s.chars().count();
                if char_count <= 80 {
                    (Some(s.clone()), false)
                } else {
                    let prefix: String = s.chars().take(77).collect();
                    (Some(format!("{}...", prefix)), true)
                }
            }
            Value::Number(n) => (Some(n.to_string()), false),
            Value::Bool(b) => (Some(b.to_string()), false),
            Value::Null => (Some("null".to_string()), false),
            _ => (None, false),
        };

        if let Some(v_str) = val_str {
            let val_map = field_value_counts.entry(field_path.clone()).or_default();
            if val_map.len() < 200 || val_map.contains_key(&v_str) {
                *val_map.entry(v_str.clone()).or_insert(0) += 1;
                if truncated {
                    field_value_truncated
                        .entry(field_path.clone())
                        .or_default()
                        .insert(v_str, true);
                }
            } else {
                capped_value_fields.insert(field_path.clone());
            }
        }

        // Recurse into child object if depth < 5
        if let Value::Object(child_map) = v {
            if depth < 5 {
                record_object_fields(
                    field_counts,
                    field_value_counts,
                    field_value_truncated,
                    capped_value_fields,
                    child_map,
                    segments,
                    depth + 1,
                );
            }
        }
        // Note: Arrays are NOT descended.

        segments.pop();
    }
}

fn truncate_preview(s: &str, max_chars: usize) -> String {
    if s.chars().count() <= max_chars {
        s.to_string()
    } else {
        let truncated: String = s.chars().take(max_chars).collect();
        format!("{}...", truncated)
    }
}

fn extract_duplicate_preview(
    parsed_payload: Option<&Value>,
    payload_bytes: Option<&[u8]>,
    max_chars: usize,
) -> String {
    if let Some(val) = parsed_payload {
        if let Ok(s) = serde_json::to_string(val) {
            return truncate_preview(&s, max_chars);
        }
    }
    match payload_bytes {
        None => "[Tombstone]".to_string(),
        Some(b) if b.is_empty() => "[Empty]".to_string(),
        Some(b) => {
            if let Ok(json_val) = serde_json::from_slice::<Value>(b) {
                if let Ok(s) = serde_json::to_string(&json_val) {
                    return truncate_preview(&s, max_chars);
                }
            }
            match std::str::from_utf8(b) {
                Ok(s) => truncate_preview(s, max_chars),
                Err(_) => format!("[Binary 0x{}]", hex_preview(b)),
            }
        }
    }
}

impl AnalyzerAccumulator {
    pub fn new(topic: String, is_compacted: bool) -> Self {
        Self::with_options(topic, is_compacted, None, HashSet::new(), None, None)
    }

    pub fn with_options(
        topic: String,
        is_compacted: bool,
        scan_reference_time_ms: Option<i64>,
        sampled_partitions: HashSet<i32>,
        filter: Option<FieldValueFilter>,
        duplicate_scope: Option<DuplicateDetectionScope>,
    ) -> Self {
        let filter_accumulator = filter.map(|f| ValueFilterAccumulator {
            field_path: f.field_path,
            value: f.value,
            messages_with_field: 0,
            matched_messages: 0,
            matched_timeline: HashMap::new(),
        });
        let duplicate_scope = duplicate_scope.unwrap_or(DuplicateDetectionScope::PayloadOnly);

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
            size_sample: SizeSample::default(),
            key_cardinality_capped: false,
            content_type_counts: HashMap::new(),
            field_counts: HashMap::new(),
            field_value_counts: HashMap::new(),
            field_value_truncated: HashMap::new(),
            capped_value_fields: HashSet::new(),
            hourly_timeline: HashMap::new(),
            scan_reference_time_ms,
            timeline_outside_count: 0,
            sampled_partitions,
            filter_accumulator,
            duplicate_scope,
            seen_fingerprints: HashSet::new(),
            duplicate_samples: HashMap::new(),
            recent_previews: HashMap::new(),
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

        // Timeline
        for (h, count) in &other.hourly_timeline {
            *self.hourly_timeline.entry(*h).or_insert(0) += count;
        }
        self.timeline_outside_count += other.timeline_outside_count;
        if self.scan_reference_time_ms.is_none() {
            self.scan_reference_time_ms = other.scan_reference_time_ms;
        }

        // Sampled partitions
        self.sampled_partitions.extend(&other.sampled_partitions);

        for (p, p_stat) in &other.partition_stats {
            let entry = self
                .partition_stats
                .entry(*p)
                .or_insert(PartitionStatsAccumulator {
                    message_count: 0,
                    byte_size: 0,
                    earliest_offset: p_stat.earliest_offset,
                    latest_offset: p_stat.latest_offset,
                    earliest_timestamp_ms: p_stat.earliest_timestamp_ms,
                });
            if p_stat.message_count > 0 {
                if entry.message_count == 0 {
                    entry.earliest_offset = p_stat.earliest_offset;
                    entry.latest_offset = p_stat.latest_offset;
                    entry.earliest_timestamp_ms = p_stat.earliest_timestamp_ms;
                } else {
                    entry.earliest_offset = entry.earliest_offset.min(p_stat.earliest_offset);
                    entry.latest_offset = entry.latest_offset.max(p_stat.latest_offset);
                    if let Some(other_ts) = p_stat.earliest_timestamp_ms {
                        entry.earliest_timestamp_ms = match entry.earliest_timestamp_ms {
                            None => Some(other_ts),
                            Some(prev) => Some(prev.min(other_ts)),
                        };
                    }
                }
            }
            entry.message_count += p_stat.message_count;
            entry.byte_size += p_stat.byte_size;
        }

        for (k, count) in &other.key_counts {
            if self.key_counts.len() < 10000 || self.key_counts.contains_key(k) {
                *self.key_counts.entry(k.clone()).or_insert(0) += count;
            } else {
                self.key_cardinality_capped = true;
            }
        }
        self.key_cardinality_capped |= other.key_cardinality_capped;
        self.size_sample.merge(other.size_sample.clone());

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
            let other_trunc_map = other.field_value_truncated.get(f);
            let self_trunc_map = self.field_value_truncated.entry(f.clone()).or_default();
            for (v, count) in val_map {
                if self_val_map.len() < 200 || self_val_map.contains_key(v) {
                    *self_val_map.entry(v.clone()).or_insert(0) += count;
                    if let Some(tm) = other_trunc_map {
                        if let Some(&tr) = tm.get(v) {
                            if tr {
                                self_trunc_map.insert(v.clone(), true);
                            }
                        }
                    }
                } else {
                    self.capped_value_fields.insert(f.clone());
                }
            }
        }
        self.capped_value_fields.extend(other.capped_value_fields.clone());

        // Value filter accumulator merge
        if let Some(ref mut self_filt) = self.filter_accumulator {
            if let Some(ref other_filt) = other.filter_accumulator {
                self_filt.messages_with_field += other_filt.messages_with_field;
                self_filt.matched_messages += other_filt.matched_messages;
                for (h, count) in &other_filt.matched_timeline {
                    *self_filt.matched_timeline.entry(*h).or_insert(0) += count;
                }
            }
        }

        // Duplicate detection merge
        for fp in &other.seen_fingerprints {
            if !self.seen_fingerprints.insert(*fp) {
                let other_cnt = other.duplicate_samples.get(fp).map(|s| s.count).unwrap_or(1);
                if let Some(sample) = self.duplicate_samples.get_mut(fp) {
                    sample.count += other_cnt;
                } else if self.duplicate_samples.len() < 1000 {
                    let (k, preview, p, o, ts) = if let Some(s) = other.duplicate_samples.get(fp) {
                        (
                            s.key.clone(),
                            s.payload_preview.clone(),
                            s.sample_partition,
                            s.sample_offset,
                            s.sample_timestamp_ms,
                        )
                    } else if let Some(recent) = other.recent_previews.get(fp) {
                        (recent.0.clone(), recent.1.clone(), recent.2, recent.3, recent.4)
                    } else if let Some(recent) = self.recent_previews.get(fp) {
                        (recent.0.clone(), recent.1.clone(), recent.2, recent.3, recent.4)
                    } else {
                        (None, "[Duplicate payload]".to_string(), 0, 0, 0)
                    };
                    self.duplicate_samples.insert(
                        *fp,
                        DuplicateSample {
                            key: k,
                            payload_preview: preview,
                            count: 1 + other_cnt,
                            sample_partition: p,
                            sample_offset: o,
                            sample_timestamp_ms: ts,
                        },
                    );
                }
            } else if let Some(other_sample) = other.duplicate_samples.get(fp) {
                if self.duplicate_samples.len() < 1000 {
                    self.duplicate_samples.insert(*fp, other_sample.clone());
                }
            }
        }
        for (fp, recent) in &other.recent_previews {
            if self.recent_previews.len() < 1000 {
                self.recent_previews.entry(*fp).or_insert_with(|| recent.clone());
            }
        }
    }

    #[allow(clippy::too_many_arguments)]
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
        self.record_message_with_filter(
            partition,
            offset,
            timestamp_ms,
            key_bytes,
            payload_bytes,
            decoded_key,
            parsed_payload,
            is_sr_encoded,
            None,
        );
    }

    #[allow(clippy::too_many_arguments)]
    pub fn record_message_with_filter(
        &mut self,
        partition: i32,
        offset: i64,
        timestamp_ms: i64,
        key_bytes: Option<&[u8]>,
        payload_bytes: Option<&[u8]>,
        decoded_key: Option<&str>,
        parsed_payload: Option<&Value>,
        is_sr_encoded: bool,
        compiled_filter: Option<&CompiledValueFilter>,
    ) {
        self.total_messages += 1;

        let key_len = key_bytes.map(|k| k.len() as i64).unwrap_or(0);
        let payload_len = payload_bytes.map(|p| p.len() as i64).unwrap_or(0);
        let msg_size = key_len + payload_len;

        self.total_bytes += msg_size;
        self.size_sample.record(partition, offset, msg_size);
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
                earliest_timestamp_ms: None,
            });
        p_stat.message_count += 1;
        p_stat.byte_size += msg_size;
        if offset < p_stat.earliest_offset {
            p_stat.earliest_offset = offset;
        }
        if offset > p_stat.latest_offset {
            p_stat.latest_offset = offset;
        }
        if timestamp_ms > 0 {
            p_stat.earliest_timestamp_ms = match p_stat.earliest_timestamp_ms {
                None => Some(timestamp_ms),
                Some(prev) => Some(prev.min(timestamp_ms)),
            };
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

            // Hourly timeline check
            let in_range = if let Some(ref_ms) = self.scan_reference_time_ms {
                let min_ts = ref_ms - 366 * 24 * 3_600_000;
                let max_ts = ref_ms + 24 * 3_600_000;
                timestamp_ms >= min_ts && timestamp_ms <= max_ts
            } else {
                true
            };

            if in_range {
                let epoch_hour = timestamp_ms.div_euclid(3_600_000);
                *self.hourly_timeline.entry(epoch_hour).or_insert(0) += 1;
            } else {
                self.timeline_outside_count += 1;
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
            Some(ref k) => {
                // Bounded tracking up to 10,000 unique keys
                if self.key_counts.len() < 10000 || self.key_counts.contains_key(k) {
                    *self.key_counts.entry(k.clone()).or_insert(0) += 1;
                } else {
                    self.key_cardinality_capped = true;
                }
            }
        }

        // Duplicate detection
        let fp = compute_message_fingerprint(self.duplicate_scope, key_bytes, payload_bytes);
        if !self.seen_fingerprints.insert(fp) {
            if let Some(sample) = self.duplicate_samples.get_mut(&fp) {
                sample.count += 1;
            } else if self.duplicate_samples.len() < 1000 {
                let (prev_key, prev_payload, p, o, ts) =
                    if let Some(recent) = self.recent_previews.get(&fp) {
                        (recent.0.clone(), recent.1.clone(), recent.2, recent.3, recent.4)
                    } else {
                        let preview = extract_duplicate_preview(parsed_payload, payload_bytes, 4000);
                        (key_str.clone(), preview, partition, offset, timestamp_ms)
                    };
                self.duplicate_samples.insert(
                    fp,
                    DuplicateSample {
                        key: prev_key,
                        payload_preview: prev_payload,
                        count: 2,
                        sample_partition: p,
                        sample_offset: o,
                        sample_timestamp_ms: ts,
                    },
                );
            }
        } else if self.recent_previews.len() < 1000 {
            let preview = extract_duplicate_preview(parsed_payload, payload_bytes, 4000);
            self.recent_previews.insert(
                fp,
                (key_str.clone(), preview, partition, offset, timestamp_ms),
            );
        }

        // Tombstone check
        let is_tombstone = parsed_payload.is_none() && payload_bytes.is_none_or(|p| p.is_empty());
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
                let mut segments = Vec::new();
                record_object_fields(
                    &mut self.field_counts,
                    &mut self.field_value_counts,
                    &mut self.field_value_truncated,
                    &mut self.capped_value_fields,
                    map,
                    &mut segments,
                    1,
                );
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

        // Evaluate value filter if configured
        if let Some(filter) = compiled_filter {
            if let Some(filter_acc) = self.filter_accumulator.as_mut() {
                if let Some(json_val) = json_ref {
                    if let Some(field_val) = filter.path.lookup(json_val) {
                        filter_acc.messages_with_field += 1;
                        if let Some(rendered) = render_for_statistics(field_val) {
                            if rendered == filter.target_value {
                                filter_acc.matched_messages += 1;
                                if timestamp_ms > 0 {
                                    let in_range = if let Some(ref_ms) = self.scan_reference_time_ms {
                                        let min_ts = ref_ms - 366 * 24 * 3_600_000;
                                        let max_ts = ref_ms + 24 * 3_600_000;
                                        timestamp_ms >= min_ts && timestamp_ms <= max_ts
                                    } else {
                                        true
                                    };
                                    if in_range {
                                        let epoch_hour = timestamp_ms.div_euclid(3_600_000);
                                        *filter_acc.matched_timeline.entry(epoch_hour).or_insert(0) += 1;
                                    }
                                }
                            }
                        }
                    }
                }
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

        // Hourly timeline sorted by epoch hour
        let mut hourly_timeline: Vec<HourBucket> = self
            .hourly_timeline
            .iter()
            .map(|(&epoch_hour, &count)| HourBucket { epoch_hour, count })
            .collect();
        hourly_timeline.sort_by_key(|b| b.epoch_hour);

        // Coverage start (complete_from_ms)
        let complete_from_ms = if self.sampled_partitions.is_empty() {
            None
        } else {
            self.sampled_partitions
                .iter()
                .filter_map(|p| {
                    self.partition_stats
                        .get(p)
                        .filter(|s| s.message_count > 0)
                        .and_then(|s| s.earliest_timestamp_ms)
                })
                .max()
        };

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

        // Field Frequencies & Top 10 Values (Top 100 fields)
        let mut fields_vec: Vec<(String, i64)> = self
            .field_counts
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        fields_vec.sort_by(|a, b| b.1.cmp(&a.1));
        fields_vec.truncate(100);

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

                    let trunc_map = self.field_value_truncated.get(&field_name);

                    top_vals = val_vec
                        .into_iter()
                        .map(|(val, v_count)| {
                            let v_pct = if count > 0 {
                                (v_count as f64 / count as f64) * 100.0
                            } else {
                                0.0
                            };
                            let truncated = trunc_map
                                .and_then(|m| m.get(&val).copied())
                                .unwrap_or(false);
                            FieldValueOccurrence {
                                value: val,
                                count: v_count,
                                percentage: v_pct,
                                truncated,
                            }
                        })
                        .collect();
                }

                let values_capped = self.capped_value_fields.contains(&field_name);

                FieldOccurrence {
                    field_name,
                    count,
                    percentage: pct,
                    top_values: top_vals,
                    values_capped,
                }
            })
            .collect();

        // Value filter result
        let value_filter_result = self.filter_accumulator.as_ref().map(|filt| {
            let mut matched_timeline: Vec<HourBucket> = filt
                .matched_timeline
                .iter()
                .map(|(&epoch_hour, &count)| HourBucket { epoch_hour, count })
                .collect();
            matched_timeline.sort_by_key(|b| b.epoch_hour);

            ValueFilterResult {
                field_path: filt.field_path.clone(),
                value: filt.value.clone(),
                messages_with_field: filt.messages_with_field,
                matched_messages: filt.matched_messages,
                matched_timeline,
            }
        });

        // Duplicate analysis result
        let unique_msgs = self.seen_fingerprints.len() as i64;
        let duplicate_msgs = if total_msgs >= unique_msgs {
            total_msgs - unique_msgs
        } else {
            0
        };
        let duplicate_rate = if total_msgs > 0 {
            (duplicate_msgs as f64 / total_msgs as f64) * 100.0
        } else {
            0.0
        };

        let mut sorted_duplicates: Vec<&DuplicateSample> =
            self.duplicate_samples.values().collect();
        sorted_duplicates.sort_by(|a, b| b.count.cmp(&a.count));

        let top_duplicates: Vec<TopDuplicateOccurrence> = sorted_duplicates
            .into_iter()
            .take(20)
            .map(|s| {
                let percentage = if total_msgs > 0 {
                    (s.count as f64 / total_msgs as f64) * 100.0
                } else {
                    0.0
                };
                TopDuplicateOccurrence {
                    key: s.key.clone(),
                    payload_preview: s.payload_preview.clone(),
                    count: s.count,
                    percentage,
                    sample_partition: s.sample_partition,
                    sample_offset: s.sample_offset,
                    sample_timestamp_ms: s.sample_timestamp_ms,
                }
            })
            .collect();

        let duplicate_analysis_result = Some(DuplicateAnalysisResult {
            scope: self.duplicate_scope,
            total_messages: total_msgs,
            unique_messages: unique_msgs,
            duplicate_messages: duplicate_msgs,
            duplicate_rate,
            top_duplicates,
        });

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
            message_size_percentiles: self.size_sample.percentiles(),
            size_percentiles_estimated: self.size_sample.estimated(),
            estimated_distinct_keys: self.key_counts.len() as i64,
            key_cardinality_capped: self.key_cardinality_capped,
            hourly_timeline,
            scan_reference_time_ms: self.scan_reference_time_ms,
            complete_from_ms,
            timeline_outside_count: self.timeline_outside_count,
            value_filter_result,
            duplicate_analysis_result,
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
    options: TopicAnalysisOptions,
    sink: StreamSink<TopicAnalysisProgress>,
    cancel_flag: Arc<AtomicBool>,
) -> Result<()> {
    let scan_reference_time_ms = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0);

    let compiled_filter = if let Some(ref filter) = options.value_filter {
        match FieldPath::parse(&filter.field_path) {
            Some(path) => Some(CompiledValueFilter {
                path,
                target_value: filter.value.clone(),
            }),
            None => {
                let progress = TopicAnalysisProgress {
                    scanned_messages: 0,
                    total_messages_to_scan: 0,
                    progress: 1.0,
                    messages_per_second: 0.0,
                    current_partition: -1,
                    is_complete: true,
                    error_message: Some(format!(
                        "Invalid filter field path: '{}'",
                        filter.field_path
                    )),
                    partial_report: None,
                };
                sink.add(progress).ok();
                return Ok(());
            }
        }
    } else {
        None
    };

    // 1. Setup Runtime & Schema Registry
    let tokio_runtime = crate::kafka_consumer::shared_runtime();
    let sr_settings = create_sr_settings(&profile);
    let (decoders, key_is_avro, value_is_avro) = if let Some(ref settings) = sr_settings {
        setup_schema_registry(tokio_runtime, settings, &topic, &profile)
            .unwrap_or((None, false, false))
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
    let mut sampled_partitions = std::collections::HashSet::new();
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

        if let Some(max_msgs) = options.max_messages {
            let target_per_partition = (max_msgs / part_count.max(1)).max(1);
            if options.sample_from_latest && available > target_per_partition {
                start_off = (high - target_per_partition).max(low);
            }
        }

        if start_off > low {
            sampled_partitions.insert(p_id);
        }

        let to_scan_p = (end_off - start_off).max(0);
        total_messages_to_scan += to_scan_p;

        start_offsets.insert(p_id, start_off);
        end_offsets.insert(p_id, end_off);

        if start_off >= end_off {
            completed_partitions.insert(p_id);
        }

        tpl.add_partition_offset(&topic, p_id, Offset::Offset(start_off))?;
    }

    let mut accumulator = AnalyzerAccumulator::with_options(
        topic.clone(),
        is_compacted,
        Some(scan_reference_time_ms),
        sampled_partitions.clone(),
        options.value_filter.clone(),
        options.duplicate_scope,
    );

    // Pre-populate partition stats so all partitions are visible in the report from the beginning
    for partition in topic_meta.partitions() {
        let p_id = partition.id();
        let start_off = start_offsets.get(&p_id).copied().unwrap_or(0);
        accumulator.partition_stats.insert(
            p_id,
            PartitionStatsAccumulator {
                message_count: 0,
                byte_size: 0,
                earliest_offset: start_off,
                latest_offset: start_off,
                earliest_timestamp_ms: None,
            },
        );
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
            Arc::new(std::sync::Mutex::new(AnalyzerAccumulator::with_options(
                topic.clone(),
                is_compacted,
                Some(scan_reference_time_ms),
                sampled_partitions.clone(),
                options.value_filter.clone(),
                options.duplicate_scope,
            )))
        })
        .collect();

    let active_workers = Arc::new(std::sync::atomic::AtomicUsize::new(num_workers));
    let scan_start = Instant::now();
    let mut main_acc = AnalyzerAccumulator::with_options(
        topic.clone(),
        is_compacted,
        Some(scan_reference_time_ms),
        sampled_partitions,
        options.value_filter,
        options.duplicate_scope,
    );

    let compiled_filter_ref = compiled_filter.as_ref();

    std::thread::scope(|s| {
        for (w_idx, tasks) in worker_tasks.into_iter().enumerate() {
            let w_acc_arc = worker_accumulators[w_idx].clone();
            let active_workers = active_workers.clone();
            let cancel_flag = &cancel_flag;
            let tokio_runtime = &tokio_runtime;
            let decoders = &decoders;
            let topic = &topic;
            let worker_consumer = consumer.clone();
            let compiled_filter = compiled_filter_ref;

            s.spawn(move || {
                let mut local_acc = w_acc_arc.lock().unwrap().clone();
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

                                local_acc.record_message_with_filter(
                                    *p_id,
                                    off,
                                    ts_ms,
                                    key,
                                    payload,
                                    decoded_key.as_deref(),
                                    parsed_payload.as_ref(),
                                    is_sr_encoded,
                                    compiled_filter,
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

                                        local_acc.record_message_with_filter(
                                            *p_id,
                                            off,
                                            ts_ms,
                                            key,
                                            payload,
                                            decoded_key.as_deref(),
                                            parsed_payload.as_ref(),
                                            is_sr_encoded,
                                            compiled_filter,
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
                    main_acc.record_message_with_filter(
                        p,
                        off,
                        ts_ms,
                        key,
                        payload,
                        decoded_key.as_deref(),
                        parsed_payload.as_ref(),
                        is_sr_encoded,
                        compiled_filter_ref,
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

pub fn analyze_topic_content_legacy(
    profile: ClusterProfile,
    topic: String,
    max_messages: Option<i64>,
    sample_from_latest: bool,
    sink: StreamSink<TopicAnalysisProgress>,
    cancel_flag: Arc<AtomicBool>,
) -> Result<()> {
    analyze_topic_content(
        profile,
        topic,
        TopicAnalysisOptions {
            max_messages,
            sample_from_latest,
            value_filter: None,
            duplicate_scope: None,
        },
        sink,
        cancel_flag,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_scan_above_the_sample_limit_reports_estimated_percentiles() {
        let mut acc = AnalyzerAccumulator::new("orders".to_string(), false);
        for offset in 0..100_000i64 {
            acc.record_message(0, offset, 0, None, Some(b"x"), None, None, false);
        }
        let report = acc.to_report(10);
        assert!(report.size_percentiles_estimated);
        assert_eq!(report.message_size_percentiles.unwrap().p50, 1);
    }

    #[test]
    fn a_small_scan_reports_exact_percentiles() {
        let mut acc = AnalyzerAccumulator::new("orders".to_string(), false);
        for offset in 0..100i64 {
            acc.record_message(0, offset, 0, None, Some(b"x"), None, None, false);
        }
        let report = acc.to_report(10);
        assert!(!report.size_percentiles_estimated);
        assert_eq!(report.message_size_percentiles.unwrap().p99, 1);
    }

    #[test]
    fn a_capped_key_map_marks_distinct_keys_as_a_lower_bound() {
        let mut acc = AnalyzerAccumulator::new("orders".to_string(), false);
        for offset in 0..10_005i64 {
            let key = format!("key-{offset}");
            acc.record_message(
                0,
                offset,
                0,
                Some(key.as_bytes()),
                Some(b"x"),
                None,
                None,
                false,
            );
        }
        let report = acc.to_report(10);
        assert!(report.key_cardinality_capped);
        assert_eq!(report.estimated_distinct_keys, 10_000);
    }

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

    #[test]
    fn test_timeline_recording_and_range_check() {
        // ref = 2026-10-30 14:30:00 UTC
        let ts_day2 = 1793370600000_i64;
        // 24 hours earlier = 2026-10-29 14:30:00 UTC
        let ts_day1 = ts_day2 - 86_400_000;

        let mut acc1 = AnalyzerAccumulator::with_options(
            "t1".into(),
            false,
            Some(ts_day2),
            HashSet::new(),
            None,
            None,
        );
        let mut acc2 = AnalyzerAccumulator::with_options(
            "t1".into(),
            false,
            Some(ts_day2),
            HashSet::new(),
            None,
            None,
        );

        // Day 1 message on acc1
        acc1.record_message(0, 1, ts_day1, None, Some(b"{}"), None, None, false);
        // Day 2 message on acc2
        acc2.record_message(0, 2, ts_day2, None, Some(b"{}"), None, None, false);
        // Invalid timestamp <= 0
        acc1.record_message(0, 3, 0, None, Some(b"{}"), None, None, false);
        acc1.record_message(0, 4, -100, None, Some(b"{}"), None, None, false);
        // Timestamp > ref + 1 day
        acc1.record_message(0, 5, ts_day2 + 100_000_000, None, Some(b"{}"), None, None, false);
        // Timestamp < ref - 366 days
        acc1.record_message(0, 6, ts_day2 - 32_000_000_000, None, Some(b"{}"), None, None, false);

        acc1.merge(&acc2);

        let report = acc1.to_report(10);
        assert_eq!(report.total_messages, 6);
        assert_eq!(report.timeline_outside_count, 2);

        // Hourly distribution (24h UTC) folds both days into hour 14
        let h14 = report.hourly_distribution.iter().find(|h| h.hour == 14).unwrap();
        assert_eq!(h14.count, 2);

        // Timeline has two separate epoch hour buckets
        let epoch_h1 = ts_day1.div_euclid(3_600_000);
        let epoch_h2 = ts_day2.div_euclid(3_600_000);
        assert_eq!(report.hourly_timeline.len(), 2);
        assert_eq!(report.hourly_timeline[0].epoch_hour, epoch_h1);
        assert_eq!(report.hourly_timeline[0].count, 1);
        assert_eq!(report.hourly_timeline[1].epoch_hour, epoch_h2);
        assert_eq!(report.hourly_timeline[1].count, 1);
    }

    #[test]
    fn test_coverage_tracking() {
        // 1. Full scan (no sampled partitions)
        let mut acc_full = AnalyzerAccumulator::with_options(
            "t1".into(),
            false,
            Some(100_000),
            HashSet::new(),
            None,
            None,
        );
        acc_full.record_message(0, 0, 50_000, None, Some(b"{}"), None, None, false);
        let rep_full = acc_full.to_report(5);
        assert_eq!(rep_full.complete_from_ms, None);

        // 2. Sampled partition with messages
        let mut sampled = HashSet::new();
        sampled.insert(1);
        let mut acc_sampled = AnalyzerAccumulator::with_options(
            "t1".into(),
            false,
            Some(100_000),
            sampled.clone(),
            None,
            None,
        );
        acc_sampled.record_message(0, 0, 20_000, None, Some(b"{}"), None, None, false);
        acc_sampled.record_message(1, 0, 60_000, None, Some(b"{}"), None, None, false);
        acc_sampled.record_message(1, 1, 70_000, None, Some(b"{}"), None, None, false);
        let rep_sampled = acc_sampled.to_report(5);
        // Max earliest timestamp among sampled partitions is 60_000
        assert_eq!(rep_sampled.complete_from_ms, Some(60_000));

        // 3. Sampled partition without messages
        let mut acc_empty_sample = AnalyzerAccumulator::with_options(
            "t1".into(),
            false,
            Some(100_000),
            sampled,
            None,
            None,
        );
        acc_empty_sample.record_message(0, 0, 20_000, None, Some(b"{}"), None, None, false);
        let rep_empty_sample = acc_empty_sample.to_report(5);
        assert_eq!(rep_empty_sample.complete_from_ms, None);
    }

    #[test]
    fn test_recursive_field_visitor_and_truncation() {
        let mut acc = AnalyzerAccumulator::new("nested".into(), false);

        // Deep nested json
        let deep_json = serde_json::json!({
            "order": {
                "id": "A1",
                "nested": {
                    "l3": {
                        "l4": {
                            "l5": {
                                "l6_hidden": "deep"
                            }
                        }
                    }
                }
            },
            "attributes": {
                "region": "EU"
            },
            "labels": {
                "app.kubernetes.io/name": "kafkalyzer"
            },
            "items": [1, 2, 3]
        });

        acc.record_message(
            0,
            0,
            1000,
            None,
            None,
            None,
            Some(&deep_json),
            false,
        );

        let report = acc.to_report(5);
        let names: Vec<&str> = report.field_frequencies.iter().map(|f| f.field_name.as_str()).collect();
        assert!(names.contains(&"order"));
        assert!(names.contains(&"order.id"));
        assert!(names.contains(&"attributes.region"));
        assert!(names.contains(&"/labels/app.kubernetes.io~1name"));
        assert!(names.contains(&"items"));
        assert!(names.contains(&"order.nested.l3.l4.l5"));
        assert!(!names.contains(&"order.nested.l3.l4.l5.l6_hidden"), "Depth > 5 should not be descended");

        // Test multi-byte string > 80 chars truncation
        let long_str = "äöü-".repeat(25); // 100 chars, multibyte
        assert!(long_str.chars().count() > 80);
        let long_payload = serde_json::json!({
            "desc": long_str
        });
        acc.record_message(0, 1, 1000, None, None, None, Some(&long_payload), false);
        let report2 = acc.to_report(5);
        let desc_field = report2.field_frequencies.iter().find(|f| f.field_name == "desc").unwrap();
        assert_eq!(desc_field.top_values[0].truncated, true);
        assert!(desc_field.top_values[0].value.ends_with("..."));

        // Test capped field (more than 200 distinct values)
        for i in 0..210 {
            let p = serde_json::json!({ "many_vals": format!("val_{}", i) });
            acc.record_message(0, 2 + i, 1000, None, None, None, Some(&p), false);
        }
        let report3 = acc.to_report(5);
        let mv_field = report3.field_frequencies.iter().find(|f| f.field_name == "many_vals").unwrap();
        assert_eq!(mv_field.values_capped, true);
    }

    #[test]
    fn test_value_filter_accumulator() {
        let filter = FieldValueFilter {
            field_path: "attributes.region".into(),
            value: "EU".into(),
        };
        let compiled = CompiledValueFilter {
            path: FieldPath::parse(&filter.field_path).unwrap(),
            target_value: filter.value.clone(),
        };

        let mut acc1 = AnalyzerAccumulator::with_options(
            "filt".into(),
            false,
            Some(100_000_000),
            HashSet::new(),
            Some(filter.clone()),
            None,
        );
        let mut acc2 = AnalyzerAccumulator::with_options(
            "filt".into(),
            false,
            Some(100_000_000),
            HashSet::new(),
            Some(filter),
            None,
        );

        // 1. Matches: attributes.region = "EU"
        let p_match = serde_json::json!({ "attributes": { "region": "EU" } });
        acc1.record_message_with_filter(0, 0, 3_600_000, None, None, None, Some(&p_match), false, Some(&compiled));

        // 2. Case mismatch: attributes.region = "eu"
        let p_case = serde_json::json!({ "attributes": { "region": "eu" } });
        acc1.record_message_with_filter(0, 1, 3_600_000, None, None, None, Some(&p_case), false, Some(&compiled));

        // 3. Different value: attributes.region = "US"
        let p_us = serde_json::json!({ "attributes": { "region": "US" } });
        acc2.record_message_with_filter(0, 2, 7_200_000, None, None, None, Some(&p_us), false, Some(&compiled));

        // 4. Absent field
        let p_other = serde_json::json!({ "status": "OK" });
        acc2.record_message_with_filter(0, 3, 7_200_000, None, None, None, Some(&p_other), false, Some(&compiled));

        // 5. Tombstone
        acc2.record_message_with_filter(0, 4, 7_200_000, None, None, None, None, false, Some(&compiled));

        // 6. Non-JSON text
        acc2.record_message_with_filter(0, 5, 7_200_000, None, Some(b"non-json-plain-text"), None, None, false, Some(&compiled));

        acc1.merge(&acc2);

        let report = acc1.to_report(10);
        let res = report.value_filter_result.expect("Value filter result should be present");
        assert_eq!(res.field_path, "attributes.region");
        assert_eq!(res.value, "EU");
        assert_eq!(res.messages_with_field, 3); // EU, eu, US
        assert_eq!(res.matched_messages, 1); // only exact EU
        assert_eq!(res.matched_timeline.len(), 1);
        assert_eq!(res.matched_timeline[0].epoch_hour, 1);
        assert_eq!(res.matched_timeline[0].count, 1);

        // Also test null matching with another accumulator
        let null_filter = FieldValueFilter {
            field_path: "deletedAt".into(),
            value: "null".into(),
        };
        let null_compiled = CompiledValueFilter {
            path: FieldPath::parse(&null_filter.field_path).unwrap(),
            target_value: "null".into(),
        };
        let mut acc_null = AnalyzerAccumulator::with_options(
            "filt".into(),
            false,
            Some(100_000_000),
            HashSet::new(),
            Some(null_filter),
            None,
        );
        let p_null = serde_json::json!({ "deletedAt": null });
        acc_null.record_message_with_filter(0, 0, 1000, None, None, None, Some(&p_null), false, Some(&null_compiled));
        let rep_null = acc_null.to_report(5);
        let res_null = rep_null.value_filter_result.unwrap();
        assert_eq!(res_null.messages_with_field, 1);
        assert_eq!(res_null.matched_messages, 1);
    }

    #[test]
    fn test_duplicate_detection_payload_only() {
        let mut acc = AnalyzerAccumulator::with_options(
            "dup-test".into(),
            false,
            Some(100_000),
            HashSet::new(),
            None,
            Some(DuplicateDetectionScope::PayloadOnly),
        );

        // Msg 1: Key "k1", payload A
        acc.record_message(0, 0, 1000, Some(b"k1"), Some(b"{\"id\":100}"), None, None, false);
        // Msg 2: Key "k2", payload A (Duplicate under PayloadOnly!)
        acc.record_message(0, 1, 2000, Some(b"k2"), Some(b"{\"id\":100}"), None, None, false);
        // Msg 3: Key None, payload A (Duplicate under PayloadOnly!)
        acc.record_message(0, 2, 3000, None, Some(b"{\"id\":100}"), None, None, false);
        // Msg 4: Key "k1", payload B (Unique)
        acc.record_message(0, 3, 4000, Some(b"k1"), Some(b"{\"id\":200}"), None, None, false);

        let report = acc.to_report(10);
        assert_eq!(report.total_messages, 4);

        let dup_res = report.duplicate_analysis_result.expect("duplicate result present");
        assert_eq!(dup_res.scope, DuplicateDetectionScope::PayloadOnly);
        assert_eq!(dup_res.total_messages, 4);
        assert_eq!(dup_res.unique_messages, 2);
        assert_eq!(dup_res.duplicate_messages, 2);
        assert!((dup_res.duplicate_rate - 50.0).abs() < 0.01);
        assert_eq!(dup_res.top_duplicates.len(), 1);
        assert_eq!(dup_res.top_duplicates[0].count, 3);
        assert_eq!(dup_res.top_duplicates[0].payload_preview, "{\"id\":100}");
        assert!((dup_res.top_duplicates[0].percentage - 75.0).abs() < 0.01);
    }

    #[test]
    fn test_duplicate_detection_key_and_payload() {
        let mut acc = AnalyzerAccumulator::with_options(
            "dup-test".into(),
            false,
            Some(100_000),
            HashSet::new(),
            None,
            Some(DuplicateDetectionScope::KeyAndPayload),
        );

        // Msg 1: Key "k1", payload A
        acc.record_message(0, 0, 1000, Some(b"k1"), Some(b"{\"id\":100}"), None, None, false);
        // Msg 2: Key "k2", payload A (NOT duplicate under KeyAndPayload)
        acc.record_message(0, 1, 2000, Some(b"k2"), Some(b"{\"id\":100}"), None, None, false);
        // Msg 3: Key "k1", payload A (Duplicate under KeyAndPayload)
        acc.record_message(0, 2, 3000, Some(b"k1"), Some(b"{\"id\":100}"), None, None, false);

        let report = acc.to_report(10);
        assert_eq!(report.total_messages, 3);

        let dup_res = report.duplicate_analysis_result.expect("duplicate result present");
        assert_eq!(dup_res.scope, DuplicateDetectionScope::KeyAndPayload);
        assert_eq!(dup_res.total_messages, 3);
        assert_eq!(dup_res.unique_messages, 2);
        assert_eq!(dup_res.duplicate_messages, 1);
        assert!((dup_res.duplicate_rate - 33.333).abs() < 0.01);
        assert_eq!(dup_res.top_duplicates.len(), 1);
        assert_eq!(dup_res.top_duplicates[0].count, 2);
        assert_eq!(dup_res.top_duplicates[0].key.as_deref(), Some("k1"));
    }

    #[test]
    fn test_duplicate_detection_cross_accumulator_merge() {
        let mut acc1 = AnalyzerAccumulator::with_options(
            "dup-test".into(),
            false,
            Some(100_000),
            HashSet::new(),
            None,
            Some(DuplicateDetectionScope::PayloadOnly),
        );
        let mut acc2 = AnalyzerAccumulator::with_options(
            "dup-test".into(),
            false,
            Some(100_000),
            HashSet::new(),
            None,
            Some(DuplicateDetectionScope::PayloadOnly),
        );

        // Worker 1 receives payload X
        acc1.record_message(0, 0, 1000, Some(b"k1"), Some(b"payload-X"), None, None, false);
        // Worker 2 receives payload X
        acc2.record_message(1, 0, 2000, Some(b"k2"), Some(b"payload-X"), None, None, false);

        acc1.merge(&acc2);

        let report = acc1.to_report(10);
        assert_eq!(report.total_messages, 2);
        let dup_res = report.duplicate_analysis_result.expect("duplicate result present");
        assert_eq!(dup_res.unique_messages, 1);
        assert_eq!(dup_res.duplicate_messages, 1);
        assert_eq!(dup_res.top_duplicates.len(), 1);
        assert_eq!(dup_res.top_duplicates[0].count, 2);
    }

    #[test]
    fn test_duplicate_detection_with_parsed_payload_and_binary_fallback() {
        let mut acc = AnalyzerAccumulator::with_options(
            "dup-avro".into(),
            false,
            Some(100_000),
            HashSet::new(),
            None,
            Some(DuplicateDetectionScope::PayloadOnly),
        );

        // Binary wire-format payload (e.g. Confluent magic byte 0x00 + schema ID 20 + binary bytes)
        let raw_avro_bytes = vec![0x00, 0x00, 0x00, 0x00, 0x14, 0xfa, 0x18, 0x57, 0x96];
        let decoded_json = serde_json::json!({
            "COR_ID": "COR-12345",
            "loadingPoint": "LP-1",
            "status": "READY"
        });

        // Msg 1: Avro encoded, decoded to parsed_payload
        acc.record_message(
            0,
            0,
            1000,
            Some(b"k1"),
            Some(&raw_avro_bytes),
            Some("k1"),
            Some(&decoded_json),
            true,
        );
        // Msg 2: Duplicate of Msg 1
        acc.record_message(
            0,
            1,
            2000,
            Some(b"k1"),
            Some(&raw_avro_bytes),
            Some("k1"),
            Some(&decoded_json),
            true,
        );

        // Msg 3 & 4: Raw undecodable binary
        let raw_unknown_binary = vec![0xff, 0xfe, 0xfd, 0xfc];
        acc.record_message(
            0,
            2,
            3000,
            None,
            Some(&raw_unknown_binary),
            None,
            None,
            false,
        );
        acc.record_message(
            0,
            3,
            4000,
            None,
            Some(&raw_unknown_binary),
            None,
            None,
            false,
        );

        let report = acc.to_report(10);
        let dup_res = report.duplicate_analysis_result.expect("duplicate result present");
        assert_eq!(dup_res.total_messages, 4);
        assert_eq!(dup_res.unique_messages, 2);
        assert_eq!(dup_res.duplicate_messages, 2);
        assert_eq!(dup_res.top_duplicates.len(), 2);

        // Check that Avro message decoded into readable JSON string, NOT [Binary 0x...]
        let avro_dup = dup_res
            .top_duplicates
            .iter()
            .find(|d| d.key.as_deref() == Some("k1"))
            .expect("Avro duplicate found");
        assert!(
            avro_dup.payload_preview.contains("\"COR_ID\":\"COR-12345\""),
            "Expected decoded JSON, got: {}",
            avro_dup.payload_preview
        );

        // Check that raw binary fell back to [Binary 0x...]
        let bin_dup = dup_res
            .top_duplicates
            .iter()
            .find(|d| d.key.is_none())
            .expect("Binary duplicate found");
        assert_eq!(bin_dup.payload_preview, "[Binary 0xfffefdfc]");
    }
}
