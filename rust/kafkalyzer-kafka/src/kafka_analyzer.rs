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
use std::time::{Duration, Instant};
use tokio::runtime::Runtime;

use crate::kafka_consumer::StreamSink;
use crate::kafka_utils::create_config;

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

    pub fn record_message(
        &mut self,
        partition: i32,
        offset: i64,
        timestamp_ms: i64,
        key_bytes: Option<&[u8]>,
        payload_bytes: Option<&[u8]>,
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
        match key_bytes {
            None => {
                self.null_keys_count += 1;
            }
            Some(bytes) => {
                if bytes.is_empty() {
                    self.null_keys_count += 1;
                } else {
                    let key_str = match std::str::from_utf8(bytes) {
                        Ok(s) => s.to_string(),
                        Err(_) => format!("[Binary 0x{}]", hex_preview(bytes)),
                    };
                    // Bounded tracking up to 10,000 unique keys
                    if self.key_counts.len() < 10000 || self.key_counts.contains_key(&key_str) {
                        *self.key_counts.entry(key_str).or_insert(0) += 1;
                    }
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

        let Some(payload) = payload_bytes else {
            return;
        };

        // Check for Confluent / Schema Registry magic byte 0
        if payload.len() > 5 && payload[0] == 0 {
            *self
                .content_type_counts
                .entry("Schema Registry (Avro/Proto)".to_string())
                .or_insert(0) += 1;
            return;
        }

        // Try JSON parsing
        if let Ok(json_val) = serde_json::from_slice::<Value>(payload) {
            *self
                .content_type_counts
                .entry("JSON".to_string())
                .or_insert(0) += 1;
            if let Value::Object(map) = json_val {
                for (field_name, field_val) in map {
                    // Record field occurrence
                    if self.field_counts.len() < 500 || self.field_counts.contains_key(&field_name)
                    {
                        *self.field_counts.entry(field_name.clone()).or_insert(0) += 1;
                    }

                    // For categorical / small identifying fields, track top values
                    if is_categorical_field(&field_name) {
                        let val_str = match field_val {
                            Value::String(s) => {
                                if s.len() <= 60 {
                                    Some(s)
                                } else {
                                    Some(format!("{}...", &s[..57]))
                                }
                            }
                            Value::Number(n) => Some(n.to_string()),
                            Value::Bool(b) => Some(b.to_string()),
                            _ => None,
                        };

                        if let Some(v_str) = val_str {
                            let val_map = self.field_value_counts.entry(field_name).or_default();
                            if val_map.len() < 100 || val_map.contains_key(&v_str) {
                                *val_map.entry(v_str).or_insert(0) += 1;
                            }
                        }
                    }
                }
            }
        } else if std::str::from_utf8(payload).is_ok() {
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

        // Field Frequencies & Top Values (Top 25 fields)
        let mut fields_vec: Vec<(String, i64)> = self
            .field_counts
            .iter()
            .map(|(k, v)| (k.clone(), *v))
            .collect();
        fields_vec.sort_by(|a, b| b.1.cmp(&a.1));
        fields_vec.truncate(25);

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
                    val_vec.truncate(5);

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

fn is_categorical_field(name: &str) -> bool {
    let lower = name.to_lowercase();
    lower.contains("type")
        || lower.contains("status")
        || lower.contains("event")
        || lower.contains("action")
        || lower.contains("category")
        || lower.contains("state")
        || lower.contains("kind")
        || lower.contains("level")
        || lower.contains("code")
        || lower.contains("gender")
        || lower.contains("role")
        || lower.contains("version")
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
    let config = create_config(&profile);
    let consumer: BaseConsumer = config.create()?;

    // 1. Fetch metadata and check cleanup policy
    let timeout = Duration::from_secs(10);
    let metadata = consumer.fetch_metadata(Some(&topic), timeout)?;

    let mut is_compacted = false;
    let rt = Runtime::new().ok();
    if let Some(ref rt_handle) = rt {
        if let Ok(admin_client) = config.create::<AdminClient<DefaultClientContext>>() {
            let resource = ResourceSpecifier::Topic(&topic);
            let admin_options = AdminOptions::new().operation_timeout(Some(Duration::from_secs(5)));
            if let Ok(configs) =
                rt_handle.block_on(admin_client.describe_configs(&[resource], &admin_options))
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
    }

    let mut accumulator = AnalyzerAccumulator::new(topic.clone(), is_compacted);

    // 2. Setup topic partition list and calculate high watermarks
    let mut tpl = TopicPartitionList::new();
    let topic_meta = metadata
        .topics()
        .iter()
        .find(|t| t.name() == topic)
        .ok_or_else(|| anyhow::anyhow!("Topic '{}' not found in cluster metadata", topic))?;

    let mut end_offsets: HashMap<i32, i64> = HashMap::new();
    let mut start_offsets: HashMap<i32, i64> = HashMap::new();
    let mut total_messages_to_scan: i64 = 0;

    for partition in topic_meta.partitions() {
        let p_id = partition.id();
        let (low, high) = consumer
            .fetch_watermarks(&topic, p_id, Duration::from_secs(5))
            .unwrap_or((0, 0));

        let available = (high - low).max(0);
        let mut start_off = low;
        let end_off = high;

        if let Some(max_msgs) = max_messages {
            let part_count = topic_meta.partitions().len() as i64;
            let target_per_partition = (max_msgs / part_count.max(1)).max(1);
            if sample_from_latest && available > target_per_partition {
                start_off = (high - target_per_partition).max(low);
            }
        }

        let to_scan_p = (end_off - start_off).max(0);
        total_messages_to_scan += to_scan_p;

        start_offsets.insert(p_id, start_off);
        end_offsets.insert(p_id, end_off);

        tpl.add_partition_offset(&topic, p_id, Offset::Offset(start_off))?;
    }

    if total_messages_to_scan == 0 {
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
    consumer.assign(&tpl)?;

    // Seek to resolved start offsets
    for (p_id, start_off) in &start_offsets {
        consumer.seek(&topic, *p_id, Offset::Offset(*start_off), timeout)?;
    }

    let scan_start = Instant::now();
    let mut last_emit = Instant::now();
    let mut completed_partitions = std::collections::HashSet::new();
    let total_partitions = topic_meta.partitions().len();

    // 3. Scan polling loop
    let mut current_partition_id = -1;
    let mut consecutive_none_polls = 0;

    while !cancel_flag.load(Ordering::Relaxed) {
        match consumer.poll(Duration::from_millis(50)) {
            Some(Ok(msg)) => {
                consecutive_none_polls = 0;
                let p = msg.partition();
                let off = msg.offset();
                current_partition_id = p;

                let end_off = end_offsets.get(&p).copied().unwrap_or(0);
                if off < end_off {
                    let ts_ms = msg.timestamp().to_millis().unwrap_or(0);
                    let key = msg.key();
                    let payload = msg.payload();

                    accumulator.record_message(p, off, ts_ms, key, payload);

                    if off + 1 >= end_off {
                        completed_partitions.insert(p);
                    }
                } else {
                    completed_partitions.insert(p);
                }

                if completed_partitions.len() >= total_partitions {
                    break;
                }
            }
            Some(Err(e)) => {
                // Partition EOF is expected when reaching partition end
                if let rdkafka::error::KafkaError::PartitionEOF(p) = e {
                    completed_partitions.insert(p);
                    if completed_partitions.len() >= total_partitions {
                        break;
                    }
                }
            }
            None => {
                consecutive_none_polls += 1;
                // If we get 10 consecutive empty polls and have reached close to end offsets
                if consecutive_none_polls >= 10 {
                    break;
                }
            }
        }

        // Periodic progress notification (every ~350ms)
        if last_emit.elapsed() >= Duration::from_millis(350) {
            let elapsed_sec = scan_start.elapsed().as_secs_f64();
            let scanned = accumulator.total_messages;
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

            let partial_report = accumulator.to_report(scan_start.elapsed().as_millis() as i64);
            let progress = TopicAnalysisProgress {
                scanned_messages: scanned,
                total_messages_to_scan,
                progress: pct,
                messages_per_second: mps,
                current_partition: current_partition_id,
                is_complete: false,
                error_message: None,
                partial_report: Some(partial_report),
            };

            if sink.add(progress).is_err() {
                // Dart listener disposed/cancelled
                break;
            }
            last_emit = Instant::now();
        }
    }

    // Final Report
    let total_duration_ms = scan_start.elapsed().as_millis() as i64;
    let final_report = accumulator.to_report(total_duration_ms);
    let final_progress = TopicAnalysisProgress {
        scanned_messages: accumulator.total_messages,
        total_messages_to_scan,
        progress: 1.0,
        messages_per_second: if total_duration_ms > 0 {
            (accumulator.total_messages as f64) / (total_duration_ms as f64 / 1000.0)
        } else {
            0.0
        },
        current_partition: current_partition_id,
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

        acc.record_message(0, 100, ts, Some(key), Some(json_payload));

        // 2. Tombstone message (null payload)
        acc.record_message(1, 200, ts, Some(b"user-456"), None);

        let report = acc.to_report(50);
        assert_eq!(report.total_messages, 2);
        assert_eq!(report.tombstones_count, 1);
        assert_eq!(report.is_compacted, true);
        assert_eq!(report.partition_stats.len(), 2);

        // Check hourly bucketing for hour 14
        let hour_14 = report.hourly_distribution.iter().find(|h| h.hour == 14);
        assert!(hour_14.is_some());
        assert_eq!(hour_14.unwrap().count, 2);

        // Check JSON field frequency
        let event_type_field = report
            .field_frequencies
            .iter()
            .find(|f| f.field_name == "eventType");
        assert!(event_type_field.is_some());
        let top_vals = &event_type_field.unwrap().top_values;
        assert_eq!(top_vals.len(), 1);
        assert_eq!(top_vals[0].value, "USER_SIGNUP");
    }

    #[test]
    fn test_accumulator_partition_balance() {
        let mut acc = AnalyzerAccumulator::new("multi-part".to_string(), false);

        for _ in 0..70 {
            acc.record_message(0, 0, 1000, Some(b"k1"), Some(b"val"));
        }
        for _ in 0..30 {
            acc.record_message(1, 0, 1000, Some(b"k2"), Some(b"val"));
        }

        let report = acc.to_report(20);
        assert_eq!(report.total_messages, 100);
        assert_eq!(report.partition_stats.len(), 2);

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

        assert_eq!(p0.message_count, 70);
        assert_eq!(p0.percentage, 70.0);
        assert_eq!(p1.message_count, 30);
        assert_eq!(p1.percentage, 30.0);
    }
}
