use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, Instant};

use anyhow::Result;
use kafkalyzer_core::offset_distribution::WatermarkRead;
use kafkalyzer_core::topic_time_range::{
    aggregate, tail_start_offset, PartitionProbe, ProbeOutcome, TimestampKind, TopicTimeRange,
    TAIL_WINDOW,
};
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::error::KafkaError;
use rdkafka::types::RDKafkaErrorCode;
use rdkafka::Message;
use rdkafka::Timestamp;
use rdkafka::TopicPartitionList;

use crate::kafka_metadata::fetch_partition_offsets;
use crate::kafka_utils::create_config;
use kafkalyzer_core::kafka_types::ClusterProfile;

static PROBE_SEQ: AtomicU64 = AtomicU64::new(1);

#[derive(Debug, Clone)]
enum ProbeEvent {
    Message {
        partition: i32,
        offset: i64,
        timestamp: Timestamp,
    },
    PartitionEof {
        partition: i32,
    },
    Error {
        partition: Option<i32>,
        message: String,
        is_auth: bool,
    },
}

fn timestamp_to_outcome(offset: i64, ts: Timestamp) -> ProbeOutcome {
    match ts {
        Timestamp::CreateTime(ms) => ProbeOutcome::Found {
            offset,
            timestamp_ms: ms,
            timestamp_type: TimestampKind::CreateTime,
        },
        Timestamp::LogAppendTime(ms) => ProbeOutcome::Found {
            offset,
            timestamp_ms: ms,
            timestamp_type: TimestampKind::LogAppendTime,
        },
        Timestamp::NotAvailable => ProbeOutcome::NoTimestamp,
    }
}

struct HeadPhaseState {
    pending: HashSet<i32>,
    outcomes: HashMap<i32, ProbeOutcome>,
}

impl HeadPhaseState {
    fn new(partitions: &[i32]) -> Self {
        Self {
            pending: partitions.iter().copied().collect(),
            outcomes: HashMap::with_capacity(partitions.len()),
        }
    }

    /// Processes one event; returns `Some(partition)` when that partition
    /// should be paused after delivering its first record.
    fn apply(&mut self, event: ProbeEvent) -> Option<i32> {
        match event {
            ProbeEvent::Message {
                partition,
                offset,
                timestamp,
            } => {
                if self.pending.remove(&partition) {
                    self.outcomes
                        .insert(partition, timestamp_to_outcome(offset, timestamp));
                    return Some(partition);
                }
                None
            }
            ProbeEvent::PartitionEof { partition } => {
                if self.pending.remove(&partition) {
                    self.outcomes
                        .insert(partition, ProbeOutcome::NotFoundInWindow);
                }
                None
            }
            ProbeEvent::Error {
                partition: Some(partition),
                message,
                is_auth,
            } => {
                if self.pending.remove(&partition) {
                    let outcome = if is_auth {
                        ProbeOutcome::Unreadable(message)
                    } else {
                        ProbeOutcome::Failed(message)
                    };
                    self.outcomes.insert(partition, outcome);
                }
                None
            }
            ProbeEvent::Error {
                partition: None,
                message,
                is_auth,
            } => {
                for p in self.pending.drain() {
                    let outcome = if is_auth {
                        ProbeOutcome::Unreadable(message.clone())
                    } else {
                        ProbeOutcome::Failed(message.clone())
                    };
                    self.outcomes.insert(p, outcome);
                }
                None
            }
        }
    }

    fn finish_timed_out(&mut self) {
        for p in self.pending.drain() {
            self.outcomes.insert(p, ProbeOutcome::TimedOut);
        }
    }
}

struct TailPhaseState {
    pending: HashSet<i32>,
    last_seen: HashMap<i32, (i64, Timestamp)>,
    outcomes: HashMap<i32, ProbeOutcome>,
}

impl TailPhaseState {
    fn new(partitions: &[i32]) -> Self {
        Self {
            pending: partitions.iter().copied().collect(),
            last_seen: HashMap::with_capacity(partitions.len()),
            outcomes: HashMap::with_capacity(partitions.len()),
        }
    }

