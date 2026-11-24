use anyhow::Result;
use chrono::{DateTime, Timelike};
use kafkalyzer_core::analysis_limits::{
    AnalysisLimit, AnalysisLimitKind, MAX_DUPLICATE_SAMPLES, MAX_FIELD_DEPTH,
    MAX_LISTED_DUPLICATES, MAX_LISTED_KEYS, MAX_LISTED_VALUES, MAX_PREVIEW_CHARS,
    MAX_REPORTED_FIELDS, MAX_SIZE_SAMPLE, MAX_TRACKED_FIELDS, MAX_TRACKED_KEYS,
    MAX_VALUES_PER_FIELD, MAX_VALUE_CHARS, TIMELINE_PAST_DAYS,
};
use kafkalyzer_core::analysis_scope::{
    plan_scan, AnalysisScope, AnalysisScopeEstimate, ScanPlan, TimeBound, TimeBounds,
};
use kafkalyzer_core::duplicate_fingerprint::{
    compute_message_fingerprint, BoundedFingerprintSet, FingerprintOutcome, MessageFingerprint,
};
use kafkalyzer_core::json_path::{build_canonical_path, render_for_statistics, FieldPath};
use kafkalyzer_core::kafka_types::{
    AnalysisScopeSummary, ClusterProfile, DuplicateAnalysisResult, DuplicateDetectionScope,
    FieldOccurrence, FieldValueFilter, FieldValueOccurrence, HourBucket, HourlyCount,
    KeyOccurrence, PartitionAnalysis, TopDuplicateOccurrence, TopicAnalysisOptions,
    TopicAnalysisProgress, TopicAnalysisReport, TypeOccurrence, ValueFilterResult,
};
use kafkalyzer_core::offset_distribution::WatermarkRead;
use kafkalyzer_core::size_stats::SizeSample;
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::error::KafkaError;
use rdkafka::topic_partition_list::{Offset, TopicPartitionList};
use rdkafka::Message as KafkaMessageTrait;
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

use crate::kafka_consumer::{create_sr_settings, setup_schema_registry, StreamSink};
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
    pub cleanup_policy_unknown: bool,
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
    pub started_after_low_partitions: HashSet<i32>,
    pub ended_before_high_partitions: HashSet<i32>,
    pub time_window: Option<(Option<i64>, Option<i64>)>,
    pub excluded_by_time_range: i64,
    pub scan_scope_summary: Option<AnalysisScopeSummary>,
    pub filter_accumulator: Option<ValueFilterAccumulator>,
    pub duplicate_scope: DuplicateDetectionScope,
    pub fingerprint_set: Arc<BoundedFingerprintSet>,
    pub duplicate_samples: HashMap<MessageFingerprint, DuplicateSample>,
    pub duplicate_samples_capped: bool,
    pub field_cap_reached: bool,
    pub depth_limit_reached: bool,
    pub preview_truncated: bool,
}

#[derive(Clone)]
pub struct PartitionStatsAccumulator {
    pub message_count: i64,
    pub byte_size: i64,
    pub earliest_offset: i64,
    pub latest_offset: i64,
    pub earliest_timestamp_ms: Option<i64>,
    pub latest_timestamp_ms: Option<i64>,
}