    fn apply(&mut self, event: ProbeEvent) {
        match event {
            ProbeEvent::Message {
                partition,
                offset,
                timestamp,
            } => {
                if self.pending.contains(&partition) {
                    self.last_seen.insert(partition, (offset, timestamp));
                }
            }
            ProbeEvent::PartitionEof { partition } => {
                if self.pending.remove(&partition) {
                    let outcome = match self.last_seen.remove(&partition) {
                        Some((offset, ts)) => timestamp_to_outcome(offset, ts),
                        None => ProbeOutcome::NotFoundInWindow,
                    };
                    self.outcomes.insert(partition, outcome);
                }
            }
            ProbeEvent::Error {
                partition: Some(partition),
                message,
                is_auth,
            } => {
                if self.pending.remove(&partition) {
                    self.last_seen.remove(&partition);
                    let outcome = if is_auth {
                        ProbeOutcome::Unreadable(message)
                    } else {
                        ProbeOutcome::Failed(message)
                    };
                    self.outcomes.insert(partition, outcome);
                }
            }
            ProbeEvent::Error {
                partition: None,
                message,
                is_auth,
            } => {
                for p in self.pending.drain() {
                    self.last_seen.remove(&p);
                    let outcome = if is_auth {
                        ProbeOutcome::Unreadable(message.clone())
                    } else {
                        ProbeOutcome::Failed(message.clone())
                    };
                    self.outcomes.insert(p, outcome);
                }
            }
        }
    }

    fn finish_timed_out(&mut self) {
        for p in self.pending.drain() {
            self.last_seen.remove(&p);
            self.outcomes.insert(p, ProbeOutcome::TimedOut);
        }
    }
}

fn poll_to_event(
    polled: std::result::Result<rdkafka::message::BorrowedMessage<'_>, KafkaError>,
) -> ProbeEvent {
    match polled {
        Ok(msg) => {
            // Only extract offset + timestamp; payload is never read or retained.
            ProbeEvent::Message {
                partition: msg.partition(),
                offset: msg.offset(),
                timestamp: msg.timestamp(),
            }
        }
        Err(KafkaError::PartitionEOF(partition)) => ProbeEvent::PartitionEof { partition },
        Err(err) => {
            let msg = err.to_string();
            let is_auth = matches!(
                err,
                KafkaError::MessageConsumption(RDKafkaErrorCode::TopicAuthorizationFailed)
                    | KafkaError::MessageConsumption(RDKafkaErrorCode::GroupAuthorizationFailed)
            ) || msg.to_lowercase().contains("authorization");
            ProbeEvent::Error {
                partition: None,
                message: msg,
                is_auth,
            }
        }
    }
}

/// Probes the oldest and newest retained message timestamps for `topic` using
/// manual partition assignment, read-only flags, bounded fetch sizes, and an
/// overall deadline.
pub fn fetch_topic_time_range(
    profile: &ClusterProfile,
    topic: &str,
    deadline: Duration,
) -> Result<TopicTimeRange> {
    let offsets = fetch_partition_offsets(profile, topic)?;
    let mut initial_probes: HashMap<i32, PartitionProbe> = HashMap::new();
    let mut active_ranges: Vec<(i32, i64, i64)> = Vec::new();

    for pw in &offsets.partitions {
        match &pw.read {
            WatermarkRead::Known { low, high } if low >= high => {
                initial_probes.insert(
                    pw.partition,
                    PartitionProbe {
                        partition: pw.partition,
                        oldest: ProbeOutcome::Empty,
                        newest: ProbeOutcome::Empty,
                    },
                );
            }
            WatermarkRead::Known { low, high } => {
                active_ranges.push((pw.partition, *low, *high));
            }
            WatermarkRead::NotReadable(msg) => {
                initial_probes.insert(
                    pw.partition,
                    PartitionProbe {
                        partition: pw.partition,
                        oldest: ProbeOutcome::Unreadable(msg.clone()),
                        newest: ProbeOutcome::Unreadable(msg.clone()),
                    },
                );
            }
            WatermarkRead::Failed(msg) => {
                initial_probes.insert(
                    pw.partition,
                    PartitionProbe {
                        partition: pw.partition,
                        oldest: ProbeOutcome::Failed(msg.clone()),
                        newest: ProbeOutcome::Failed(msg.clone()),
                    },
                );
            }
            WatermarkRead::TimedOut => {
                initial_probes.insert(
                    pw.partition,
                    PartitionProbe {
                        partition: pw.partition,
                        oldest: ProbeOutcome::TimedOut,
                        newest: ProbeOutcome::TimedOut,
                    },
                );
            }
        }
    }

    if active_ranges.is_empty() {
        let probes: Vec<PartitionProbe> = initial_probes.into_values().collect();
        return Ok(aggregate(&probes));
    }

    let seq = PROBE_SEQ.fetch_add(1, Ordering::Relaxed);
    let mut config = create_config(profile);
    config
        .set(
            "group.id",
            format!("kafkalyzer-timerange-{}-{}", std::process::id(), seq),
        )
        .set("enable.auto.commit", "false")
        .set("enable.auto.offset.store", "false")
        .set("enable.partition.eof", "true")
        .set("auto.offset.reset", "earliest")
        .set("fetch.message.max.bytes", "65536")
        .set("fetch.wait.max.ms", "100")
        .set("queued.min.messages", "1")
        .set("queued.max.messages.kbytes", "1024");

    let consumer: BaseConsumer = config.create()?;
    let active_partitions: Vec<i32> = active_ranges.iter().map(|(p, _, _)| *p).collect();

    let overall_end = Instant::now() + deadline;
    let head_end = Instant::now() + deadline / 2;

    // --- Head phase: first message at/after low watermark ---
    let mut head_tpl = TopicPartitionList::new();
    for &(partition, low, _) in &active_ranges {
        head_tpl.add_partition_offset(topic, partition, rdkafka::Offset::Offset(low))?;
    }
    consumer.assign(&head_tpl)?;

    let mut head_state = HeadPhaseState::new(&active_partitions);
    while !head_state.pending.is_empty() {
        let now = Instant::now();
        if now >= head_end {
            break;
        }
        let poll_timeout = Duration::from_millis(50).min(head_end - now);
        if let Some(polled) = consumer.poll(poll_timeout) {
            if let Some(pause_partition) = head_state.apply(poll_to_event(polled)) {
                let mut pause_tpl = TopicPartitionList::new();
                pause_tpl.add_partition(topic, pause_partition);
                let _ = consumer.pause(&pause_tpl);
            }
        }
    }
    head_state.finish_timed_out();

    // --- Tail phase: last message in [max(low, high - 16), high) before PartitionEOF ---
    consumer.unassign()?;
    let mut tail_tpl = TopicPartitionList::new();
    let mut resume_tpl = TopicPartitionList::new();
    for &(partition, low, high) in &active_ranges {
        let start = tail_start_offset(low, high, TAIL_WINDOW);
        tail_tpl.add_partition_offset(topic, partition, rdkafka::Offset::Offset(start))?;
        resume_tpl.add_partition(topic, partition);
    }
    consumer.assign(&tail_tpl)?;
    consumer.resume(&resume_tpl)?;

    let mut tail_state = TailPhaseState::new(&active_partitions);
    while !tail_state.pending.is_empty() {
        let now = Instant::now();
        if now >= overall_end {
            break;
        }
        let poll_timeout = Duration::from_millis(50).min(overall_end - now);
        if let Some(polled) = consumer.poll(poll_timeout) {
            tail_state.apply(poll_to_event(polled));
        }
    }
    tail_state.finish_timed_out();

    for &(partition, _, _) in &active_ranges {
        initial_probes.insert(
            partition,
            PartitionProbe {
                partition,
                oldest: head_state
                    .outcomes
                    .remove(&partition)
                    .unwrap_or(ProbeOutcome::TimedOut),
                newest: tail_state
                    .outcomes
                    .remove(&partition)
                    .unwrap_or(ProbeOutcome::TimedOut),
            },
        );
    }

    let probes: Vec<PartitionProbe> = initial_probes.into_values().collect();
    Ok(aggregate(&probes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn head_phase_captures_first_message_ignores_post_pause_and_handles_eof_or_timeout() {
        let mut head = HeadPhaseState::new(&[0, 1, 2, 3]);

        // Partition 0 delivers a message, then a buffered post-pause message arrives.
        assert_eq!(
            head.apply(ProbeEvent::Message {
                partition: 0,
                offset: 10,
                timestamp: Timestamp::CreateTime(1_000),
            }),
            Some(0)
        );
        assert_eq!(
            head.apply(ProbeEvent::Message {
                partition: 0,
                offset: 11,
                timestamp: Timestamp::CreateTime(2_000),
            }),
            None
        );

        // Partition 1 hits EOF without delivering a message.
        assert_eq!(head.apply(ProbeEvent::PartitionEof { partition: 1 }), None);

        // Partition 2 delivers a message with Timestamp::NotAvailable.
        assert_eq!(
            head.apply(ProbeEvent::Message {
                partition: 2,
                offset: 5,
                timestamp: Timestamp::NotAvailable,
            }),
            Some(2)
        );

        // Partition 3 never delivers before deadline.
        head.finish_timed_out();

        assert_eq!(
            head.outcomes.get(&0),
            Some(&ProbeOutcome::Found {
                offset: 10,
                timestamp_ms: 1_000,
                timestamp_type: TimestampKind::CreateTime,
            })
        );
        assert_eq!(head.outcomes.get(&1), Some(&ProbeOutcome::NotFoundInWindow));
        assert_eq!(head.outcomes.get(&2), Some(&ProbeOutcome::NoTimestamp));
        assert_eq!(head.outcomes.get(&3), Some(&ProbeOutcome::TimedOut));
    }

    #[test]
    fn tail_phase_keeps_last_message_before_eof_and_marks_empty_window_or_timeout() {
        let mut tail = TailPhaseState::new(&[0, 1, 2]);

        // Partition 0 receives multiple records then EOF -> keeps the last one.
        tail.apply(ProbeEvent::Message {
            partition: 0,
            offset: 90,
            timestamp: Timestamp::CreateTime(5_000),
        });
        tail.apply(ProbeEvent::Message {
            partition: 0,
            offset: 95,
            timestamp: Timestamp::LogAppendTime(6_500),
        });
        tail.apply(ProbeEvent::PartitionEof { partition: 0 });

        // Partition 1 receives EOF with no records (e.g. only transaction markers in window).
        tail.apply(ProbeEvent::PartitionEof { partition: 1 });

        // Partition 2 receives a record but never reaches EOF before deadline -> TimedOut.
        tail.apply(ProbeEvent::Message {
            partition: 2,
            offset: 40,
            timestamp: Timestamp::CreateTime(3_000),
        });
        tail.finish_timed_out();

        assert_eq!(
            tail.outcomes.get(&0),
            Some(&ProbeOutcome::Found {
                offset: 95,
                timestamp_ms: 6_500,
                timestamp_type: TimestampKind::LogAppendTime,
            })
        );
        assert_eq!(tail.outcomes.get(&1), Some(&ProbeOutcome::NotFoundInWindow));
        assert_eq!(tail.outcomes.get(&2), Some(&ProbeOutcome::TimedOut));
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn integration_cluster_overview_and_time_range() {
        let profile = ClusterProfile {
            name: "integration".to_string(),
            bootstrap_servers: "localhost:9094".to_string(),
            security_protocol: Some("PLAINTEXT".to_string()),
            ..Default::default()
        };
        let overview = crate::kafka_metadata::fetch_cluster_overview(&profile).unwrap();
        assert!(!overview.brokers.is_empty());
        assert!(overview.cluster_id.is_some());

        let range =
            fetch_topic_time_range(&profile, "spike-tx-12", Duration::from_secs(15)).unwrap();
        assert_eq!(range.partitions_total, 1);
        assert_eq!(range.oldest_known, 1);
        assert_eq!(range.newest_known, 1);
        assert!(range.oldest.is_some());
        assert!(range.newest.is_some());
    }
}