#[allow(clippy::too_many_arguments)]
fn record_object_fields(
    field_counts: &mut HashMap<String, i64>,
    field_value_counts: &mut HashMap<String, HashMap<String, i64>>,
    field_value_truncated: &mut HashMap<String, HashMap<String, bool>>,
    capped_value_fields: &mut HashSet<String>,
    field_cap_reached: &mut bool,
    depth_limit_reached: &mut bool,
    map: &serde_json::Map<String, Value>,
    segments: &mut Vec<String>,
    depth: usize,
) {
    if depth > MAX_FIELD_DEPTH {
        return;
    }

    for (k, v) in map {
        segments.push(k.clone());
        let field_path = build_canonical_path(segments);

        // Record field occurrence (bounded up to MAX_TRACKED_FIELDS)
        if field_counts.len() < MAX_TRACKED_FIELDS || field_counts.contains_key(&field_path) {
            *field_counts.entry(field_path.clone()).or_insert(0) += 1;
        } else {
            *field_cap_reached = true;
        }

        // Check scalar value for top_values tracking
        let (val_str, truncated) = match v {
            Value::String(s) => {
                let char_count = s.chars().count();
                if char_count <= MAX_VALUE_CHARS {
                    (Some(s.clone()), false)
                } else {
                    let prefix: String = s.chars().take(MAX_VALUE_CHARS - 3).collect();
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
            if val_map.len() < MAX_VALUES_PER_FIELD || val_map.contains_key(&v_str) {
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

        // Recurse into child object if depth < MAX_FIELD_DEPTH
        if let Value::Object(child_map) = v {
            if depth < MAX_FIELD_DEPTH {
                record_object_fields(
                    field_counts,
                    field_value_counts,
                    field_value_truncated,
                    capped_value_fields,
                    field_cap_reached,
                    depth_limit_reached,
                    child_map,
                    segments,
                    depth + 1,
                );
            } else {
                *depth_limit_reached = true;
            }
        }
        // Note: Arrays are NOT descended.

        segments.pop();
    }
}

fn truncate_preview(s: &str, max_chars: usize) -> (String, bool) {
    if s.chars().count() <= max_chars {
        (s.to_string(), false)
    } else {
        let truncated: String = s.chars().take(max_chars).collect();
        (format!("{}...", truncated), true)
    }
}

fn extract_duplicate_preview(
    parsed_payload: Option<&Value>,
    payload_bytes: Option<&[u8]>,
    max_chars: usize,
) -> (String, bool) {
    if let Some(val) = parsed_payload {
        if let Ok(s) = serde_json::to_string(val) {
            return truncate_preview(&s, max_chars);
        }
    }
    match payload_bytes {
        None => ("[Tombstone]".to_string(), false),
        Some([]) => ("[Empty]".to_string(), false),
        Some(b) => {
            if let Ok(json_val) = serde_json::from_slice::<Value>(b) {
                if let Ok(s) = serde_json::to_string(&json_val) {
                    return truncate_preview(&s, max_chars);
                }
            }
            match std::str::from_utf8(b) {
                Ok(s) => truncate_preview(s, max_chars),
                Err(_) => (format!("[Binary 0x{}]", hex_preview(b)), false),
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
        Self::with_scope_and_fingerprints(
            topic,
            is_compacted,
            scan_reference_time_ms,
            sampled_partitions,
            HashSet::new(),
            None,
            None,
            filter,
            duplicate_scope,
            Arc::new(BoundedFingerprintSet::new()),
        )
    }

    #[allow(clippy::too_many_arguments)]
    pub fn with_scope_and_fingerprints(
        topic: String,
        is_compacted: bool,
        scan_reference_time_ms: Option<i64>,
        started_after_low_partitions: HashSet<i32>,
        ended_before_high_partitions: HashSet<i32>,
        time_window: Option<(Option<i64>, Option<i64>)>,
        scan_scope_summary: Option<AnalysisScopeSummary>,
        filter: Option<FieldValueFilter>,
        duplicate_scope: Option<DuplicateDetectionScope>,
        fingerprint_set: Arc<BoundedFingerprintSet>,
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
            cleanup_policy_unknown: false,
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
            started_after_low_partitions,
            ended_before_high_partitions,
            time_window,
            excluded_by_time_range: 0,
            scan_scope_summary,
            filter_accumulator,
            duplicate_scope,
            fingerprint_set,
            duplicate_samples: HashMap::new(),
            duplicate_samples_capped: false,
            field_cap_reached: false,
            depth_limit_reached: false,
            preview_truncated: false,
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
                    latest_timestamp_ms: p_stat.latest_timestamp_ms,
                });
            if p_stat.message_count > 0 {
                if entry.message_count == 0 {
                    entry.earliest_offset = p_stat.earliest_offset;
                    entry.latest_offset = p_stat.latest_offset;
                    entry.earliest_timestamp_ms = p_stat.earliest_timestamp_ms;
                    entry.latest_timestamp_ms = p_stat.latest_timestamp_ms;
                } else {
                    entry.earliest_offset = entry.earliest_offset.min(p_stat.earliest_offset);
                    entry.latest_offset = entry.latest_offset.max(p_stat.latest_offset);
                    if let Some(other_ts) = p_stat.earliest_timestamp_ms {
                        entry.earliest_timestamp_ms = match entry.earliest_timestamp_ms {
                            None => Some(other_ts),
                            Some(prev) => Some(prev.min(other_ts)),
                        };
                    }
                    if let Some(other_ts) = p_stat.latest_timestamp_ms {
                        entry.latest_timestamp_ms = match entry.latest_timestamp_ms {
                            None => Some(other_ts),
                            Some(prev) => Some(prev.max(other_ts)),
                        };
                    }
                }
            }
            entry.message_count += p_stat.message_count;
            entry.byte_size += p_stat.byte_size;
        }

        for (k, count) in &other.key_counts {
            if self.key_counts.len() < MAX_TRACKED_KEYS || self.key_counts.contains_key(k) {
                *self.key_counts.entry(k.clone()).or_insert(0) += count;
            } else {
                self.key_cardinality_capped = true;
            }
        }
        self.key_cardinality_capped |= other.key_cardinality_capped;
        self.field_cap_reached |= other.field_cap_reached;
        self.depth_limit_reached |= other.depth_limit_reached;
        self.preview_truncated |= other.preview_truncated;
        self.excluded_by_time_range += other.excluded_by_time_range;
        self.started_after_low_partitions
            .extend(other.started_after_low_partitions.iter().copied());
        self.ended_before_high_partitions
            .extend(other.ended_before_high_partitions.iter().copied());
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
        self.capped_value_fields
            .extend(other.capped_value_fields.clone());

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

        // Duplicate detection merge (shared BoundedFingerprintSet; samples store extra occurrences)
        for (fp, other_sample) in &other.duplicate_samples {
            if let Some(sample) = self.duplicate_samples.get_mut(fp) {
                sample.count += other_sample.count;
            } else if self.duplicate_samples.len() < MAX_DUPLICATE_SAMPLES {
                self.duplicate_samples.insert(*fp, other_sample.clone());
            } else {
                self.duplicate_samples_capped = true;
            }
        }
        self.duplicate_samples_capped |= other.duplicate_samples_capped;
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
        self.record_message_with_filter_and_local(
            partition,
            offset,
            timestamp_ms,
            key_bytes,
            payload_bytes,
            decoded_key,
            parsed_payload,
            is_sr_encoded,
            compiled_filter,
            None,
        );
    }

    #[allow(clippy::too_many_arguments)]
    pub fn record_message_with_filter_and_local(
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
        value_local_schema: Option<&kafkalyzer_core::kafka_types::LocalSchemaUse>,
    ) {
        if let Some((win_start, win_end)) = self.time_window {
            let out_of_window = timestamp_ms <= 0
                || win_start.is_some_and(|s| timestamp_ms < s)
                || win_end.is_some_and(|e| timestamp_ms >= e);
            if out_of_window {
                self.excluded_by_time_range += 1;
                return;
            }
        }

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
                latest_timestamp_ms: None,
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
            p_stat.latest_timestamp_ms = match p_stat.latest_timestamp_ms {
                None => Some(timestamp_ms),
                Some(prev) => Some(prev.max(timestamp_ms)),
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
                // Bounded tracking up to MAX_TRACKED_KEYS unique keys
                if self.key_counts.len() < MAX_TRACKED_KEYS || self.key_counts.contains_key(k) {
                    *self.key_counts.entry(k.clone()).or_insert(0) += 1;
                } else {
                    self.key_cardinality_capped = true;
                }
            }
        }

        // Duplicate detection (shared BoundedFingerprintSet; samples count extra occurrences)
        let fp = compute_message_fingerprint(self.duplicate_scope, key_bytes, payload_bytes);
        match self.fingerprint_set.insert(fp) {
            FingerprintOutcome::New | FingerprintOutcome::Untracked => {}
            FingerprintOutcome::Seen => {
                if let Some(sample) = self.duplicate_samples.get_mut(&fp) {
                    sample.count += 1;
                } else if self.duplicate_samples.len() < MAX_DUPLICATE_SAMPLES {
                    let (preview, truncated) =
                        extract_duplicate_preview(parsed_payload, payload_bytes, MAX_PREVIEW_CHARS);
                    if truncated {
                        self.preview_truncated = true;
                    }
                    self.duplicate_samples.insert(
                        fp,
                        DuplicateSample {
                            key: key_str.clone(),
                            payload_preview: preview,
                            count: 1,
                            sample_partition: partition,
                            sample_offset: offset,
                            sample_timestamp_ms: timestamp_ms,
                        },
                    );
                } else {
                    self.duplicate_samples_capped = true;
                }
            }
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

        let local_failed = value_local_schema.is_some_and(|u| u.error.is_some());

        // Try parsed payload or parse JSON from raw payload (unless local decode failed)
        let fallback_json;
        let json_ref = if local_failed {
            None
        } else if let Some(val) = parsed_payload {
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

        if local_failed {
            *self
                .content_type_counts
                .entry("Local schema decode failed".to_string())
                .or_insert(0) += 1;
        } else if let Some(json_val) = json_ref {
            let local_label;
            let type_label = if let Some(local_use) = value_local_schema {
                local_label = format!("{} (local schema)", local_use.format.display_kind());
                local_label.as_str()
            } else if is_sr_encoded {
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
                    &mut self.field_cap_reached,
                    &mut self.depth_limit_reached,
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
                                    let in_range = if let Some(ref_ms) = self.scan_reference_time_ms
                                    {
                                        let min_ts = ref_ms - 366 * 24 * 3_600_000;
                                        let max_ts = ref_ms + 24 * 3_600_000;
                                        timestamp_ms >= min_ts && timestamp_ms <= max_ts
                                    } else {
                                        true
                                    };
                                    if in_range {
                                        let epoch_hour = timestamp_ms.div_euclid(3_600_000);
                                        *filter_acc
                                            .matched_timeline
                                            .entry(epoch_hour)
                                            .or_insert(0) += 1;
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
        let part_complete_from = if self.started_after_low_partitions.is_empty() {
            None
        } else {
            self.started_after_low_partitions
                .iter()
                .filter_map(|p| {
                    self.partition_stats
                        .get(p)
                        .filter(|s| s.message_count > 0)
                        .and_then(|s| s.earliest_timestamp_ms)
                })
                .max()
        };
        let complete_from_ms = match (
            part_complete_from,
            self.time_window.and_then(|(start, _)| start),
        ) {
            (Some(a), Some(b)) => Some(a.max(b)),
            (Some(a), None) => Some(a),
            (None, Some(b)) => Some(b),
            (None, None) => None,
        };

        // Coverage end (complete_until_ms)
        let part_complete_until = if self.ended_before_high_partitions.is_empty() {
            None
        } else {
            self.ended_before_high_partitions
                .iter()
                .filter_map(|p| {
                    self.partition_stats
                        .get(p)
                        .filter(|s| s.message_count > 0)
                        .and_then(|s| s.latest_timestamp_ms)
                })
                .min()
        };
        let complete_until_ms = match (
            part_complete_until,
            self.time_window.and_then(|(_, end)| end),
        ) {
            (Some(a), Some(b)) => Some(a.min(b)),
            (Some(a), None) => Some(a),
            (None, Some(b)) => Some(b),
            (None, None) => None,
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
        let tracked = self.fingerprint_set.tracked();
        let untracked = self.fingerprint_set.untracked();
        let unique_msgs = (tracked + untracked).min(total_msgs);
        let duplicate_msgs = (total_msgs - unique_msgs).max(0);
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
            .take(MAX_LISTED_DUPLICATES)
            .map(|s| {
                let occurrences = s.count + 1;
                let percentage = if total_msgs > 0 {
                    (occurrences as f64 / total_msgs as f64) * 100.0
                } else {
                    0.0
                };
                TopDuplicateOccurrence {
                    key: s.key.clone(),
                    payload_preview: s.payload_preview.clone(),
                    count: occurrences,
                    percentage,
                    sample_partition: s.sample_partition,
                    sample_offset: s.sample_offset,
                    sample_timestamp_ms: s.sample_timestamp_ms,
                }
            })
            .collect();

        let fp_limit = self.fingerprint_set.limit();
        let duplicate_analysis_result = Some(DuplicateAnalysisResult {
            scope: self.duplicate_scope,
            total_messages: total_msgs,
            unique_messages: unique_msgs,
            duplicate_messages: duplicate_msgs,
            duplicate_rate,
            top_duplicates,
            estimated: untracked > 0,
            untracked_messages: untracked,
            fingerprint_limit: Some(fp_limit),
            samples_capped: self.duplicate_samples_capped,
        });

        let analysis_limits = vec![
            AnalysisLimit {
                kind: AnalysisLimitKind::TrackedFields,
                limit: MAX_TRACKED_FIELDS as i64,
                reached: self.field_cap_reached,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::ListedFields,
                limit: MAX_REPORTED_FIELDS as i64,
                reached: self.field_counts.len() > MAX_REPORTED_FIELDS,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::ValuesPerField,
                limit: MAX_VALUES_PER_FIELD as i64,
                reached: !self.capped_value_fields.is_empty(),
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::ListedValuesPerField,
                limit: MAX_LISTED_VALUES as i64,
                reached: self
                    .field_value_counts
                    .values()
                    .any(|m| m.len() > MAX_LISTED_VALUES),
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::FieldDepth,
                limit: MAX_FIELD_DEPTH as i64,
                reached: self.depth_limit_reached,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::ValueDisplayChars,
                limit: MAX_VALUE_CHARS as i64,
                reached: self
                    .field_value_truncated
                    .values()
                    .any(|m| m.values().any(|&t| t)),
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::TrackedKeys,
                limit: MAX_TRACKED_KEYS as i64,
                reached: self.key_cardinality_capped,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::ListedKeys,
                limit: MAX_LISTED_KEYS as i64,
                reached: self.key_counts.len() > MAX_LISTED_KEYS,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::SizePercentileSample,
                limit: MAX_SIZE_SAMPLE as i64,
                reached: self.size_sample.estimated(),
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::TrackedFingerprints,
                limit: fp_limit,
                reached: untracked > 0,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::DuplicateSamples,
                limit: MAX_DUPLICATE_SAMPLES as i64,
                reached: self.duplicate_samples_capped,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::ListedDuplicates,
                limit: MAX_LISTED_DUPLICATES as i64,
                reached: self.duplicate_samples.len() > MAX_LISTED_DUPLICATES,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::PreviewChars,
                limit: MAX_PREVIEW_CHARS as i64,
                reached: self.preview_truncated,
            },
            AnalysisLimit {
                kind: AnalysisLimitKind::TimelineWindowDays,
                limit: TIMELINE_PAST_DAYS,
                reached: self.timeline_outside_count > 0,
            },
        ];

        let scan_scope = self
            .scan_scope_summary
            .as_ref()
            .map(|s| AnalysisScopeSummary {
                scope: s.scope.clone(),
                ranges: s.ranges.clone(),
                unreadable: s.unreadable.clone(),
                excluded_by_time_range: self.excluded_by_time_range,
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
            cleanup_policy_unknown: self.cleanup_policy_unknown,
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
            scan_scope,
            analysis_limits: Some(analysis_limits),
            tracked_field_count: Some(self.field_counts.len() as i64),
            complete_until_ms,
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

fn map_offset_for_time_element(offset: Offset, err: Result<(), KafkaError>) -> TimeBound {
    if let Err(code) = err {
        return TimeBound::Failed(code.to_string());
    }
    match offset {
        Offset::Offset(o) => TimeBound::Offset(o),
        Offset::End => TimeBound::AfterEnd,
        other => {
            if other.to_raw() == Some(-1) {
                TimeBound::AfterEnd
            } else {
                TimeBound::Failed(format!("unexpected offset {:?}", other))
            }
        }
    }
}

struct ResolvedScanPlan {
    plan: ScanPlan,
    started_after_low: HashSet<i32>,
    ended_before_high: HashSet<i32>,
}

fn resolve_scan_plan(
    profile: &ClusterProfile,
    consumer: Option<&BaseConsumer>,
    topic: &str,
    scope: &AnalysisScope,
) -> Result<ResolvedScanPlan> {
    scope.validate().map_err(|e| anyhow::anyhow!(e))?;

    let watermarks = crate::kafka_metadata::fetch_partition_offsets(profile, topic)?;

    if let Some(requested) = &scope.partitions {
        let available: HashSet<i32> = watermarks
            .partitions
            .iter()
            .map(|pw| pw.partition)
            .collect();
        for &p in requested {
            if !available.contains(&p) {
                anyhow::bail!("Partition {} does not exist in topic '{}'", p, topic);
            }
        }
    }

    let selected_filter: Option<HashSet<i32>> = scope
        .partitions
        .as_ref()
        .map(|p| p.iter().copied().collect());

    let mut known_partitions: Vec<i32> = Vec::new();
    let mut watermark_map: HashMap<i32, (i64, i64)> = HashMap::new();
    for pw in &watermarks.partitions {
        if let WatermarkRead::Known { low, high } = pw.read {
            watermark_map.insert(pw.partition, (low, high));
            if selected_filter
                .as_ref()
                .is_none_or(|set| set.contains(&pw.partition))
            {
                known_partitions.push(pw.partition);
            }
        }
    }

    let mut time_bounds: HashMap<i32, TimeBounds> = HashMap::new();
    let has_time_bound = scope.start_timestamp_ms.is_some() || scope.end_timestamp_ms.is_some();

    if has_time_bound && !known_partitions.is_empty() {
        let consumer = consumer.ok_or_else(|| {
            anyhow::anyhow!(
                "Kafka consumer required to resolve time range for '{}'",
                topic
            )
        })?;
        let oft_timeout = Duration::from_secs(10);

        if let Some(start_ts) = scope.start_timestamp_ms {
            let mut tpl = TopicPartitionList::new();
            for &p in &known_partitions {
                tpl.add_partition_offset(topic, p, Offset::from_raw(start_ts))?;
            }
            let resolved = consumer.offsets_for_times(tpl, oft_timeout).map_err(|e| {
                anyhow::anyhow!(
                    "Failed to resolve start time range for topic '{}': {}",
                    topic,
                    e
                )
            })?;
            for elem in resolved.elements() {
                let bound = map_offset_for_time_element(elem.offset(), elem.error());
                time_bounds.entry(elem.partition()).or_default().start = Some(bound);
            }
        }

        if let Some(end_ts) = scope.end_timestamp_ms {
            let mut tpl = TopicPartitionList::new();
            for &p in &known_partitions {
                tpl.add_partition_offset(topic, p, Offset::from_raw(end_ts))?;
            }
            let resolved = consumer.offsets_for_times(tpl, oft_timeout).map_err(|e| {
                anyhow::anyhow!(
                    "Failed to resolve end time range for topic '{}': {}",
                    topic,
                    e
                )
            })?;
            for elem in resolved.elements() {
                let bound = map_offset_for_time_element(elem.offset(), elem.error());
                time_bounds.entry(elem.partition()).or_default().end = Some(bound);
            }
        }
    }

    let plan = plan_scan(&watermarks.partitions, &time_bounds, scope);

    let mut started_after_low = HashSet::new();
    let mut ended_before_high = HashSet::new();
    for r in &plan.ranges {
        if let Some(&(low, high)) = watermark_map.get(&r.partition) {
            if r.start > low {
                started_after_low.insert(r.partition);
            }
            if r.end < high {
                ended_before_high.insert(r.partition);
            }
        }
    }

    Ok(ResolvedScanPlan {
        plan,
        started_after_low,
        ended_before_high,
    })
}

pub fn estimate_analysis_scope(
    profile: ClusterProfile,
    topic: String,
    scope: AnalysisScope,
) -> Result<AnalysisScopeEstimate> {
    scope.validate().map_err(|e| anyhow::anyhow!(e))?;

    let needs_consumer = scope.start_timestamp_ms.is_some() || scope.end_timestamp_ms.is_some();
    let consumer = if needs_consumer {
        let mut config = create_config(&profile);
        config.set("enable.auto.commit", "false");
        config.set("enable.auto.offset.store", "false");
        Some(config.create::<BaseConsumer>()?)
    } else {
        None
    };

    let resolved = resolve_scan_plan(&profile, consumer.as_ref(), &topic, &scope)?;
    let plan = resolved.plan;
    Ok(AnalysisScopeEstimate {
        planned_total: if plan.complete {
            Some(plan.planned_total)
        } else {
            None
        },
        known_total: plan.planned_total,
        complete: plan.complete,
        unreadable: plan.unreadable,
    })
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

    let effective_scope = options.effective_scope();
    if let Err(err_msg) = effective_scope.validate() {
        let progress = TopicAnalysisProgress {
            scanned_messages: 0,
            total_messages_to_scan: 0,
            progress: 1.0,
            messages_per_second: 0.0,
            current_partition: -1,
            is_complete: true,
            error_message: Some(err_msg),
            partial_report: None,
        };
        sink.add(progress).ok();
        return Ok(());
    }

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
    let loaded_local = std::sync::Arc::new(crate::local_schema_loader::load_topic_local_schemas(
        options.local_schemas.as_ref(),
    ));

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

    // 3. Fetch cleanup policy & resolve scan plan before assign
    let (is_compacted, cleanup_policy_unknown) =
        match crate::kafka_metadata::describe_topic_configs(profile.clone(), vec![topic.clone()]) {
            Ok(results) => results
                .into_iter()
                .next()
                .map(|r| resolve_cleanup_policy(&topic, &r.outcome))
                .unwrap_or_else(|| {
                    log::warn!("cleanup.policy for topic '{topic}' unavailable: empty result");
                    (false, true)
                }),
            Err(err) => {
                log::warn!("cleanup.policy lookup failed for topic '{topic}': {err}");
                (false, true)
            }
        };

    let resolved_plan = match resolve_scan_plan(&profile, Some(&consumer), &topic, &effective_scope)
    {
        Ok(p) => p,
        Err(err) => {
            let progress = TopicAnalysisProgress {
                scanned_messages: 0,
                total_messages_to_scan: 0,
                progress: 1.0,
                messages_per_second: 0.0,
                current_partition: -1,
                is_complete: true,
                error_message: Some(err.to_string()),
                partial_report: None,
            };
            sink.add(progress).ok();
            return Ok(());
        }
    };

    let plan = resolved_plan.plan;
    if plan.ranges.is_empty() && !plan.unreadable.is_empty() {
        let details: Vec<String> = plan
            .unreadable
            .iter()
            .map(|u| format!("partition {}: {}", u.partition, u.reason))
            .collect();
        let progress = TopicAnalysisProgress {
            scanned_messages: 0,
            total_messages_to_scan: 0,
            progress: 1.0,
            messages_per_second: 0.0,
            current_partition: -1,
            is_complete: true,
            error_message: Some(format!("No partition readable ({})", details.join("; "))),
            partial_report: None,
        };
        sink.add(progress).ok();
        return Ok(());
    }

    let mut tpl = TopicPartitionList::new();
    let total_messages_to_scan: i64 = plan.planned_total;
    for r in &plan.ranges {
        if r.start < r.end {
            tpl.add_partition_offset(&topic, r.partition, Offset::Offset(r.start))?;
        }
    }

    let time_window = if effective_scope.start_timestamp_ms.is_some()
        || effective_scope.end_timestamp_ms.is_some()
    {
        Some((
            effective_scope.start_timestamp_ms,
            effective_scope.end_timestamp_ms,
        ))
    } else {
        None
    };

    let scan_scope_summary = Some(AnalysisScopeSummary {
        scope: effective_scope.clone(),
        ranges: plan.ranges.clone(),
        unreadable: plan.unreadable.clone(),
        excluded_by_time_range: 0,
    });

    let shared_fingerprints = Arc::new(BoundedFingerprintSet::new());

    let mut accumulator = AnalyzerAccumulator::with_scope_and_fingerprints(
        topic.clone(),
        is_compacted,
        Some(scan_reference_time_ms),
        resolved_plan.started_after_low.clone(),
        resolved_plan.ended_before_high.clone(),
        time_window,
        scan_scope_summary.clone(),
        options.value_filter.clone(),
        options.duplicate_scope,
        Arc::clone(&shared_fingerprints),
    );
    accumulator.cleanup_policy_unknown = cleanup_policy_unknown;

    // Pre-populate partition stats for planned partitions only
    for r in &plan.ranges {
        accumulator.partition_stats.insert(
            r.partition,
            PartitionStatsAccumulator {
                message_count: 0,
                byte_size: 0,
                earliest_offset: r.start,
                latest_offset: r.start,
                earliest_timestamp_ms: None,
                latest_timestamp_ms: None,
            },
        );
    }

    if total_messages_to_scan == 0 || tpl.count() == 0 {
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

    // Assign planned partitions
    let consumer = Arc::new(consumer);
    consumer.assign(&tpl)?;

    // Split partition queues so planned partitions can be read concurrently in parallel
    let mut active_partition_queues = Vec::new();
    for r in &plan.ranges {
        if r.start < r.end {
            if let Some(queue) = consumer.split_partition_queue(&topic, r.partition) {
                active_partition_queues.push((r.partition, queue, r.start, r.end));
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
    type WorkerTask = (
        i32,
        rdkafka::consumer::base_consumer::PartitionQueue<rdkafka::consumer::DefaultConsumerContext>,
        i64,
        i64,
    );
    let mut worker_tasks: Vec<Vec<WorkerTask>> = (0..num_workers).map(|_| Vec::new()).collect();
    for (i, item) in active_partition_queues.into_iter().enumerate() {
        worker_tasks[i % num_workers].push(item);
    }

    let worker_accumulators: Vec<Arc<std::sync::Mutex<AnalyzerAccumulator>>> = (0..num_workers)
        .map(|_| {
            let mut acc = AnalyzerAccumulator::with_scope_and_fingerprints(
                topic.clone(),
                is_compacted,
                Some(scan_reference_time_ms),
                resolved_plan.started_after_low.clone(),
                resolved_plan.ended_before_high.clone(),
                time_window,
                scan_scope_summary.clone(),
                options.value_filter.clone(),
                options.duplicate_scope,
                Arc::clone(&shared_fingerprints),
            );
            acc.cleanup_policy_unknown = cleanup_policy_unknown;
            Arc::new(std::sync::Mutex::new(acc))
        })
        .collect();

    let active_workers = Arc::new(std::sync::atomic::AtomicUsize::new(num_workers));
    let scan_start = Instant::now();
    let mut main_acc = AnalyzerAccumulator::with_scope_and_fingerprints(
        topic.clone(),
        is_compacted,
        Some(scan_reference_time_ms),
        resolved_plan.started_after_low,
        resolved_plan.ended_before_high,
        time_window,
        scan_scope_summary,
        options.value_filter,
        options.duplicate_scope,
        Arc::clone(&shared_fingerprints),
    );
    main_acc.cleanup_policy_unknown = cleanup_policy_unknown;

    let end_offsets: HashMap<i32, i64> = plan.ranges.iter().map(|r| (r.partition, r.end)).collect();
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
            let loaded_local = Arc::clone(&loaded_local);

            s.spawn(move || {
                let mut local_acc = w_acc_arc.lock().unwrap().clone();
                let mut last_sync = Instant::now();

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

                                decode_and_record_for_analysis(
                                    &mut local_acc,
                                    *p_id,
                                    off,
                                    ts_ms,
                                    key,
                                    payload,
                                    tokio_runtime,
                                    decoders,
                                    key_is_avro,
                                    value_is_avro,
                                    &loaded_local,
                                    compiled_filter,
                                );

                                if off + 1 >= *end_off {
                                    break;
                                }

                                if last_sync.elapsed() >= Duration::from_millis(250) {
                                    if let Ok(mut shared) = w_acc_arc.lock() {
                                        *shared = local_acc.clone();
                                    }
                                    last_sync = Instant::now();
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

                                        decode_and_record_for_analysis(
                                            &mut local_acc,
                                            *p_id,
                                            off,
                                            ts_ms,
                                            key,
                                            payload,
                                            tokio_runtime,
                                            decoders,
                                            key_is_avro,
                                            value_is_avro,
                                            &loaded_local,
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

                        if last_sync.elapsed() >= Duration::from_millis(250) {
                            if let Ok(mut shared) = w_acc_arc.lock() {
                                *shared = local_acc.clone();
                            }
                            last_sync = Instant::now();
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
                    decode_and_record_for_analysis(
                        &mut main_acc,
                        p,
                        off,
                        ts_ms,
                        key,
                        payload,
                        tokio_runtime,
                        &decoders,
                        key_is_avro,
                        value_is_avro,
                        &loaded_local,
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
            scope: None,
            local_schemas: None,
        },
        sink,
        cancel_flag,
    )
}

pub(crate) fn resolve_cleanup_policy(
    topic: &str,
    outcome: &crate::kafka_metadata::TopicConfigOutcome,
) -> (bool, bool) {
    match outcome {
        crate::kafka_metadata::TopicConfigOutcome::Available(entries) => {
            if let Some(entry) = entries.iter().find(|e| e.name == "cleanup.policy") {
                if let Some(val) = &entry.value {
                    return (val.contains("compact"), false);
                }
            }
            log::warn!("cleanup.policy for topic '{topic}' missing from available config entries");
            (false, true)
        }
        crate::kafka_metadata::TopicConfigOutcome::NotReadable(reason)
        | crate::kafka_metadata::TopicConfigOutcome::Failed(reason) => {
            log::warn!("cleanup.policy for topic '{topic}' unavailable: {reason}");
            (false, true)
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn decode_and_record_for_analysis<'a>(
    acc: &mut AnalyzerAccumulator,
    partition: i32,
    offset: i64,
    timestamp_ms: i64,
    key: Option<&[u8]>,
    payload: Option<&[u8]>,
    tokio_runtime: &tokio::runtime::Runtime,
    decoders: &Option<crate::kafka_consumer::SrDecoders<'a>>,
    key_is_avro: bool,
    value_is_avro: bool,
    loaded_local: &crate::local_schema_loader::LoadedTopicLocalSchemas,
    compiled_filter: Option<&CompiledValueFilter>,
) {
    let is_sr_encoded = payload.is_some_and(|b| b.len() >= 5 && b[0] == 0);
    let val_side = if value_is_avro || is_sr_encoded || loaded_local.value.is_some() {
        Some(crate::kafka_consumer::decode_side(
            tokio_runtime,
            decoders,
            payload,
            value_is_avro || is_sr_encoded,
            "",
            loaded_local.value.as_ref(),
        ))
    } else {
        None
    };
    let parsed_payload = val_side.as_ref().and_then(|s| s.component.json.as_ref());
    let value_local_schema = val_side.as_ref().and_then(|s| s.local_schema.as_ref());

    let decoded_key = if key_is_avro || loaded_local.key.is_some() {
        crate::kafka_consumer::decode_side(
            tokio_runtime,
            decoders,
            key,
            key_is_avro,
            "",
            loaded_local.key.as_ref(),
        )
        .component
        .text
    } else {
        None
    };

    acc.record_message_with_filter_and_local(
        partition,
        offset,
        timestamp_ms,
        key,
        payload,
        decoded_key.as_deref(),
        parsed_payload,
        is_sr_encoded,
        compiled_filter,
        value_local_schema,
    );
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
        assert!(report.is_compacted);
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
        acc1.record_message(
            0,
            5,
            ts_day2 + 100_000_000,
            None,
            Some(b"{}"),
            None,
            None,
            false,
        );
        // Timestamp < ref - 366 days
        acc1.record_message(
            0,
            6,
            ts_day2 - 32_000_000_000,
            None,
            Some(b"{}"),
            None,
            None,
            false,
        );

        acc1.merge(&acc2);

        let report = acc1.to_report(10);
        assert_eq!(report.total_messages, 6);
        assert_eq!(report.timeline_outside_count, 2);

        // Hourly distribution (24h UTC) folds both days into hour 14
        let h14 = report
            .hourly_distribution
            .iter()
            .find(|h| h.hour == 14)
            .unwrap();
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

        acc.record_message(0, 0, 1000, None, None, None, Some(&deep_json), false);

        let report = acc.to_report(5);
        let names: Vec<&str> = report
            .field_frequencies
            .iter()
            .map(|f| f.field_name.as_str())
            .collect();
        assert!(names.contains(&"order"));
        assert!(names.contains(&"order.id"));
        assert!(names.contains(&"attributes.region"));
        assert!(names.contains(&"/labels/app.kubernetes.io~1name"));
        assert!(names.contains(&"items"));
        assert!(names.contains(&"order.nested.l3.l4.l5"));
        assert!(
            !names.contains(&"order.nested.l3.l4.l5.l6_hidden"),
            "Depth > 5 should not be descended"
        );

        // Test multi-byte string > 80 chars truncation
        let long_str = "äöü-".repeat(25); // 100 chars, multibyte
        assert!(long_str.chars().count() > 80);
        let long_payload = serde_json::json!({
            "desc": long_str
        });
        acc.record_message(0, 1, 1000, None, None, None, Some(&long_payload), false);
        let report2 = acc.to_report(5);
        let desc_field = report2
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "desc")
            .unwrap();
        assert!(desc_field.top_values[0].truncated);
        assert!(desc_field.top_values[0].value.ends_with("..."));

        // Test capped field (more than 200 distinct values)
        for i in 0..210 {
            let p = serde_json::json!({ "many_vals": format!("val_{}", i) });
            acc.record_message(0, 2 + i, 1000, None, None, None, Some(&p), false);
        }
        let report3 = acc.to_report(5);
        let mv_field = report3
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "many_vals")
            .unwrap();
        assert!(mv_field.values_capped);
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
        acc1.record_message_with_filter(
            0,
            0,
            3_600_000,
            None,
            None,
            None,
            Some(&p_match),
            false,
            Some(&compiled),
        );

        // 2. Case mismatch: attributes.region = "eu"
        let p_case = serde_json::json!({ "attributes": { "region": "eu" } });
        acc1.record_message_with_filter(
            0,
            1,
            3_600_000,
            None,
            None,
            None,
            Some(&p_case),
            false,
            Some(&compiled),
        );

        // 3. Different value: attributes.region = "US"
        let p_us = serde_json::json!({ "attributes": { "region": "US" } });
        acc2.record_message_with_filter(
            0,
            2,
            7_200_000,
            None,
            None,
            None,
            Some(&p_us),
            false,
            Some(&compiled),
        );

        // 4. Absent field
        let p_other = serde_json::json!({ "status": "OK" });
        acc2.record_message_with_filter(
            0,
            3,
            7_200_000,
            None,
            None,
            None,
            Some(&p_other),
            false,
            Some(&compiled),
        );

        // 5. Tombstone
        acc2.record_message_with_filter(
            0,
            4,
            7_200_000,
            None,
            None,
            None,
            None,
            false,
            Some(&compiled),
        );

        // 6. Non-JSON text
        acc2.record_message_with_filter(
            0,
            5,
            7_200_000,
            None,
            Some(b"non-json-plain-text"),
            None,
            None,
            false,
            Some(&compiled),
        );

        acc1.merge(&acc2);

        let report = acc1.to_report(10);
        let res = report
            .value_filter_result
            .expect("Value filter result should be present");
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
        acc_null.record_message_with_filter(
            0,
            0,
            1000,
            None,
            None,
            None,
            Some(&p_null),
            false,
            Some(&null_compiled),
        );
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
        acc.record_message(
            0,
            0,
            1000,
            Some(b"k1"),
            Some(b"{\"id\":100}"),
            None,
            None,
            false,
        );
        // Msg 2: Key "k2", payload A (Duplicate under PayloadOnly!)
        acc.record_message(
            0,
            1,
            2000,
            Some(b"k2"),
            Some(b"{\"id\":100}"),
            None,
            None,
            false,
        );
        // Msg 3: Key None, payload A (Duplicate under PayloadOnly!)
        acc.record_message(0, 2, 3000, None, Some(b"{\"id\":100}"), None, None, false);
        // Msg 4: Key "k1", payload B (Unique)
        acc.record_message(
            0,
            3,
            4000,
            Some(b"k1"),
            Some(b"{\"id\":200}"),
            None,
            None,
            false,
        );

        let report = acc.to_report(10);
        assert_eq!(report.total_messages, 4);

        let dup_res = report
            .duplicate_analysis_result
            .expect("duplicate result present");
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
        acc.record_message(
            0,
            0,
            1000,
            Some(b"k1"),
            Some(b"{\"id\":100}"),
            None,
            None,
            false,
        );
        // Msg 2: Key "k2", payload A (NOT duplicate under KeyAndPayload)
        acc.record_message(
            0,
            1,
            2000,
            Some(b"k2"),
            Some(b"{\"id\":100}"),
            None,
            None,
            false,
        );
        // Msg 3: Key "k1", payload A (Duplicate under KeyAndPayload)
        acc.record_message(
            0,
            2,
            3000,
            Some(b"k1"),
            Some(b"{\"id\":100}"),
            None,
            None,
            false,
        );

        let report = acc.to_report(10);
        assert_eq!(report.total_messages, 3);

        let dup_res = report
            .duplicate_analysis_result
            .expect("duplicate result present");
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
        let shared = Arc::new(BoundedFingerprintSet::new());
        let mut acc1 = AnalyzerAccumulator::with_scope_and_fingerprints(
            "dup-test".into(),
            false,
            Some(100_000),
            HashSet::new(),
            HashSet::new(),
            None,
            None,
            None,
            Some(DuplicateDetectionScope::PayloadOnly),
            Arc::clone(&shared),
        );
        let mut acc2 = AnalyzerAccumulator::with_scope_and_fingerprints(
            "dup-test".into(),
            false,
            Some(100_000),
            HashSet::new(),
            HashSet::new(),
            None,
            None,
            None,
            Some(DuplicateDetectionScope::PayloadOnly),
            Arc::clone(&shared),
        );

        // Worker 1 receives payload X
        acc1.record_message(
            0,
            0,
            1000,
            Some(b"k1"),
            Some(b"payload-X"),
            None,
            None,
            false,
        );
        // Worker 2 receives payload X
        acc2.record_message(
            1,
            0,
            2000,
            Some(b"k2"),
            Some(b"payload-X"),
            None,
            None,
            false,
        );

        acc1.merge(&acc2);

        let report = acc1.to_report(10);
        assert_eq!(report.total_messages, 2);
        let dup_res = report
            .duplicate_analysis_result
            .expect("duplicate result present");
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
        let dup_res = report
            .duplicate_analysis_result
            .expect("duplicate result present");
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
            avro_dup
                .payload_preview
                .contains("\"COR_ID\":\"COR-12345\""),
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

    #[test]
    fn resolve_cleanup_policy_marks_not_readable_as_unknown_and_compact_delete_as_compacted() {
        use crate::kafka_metadata::{TopicConfigEntry, TopicConfigOutcome, TopicConfigSource};

        let not_readable = TopicConfigOutcome::NotReadable("denied".to_string());
        let (is_compacted, unknown) = resolve_cleanup_policy("orders", &not_readable);
        assert!(!is_compacted);
        assert!(unknown);

        let compacted = TopicConfigOutcome::Available(vec![TopicConfigEntry {
            name: "cleanup.policy".to_string(),
            value: Some("compact,delete".to_string()),
            source: TopicConfigSource::DynamicTopic,
            is_default: false,
            is_sensitive: false,
            is_read_only: false,
        }]);
        let (is_compacted, unknown) = resolve_cleanup_policy("orders", &compacted);
        assert!(is_compacted);
        assert!(!unknown);
    }

    #[test]
    fn map_offset_for_time_element_handles_offset_end_raw_and_error() {
        assert_eq!(
            map_offset_for_time_element(Offset::Offset(42), Ok(())),
            TimeBound::Offset(42)
        );
        assert_eq!(
            map_offset_for_time_element(Offset::End, Ok(())),
            TimeBound::AfterEnd
        );
        assert_eq!(
            map_offset_for_time_element(Offset::from_raw(-1), Ok(())),
            TimeBound::AfterEnd
        );
        assert!(matches!(
            map_offset_for_time_element(
                Offset::Invalid,
                Err(KafkaError::MetadataFetch(
                    rdkafka::error::RDKafkaErrorCode::UnknownTopicOrPartition
                ))
            ),
            TimeBound::Failed(_)
        ));
    }

    #[test]
    fn time_window_excludes_outside_and_invalid_timestamps_and_tracks_coverage_end() {
        let mut acc = AnalyzerAccumulator::with_scope_and_fingerprints(
            "t".into(),
            false,
            Some(10_000),
            HashSet::new(),
            [0].into_iter().collect(),
            Some((Some(2_000), Some(5_000))),
            Some(AnalysisScopeSummary {
                scope: AnalysisScope {
                    start_timestamp_ms: Some(2_000),
                    end_timestamp_ms: Some(5_000),
                    ..Default::default()
                },
                ranges: vec![],
                unreadable: vec![],
                excluded_by_time_range: 0,
            }),
            None,
            None,
            Arc::new(BoundedFingerprintSet::new()),
        );
        acc.record_message(0, 0, 1_999, None, Some(b"{\"a\":1}"), None, None, false);
        acc.record_message(0, 1, 0, None, Some(b"{\"a\":2}"), None, None, false);
        acc.record_message(0, 2, -5, None, Some(b"{\"a\":3}"), None, None, false);
        acc.record_message(0, 3, 5_000, None, Some(b"{\"a\":4}"), None, None, false);
        acc.record_message(0, 4, 3_000, None, Some(b"{\"a\":5}"), None, None, false);
        acc.record_message(0, 5, 4_000, None, Some(b"{\"a\":6}"), None, None, false);

        let report = acc.to_report(5);
        assert_eq!(report.total_messages, 2);
        assert_eq!(report.complete_from_ms, Some(2_000));
        assert_eq!(report.complete_until_ms, Some(4_000));
        assert_eq!(report.scan_scope.unwrap().excluded_by_time_range, 4);
    }

    #[test]
    fn bounded_duplicate_tracking_exact_and_overflow_and_sample_cap() {
        // 10,000 messages with 8,500 unique (500 duplicated 3 extra times = 1,500 dups) -> 15.0%
        let mut acc = AnalyzerAccumulator::new("dup-10k".into(), false);
        for i in 0..8_500 {
            let p = format!("payload-{i}");
            acc.record_message(0, i, 1000, None, Some(p.as_bytes()), None, None, false);
        }
        for round in 0..3 {
            for i in 0..500 {
                let p = format!("payload-{i}");
                acc.record_message(
                    0,
                    8_500 + round * 500 + i,
                    1000,
                    None,
                    Some(p.as_bytes()),
                    None,
                    None,
                    false,
                );
            }
        }
        let rep = acc.to_report(10);
        let dup = rep.duplicate_analysis_result.unwrap();
        assert_eq!(dup.total_messages, 10_000);
        assert_eq!(dup.unique_messages, 8_500);
        assert_eq!(dup.duplicate_messages, 1_500);
        assert!((dup.duplicate_rate - 15.0).abs() < 1e-6);
        assert!(!dup.estimated);
        assert_eq!(dup.untracked_messages, 0);
        assert!(!dup.samples_capped);

        // Small-cap set overflow -> estimated = true, untracked > 0, duplicates >= 0
        let small_set = Arc::new(BoundedFingerprintSet::with_per_shard_cap(2));
        let mut acc_small = AnalyzerAccumulator::with_scope_and_fingerprints(
            "dup-small".into(),
            false,
            None,
            HashSet::new(),
            HashSet::new(),
            None,
            None,
            None,
            None,
            small_set,
        );
        for i in 0..200 {
            let p = format!("unique-{i}");
            acc_small.record_message(0, i, 1000, None, Some(p.as_bytes()), None, None, false);
        }
        let rep_small = acc_small.to_report(5);
        let dup_small = rep_small.duplicate_analysis_result.unwrap();
        assert!(dup_small.estimated);
        assert!(dup_small.untracked_messages > 0);
        assert!(dup_small.duplicate_messages >= 0);

        // Sample table overflow -> samples_capped = true
        let mut acc_samples = AnalyzerAccumulator::new("dup-samples".into(), false);
        for i in 0..1_005 {
            let p = format!("dup-{i}");
            acc_samples.record_message(0, i * 2, 1000, None, Some(p.as_bytes()), None, None, false);
            acc_samples.record_message(
                0,
                i * 2 + 1,
                1000,
                None,
                Some(p.as_bytes()),
                None,
                None,
                false,
            );
        }
        let rep_samples = acc_samples.to_report(5);
        assert!(
            rep_samples
                .duplicate_analysis_result
                .unwrap()
                .samples_capped
        );
    }

    #[test]
    fn analysis_limits_track_fields_depth_and_emit_all_kinds_once() {
        let mut acc = AnalyzerAccumulator::new("limits".into(), false);
        // 501 distinct fields -> field cap reached, tracked_field_count = 500
        let mut obj = serde_json::Map::new();
        for i in 0..501 {
            obj.insert(format!("f{i}"), Value::from(i));
        }
        let val_501 = Value::Object(obj);
        acc.record_message(0, 0, 1000, None, Some(b"{}"), None, Some(&val_501), false);
        let rep = acc.to_report(5);
        assert_eq!(rep.tracked_field_count, Some(500));
        let limits = rep.analysis_limits.unwrap();
        assert_eq!(limits.len(), 14);
        let kinds: HashSet<AnalysisLimitKind> = limits.iter().map(|l| l.kind).collect();
        assert_eq!(kinds.len(), 14);
        assert!(
            limits
                .iter()
                .find(|l| l.kind == AnalysisLimitKind::TrackedFields)
                .unwrap()
                .reached
        );

        // 5-level payload -> depth limit NOT reached
        let mut acc5 = AnalyzerAccumulator::new("depth5".into(), false);
        let v5 = serde_json::json!({"a": {"b": {"c": {"d": {"e": 1}}}}});
        acc5.record_message(0, 0, 1000, None, Some(b"{}"), None, Some(&v5), false);
        assert!(
            !acc5
                .to_report(5)
                .analysis_limits
                .unwrap()
                .iter()
                .find(|l| l.kind == AnalysisLimitKind::FieldDepth)
                .unwrap()
                .reached
        );

        // 6-level payload -> depth limit reached
        let mut acc6 = AnalyzerAccumulator::new("depth6".into(), false);
        let v6 = serde_json::json!({"a": {"b": {"c": {"d": {"e": {"f": 1}}}}}});
        acc6.record_message(0, 0, 1000, None, Some(b"{}"), None, Some(&v6), false);
        assert!(
            acc6.to_report(5)
                .analysis_limits
                .unwrap()
                .iter()
                .find(|l| l.kind == AnalysisLimitKind::FieldDepth)
                .unwrap()
                .reached
        );
    }

    #[test]
    fn accumulator_records_local_avro_fields_and_decode_failures() {
        use crate::local_schema_loader::{LoadedTopicLocalSchemas, SideLocalSchema};
        use kafkalyzer_core::local_schema::{load_local_schema, Framing, LocalSchemaFormat};

        let avro_schema =
            r#"{"type":"record","name":"Order","fields":[{"name":"status","type":"string"}]}"#;
        let schema = apache_avro::Schema::parse_str(avro_schema).unwrap();
        let datum = apache_avro::to_avro_datum(
            &schema,
            apache_avro::types::Value::Record(vec![(
                "status".to_string(),
                apache_avro::types::Value::String("PAID".to_string()),
            )]),
        )
        .unwrap();

        let loaded = std::sync::Arc::new(
            load_local_schema(
                "orders.avsc",
                avro_schema.as_bytes(),
                LocalSchemaFormat::Avro,
                None,
                Framing::Auto,
            )
            .unwrap(),
        );
        let local = LoadedTopicLocalSchemas {
            key: None,
            value: Some(SideLocalSchema::Loaded {
                schema: loaded,
                mode: kafkalyzer_core::kafka_types::LocalSchemaMode::Fallback,
            }),
        };

        let mut acc = AnalyzerAccumulator::new("orders".to_string(), false);
        let rt = crate::kafka_consumer::shared_runtime();
        decode_and_record_for_analysis(
            &mut acc,
            0,
            0,
            1000,
            None,
            Some(&datum),
            rt,
            &None,
            false,
            false,
            &local,
            None,
        );
        decode_and_record_for_analysis(
            &mut acc,
            0,
            1,
            1001,
            None,
            Some(&[0xff, 0x00, 0xfe]),
            rt,
            &None,
            false,
            false,
            &local,
            None,
        );

        let report = acc.to_report(5);
        let avro_local = report
            .content_type_distribution
            .iter()
            .find(|t| t.type_name == "Avro (local schema)")
            .unwrap();
        assert_eq!(avro_local.count, 1);
        let failed_local = report
            .content_type_distribution
            .iter()
            .find(|t| t.type_name == "Local schema decode failed")
            .unwrap();
        assert_eq!(failed_local.count, 1);
        let status_field = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "status")
            .unwrap();
        assert_eq!(status_field.count, 1);
        assert_eq!(status_field.top_values[0].value, "PAID");
    }
}
