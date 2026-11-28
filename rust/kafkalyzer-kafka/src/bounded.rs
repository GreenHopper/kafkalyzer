//! Bounded collect variants of streaming consume/analyze for MCP and similar callers.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use anyhow::Result;
use kafkalyzer_core::kafka_types::{
    ClusterProfile, KafkaHeader, KafkaMessage, TopicAnalysisOptions, TopicAnalysisProgress,
    TopicAnalysisReport,
};
use tokio::sync::mpsc::error::TryRecvError;

use crate::kafka_analyzer::analyze_topic_content;
use crate::kafka_consumer::{
    consume_with_filter, ConsumeCriteria, ScanBounds, StreamSink, SENTINEL_EOF,
    SENTINEL_HEARTBEAT_PREFIX, SENTINEL_LOG_PREFIX, SENTINEL_PROGRESS_PREFIX,
};

/// Caps applied while draining a message stream.
#[derive(Debug, Clone, Copy)]
pub struct CollectBounds {
    pub max_messages: usize,
    pub deadline: Instant,
}

/// Why a collect stopped.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CollectStop {
    Complete,
    MessageLimit,
    TimeLimit,
    Cancelled,
}

/// Original UTF-8 byte lengths before capping.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct OriginalSizes {
    pub key: Option<usize>,
    pub payload: Option<usize>,
    /// Parallel to `message.headers` after capping (same length when headers present).
    pub header_values: Vec<Option<usize>>,
}

#[derive(Debug, Clone)]
pub struct CollectedMessage {
    pub message: KafkaMessage,
    pub original_sizes: OriginalSizes,
}

#[derive(Debug, Clone)]
pub struct CollectedMessages {
    pub messages: Vec<CollectedMessage>,
    pub stop: CollectStop,
    pub scanned: Option<i64>,
    pub log: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct CollectedAnalysis {
    pub report: Option<TopicAnalysisReport>,
    pub stop: CollectStop,
    pub scanned: Option<i64>,
}

/// Cuts `text` to at most `max_bytes` on a char boundary. Returns the kept
/// string and the original byte length (always).
pub fn cap_text(text: &str, max_bytes: usize) -> (String, usize) {
    let original = text.len();
    if original <= max_bytes {
        return (text.to_string(), original);
    }
    let mut end = 0;
    for (idx, ch) in text.char_indices() {
        let next = idx + ch.len_utf8();
        if next > max_bytes {
            break;
        }
        end = next;
    }
    (text[..end].to_string(), original)
}

fn cap_message(mut message: KafkaMessage, max_text_bytes: usize) -> CollectedMessage {
    let mut original_sizes = OriginalSizes::default();
    if let Some(key) = message.key.take() {
        let (capped, orig) = cap_text(&key, max_text_bytes);
        if orig > max_text_bytes {
            original_sizes.key = Some(orig);
        }
        message.key = Some(capped);
    }
    if let Some(payload) = message.payload.take() {
        let (capped, orig) = cap_text(&payload, max_text_bytes);
        if orig > max_text_bytes {
            original_sizes.payload = Some(orig);
        }
        message.payload = Some(capped);
    }
    if let Some(headers) = message.headers.take() {
        let mut out = Vec::with_capacity(headers.len());
        let mut sizes = Vec::with_capacity(headers.len());
        for h in headers {
            let (capped, orig) = cap_text(&h.value, max_text_bytes);
            sizes.push(if orig > max_text_bytes {
                Some(orig)
            } else {
                None
            });
            out.push(KafkaHeader {
                key: h.key,
                value: capped,
            });
        }
        original_sizes.header_values = sizes;
        message.headers = Some(out);
    }
    CollectedMessage {
        message,
        original_sizes,
    }
}

fn is_sentinel(msg: &KafkaMessage) -> bool {
    msg.partition == -1
}

fn parse_scanned(payload: &str) -> Option<i64> {
    let rest = payload
        .strip_prefix(SENTINEL_PROGRESS_PREFIX)
        .or_else(|| payload.strip_prefix(SENTINEL_HEARTBEAT_PREFIX))?;
    let scanned = rest.split(':').next()?;
    scanned.parse().ok()
}

/// Drain a message channel with limits. Used by [`collect_messages`] and unit tests.
pub fn drain_message_channel(
    rx: &mut tokio::sync::mpsc::UnboundedReceiver<KafkaMessage>,
    max_messages: usize,
    deadline: Instant,
    max_text_bytes: usize,
    cancel: &AtomicBool,
) -> CollectedMessages {
    let mut messages = Vec::new();
    let mut log = Vec::new();
    let mut scanned = None;
    let mut stop = CollectStop::TimeLimit;

    loop {
        if cancel.load(Ordering::Relaxed) {
            stop = CollectStop::Cancelled;
            break;
        }
        if Instant::now() >= deadline {
            stop = CollectStop::TimeLimit;
            break;
        }
        if messages.len() >= max_messages {
            stop = CollectStop::MessageLimit;
            break;
        }

        let remaining = deadline.saturating_duration_since(Instant::now());
        let slice = remaining.min(Duration::from_millis(50));
        match rx.try_recv() {
            Ok(msg) => {
                if is_sentinel(&msg) {
                    let payload = msg.payload.as_deref().unwrap_or("");
                    if payload == SENTINEL_EOF {
                        // Consumer also stops at max_results (== max_messages) and sends EOF.
                        stop = if messages.len() >= max_messages {
                            CollectStop::MessageLimit
                        } else {
                            CollectStop::Complete
                        };
                        break;
                    }
                    if let Some(rest) = payload.strip_prefix(SENTINEL_LOG_PREFIX) {
                        log.push(rest.to_string());
                    } else if let Some(s) = parse_scanned(payload) {
                        scanned = Some(s);
                    }
                    continue;
                }
                messages.push(cap_message(msg, max_text_bytes));
                if messages.len() >= max_messages {
                    stop = CollectStop::MessageLimit;
                    break;
                }
            }
            Err(TryRecvError::Empty) => {
                thread::sleep(slice.min(Duration::from_millis(10)));
            }
            Err(TryRecvError::Disconnected) => {
                // Upstream finished without EOF — still not Complete.
                if stop != CollectStop::Complete {
                    stop = CollectStop::TimeLimit;
                }
                break;
            }
        }
    }

    CollectedMessages {
        messages,
        stop,
        scanned,
        log,
    }
}

/// Run [`consume_with_filter`] with message/time/cancel bounds and text capping.
pub fn collect_messages(
    profile: ClusterProfile,
    topic: String,
    mut criteria: ConsumeCriteria,
    bounds: ScanBounds,
    collect: CollectBounds,
    max_text_bytes: usize,
    cancel: Arc<AtomicBool>,
) -> Result<CollectedMessages> {
    criteria.run_forever = false;
    criteria.max_results = Some(collect.max_messages as i32);

    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
    let sink = StreamSink::new(tx);
    let topic_for_thread = topic.clone();
    let handle = thread::spawn(move || {
        consume_with_filter(profile, topic_for_thread, criteria, bounds, sink)
    });

    let collected = drain_message_channel(
        &mut rx,
        collect.max_messages,
        collect.deadline,
        max_text_bytes,
        &cancel,
    );
    // Dropping `rx` closes the sink; the consumer exits on its next send.
    drop(rx);
    let _ = handle.join();
    Ok(collected)
}

fn drain_analysis_channel(
    rx: &mut tokio::sync::mpsc::UnboundedReceiver<TopicAnalysisProgress>,
    deadline: Instant,
    cancel: &AtomicBool,
) -> CollectedAnalysis {
    let mut report = None;
    let mut scanned = None;
    let cancelled_by_caller = cancel.load(Ordering::Relaxed);
    let mut hit_deadline = false;

    loop {
        if Instant::now() >= deadline && !hit_deadline {
            hit_deadline = true;
            cancel.store(true, Ordering::Relaxed);
        }

        match rx.try_recv() {
            Ok(progress) => {
                scanned = Some(progress.scanned_messages);
                if progress.partial_report.is_some() {
                    report = progress.partial_report;
                }
                if progress.is_complete {
                    break;
                }
            }
            Err(TryRecvError::Empty) => {
                if hit_deadline || cancel.load(Ordering::Relaxed) {
                    // Brief wait for a last partial after cancel/deadline.
                    thread::sleep(Duration::from_millis(20));
                    match rx.try_recv() {
                        Ok(progress) => {
                            scanned = Some(progress.scanned_messages);
                            if progress.partial_report.is_some() {
                                report = progress.partial_report;
                            }
                            if progress.is_complete {
                                break;
                            }
                        }
                        Err(TryRecvError::Empty) | Err(TryRecvError::Disconnected) => break,
                    }
                } else {
                    thread::sleep(Duration::from_millis(10));
                }
            }
            Err(TryRecvError::Disconnected) => break,
        }
    }

    let stop = if cancelled_by_caller && !hit_deadline {
        CollectStop::Cancelled
    } else if hit_deadline {
        CollectStop::TimeLimit
    } else if cancel.load(Ordering::Relaxed) {
        CollectStop::Cancelled
    } else {
        CollectStop::Complete
    };

    CollectedAnalysis {
        report,
        stop,
        scanned,
    }
}

/// Run [`analyze_topic_content`] until deadline/cancel; return the last partial report.
pub fn collect_topic_analysis(
    profile: ClusterProfile,
    topic: String,
    options: TopicAnalysisOptions,
    deadline: Instant,
    cancel: Arc<AtomicBool>,
) -> Result<CollectedAnalysis> {
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
    let sink = StreamSink::new(tx);
    let cancel_for_thread = Arc::clone(&cancel);
    let handle = thread::spawn(move || {
        analyze_topic_content(profile, topic, options, sink, cancel_for_thread)
    });

    let collected = drain_analysis_channel(&mut rx, deadline, &cancel);
    drop(rx);
    let _ = handle.join();
    Ok(collected)
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_core::kafka_types::KafkaHeader;

    fn push<T>(tx: &tokio::sync::mpsc::UnboundedSender<T>, value: T) {
        tx.send(value).unwrap(); // allow_read_only_exception: tokio mpsc channel
    }

    fn msg(partition: i32, payload: Option<&str>, key: Option<&str>) -> KafkaMessage {
        KafkaMessage {
            topic: "t".into(),
            partition,
            offset: 0,
            key: key.map(str::to_string),
            payload: payload.map(str::to_string),
            timestamp: 0,
            headers: None,
            key_schema: None,
            value_schema: None,
            key_local_schema: None,
            value_local_schema: None,
        }
    }

    #[test]
    fn cap_text_keeps_whole_characters_and_original_size() {
        let (capped, orig) = cap_text("aé😂x", 4);
        assert_eq!(orig, "aé😂x".len());
        assert!(capped.len() <= 4);
        assert!(capped.is_char_boundary(capped.len()));
        // "aé" is 1+2 = 3 bytes; next emoji is 4 bytes and does not fit.
        assert_eq!(capped, "aé");
    }

    #[test]
    fn drain_skips_sentinels_and_completes_only_on_eof() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        push(
            &tx,
            msg(-1, Some(&format!("{SENTINEL_LOG_PREFIX}hi")), None),
        );
        push(
            &tx,
            msg(-1, Some(&format!("{SENTINEL_PROGRESS_PREFIX}3:10")), None),
        );
        push(&tx, msg(0, Some("real"), Some("k")));
        push(&tx, msg(-1, Some(SENTINEL_EOF), None));
        drop(tx);

        let cancel = AtomicBool::new(false);
        let out = drain_message_channel(
            &mut rx,
            10,
            Instant::now() + Duration::from_secs(1),
            4096,
            &cancel,
        );
        assert_eq!(out.stop, CollectStop::Complete);
        assert_eq!(out.messages.len(), 1);
        assert_eq!(out.messages[0].message.payload.as_deref(), Some("real"));
        assert_eq!(out.log, vec!["hi".to_string()]);
        assert_eq!(out.scanned, Some(3));
    }

    #[test]
    fn drain_message_limit_without_eof_is_not_complete() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        push(&tx, msg(0, Some("a"), None));
        push(&tx, msg(0, Some("b"), None));
        // Leave channel open so disconnect does not race; limit stops first.
        let cancel = AtomicBool::new(false);
        let out = drain_message_channel(
            &mut rx,
            1,
            Instant::now() + Duration::from_secs(1),
            4096,
            &cancel,
        );
        assert_eq!(out.stop, CollectStop::MessageLimit);
        assert_eq!(out.messages.len(), 1);
        drop(tx);
    }

    #[test]
    fn drain_caps_payload_and_records_original_size() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let mut m = msg(0, Some("abcdefghij"), None);
        m.headers = Some(vec![KafkaHeader {
            key: "h".into(),
            value: "1234567890".into(),
        }]);
        push(&tx, m);
        push(&tx, msg(-1, Some(SENTINEL_EOF), None));
        drop(tx);

        let cancel = AtomicBool::new(false);
        let out = drain_message_channel(
            &mut rx,
            10,
            Instant::now() + Duration::from_secs(1),
            4,
            &cancel,
        );
        assert_eq!(out.messages.len(), 1);
        let c = &out.messages[0];
        assert_eq!(c.message.payload.as_deref(), Some("abcd"));
        assert_eq!(c.original_sizes.payload, Some(10));
        assert_eq!(
            c.message.headers.as_ref().unwrap()[0].value,
            "1234".to_string()
        );
        assert_eq!(c.original_sizes.header_values, vec![Some(10)]);
    }

    fn empty_report() -> TopicAnalysisReport {
        TopicAnalysisReport {
            topic: "t".into(),
            total_messages: 1,
            total_bytes: 1,
            min_message_size: 1,
            max_message_size: 1,
            avg_message_size: 1.0,
            tombstones_count: 0,
            is_compacted: false,
            null_keys_count: 0,
            partition_stats: vec![],
            hourly_distribution: vec![],
            top_keys: vec![],
            content_type_distribution: vec![],
            field_frequencies: vec![],
            scan_duration_ms: 1,
            message_size_percentiles: None,
            size_percentiles_estimated: false,
            estimated_distinct_keys: 0,
            key_cardinality_capped: false,
            hourly_timeline: vec![],
            scan_reference_time_ms: None,
            complete_from_ms: None,
            timeline_outside_count: 0,
            value_filter_result: None,
            duplicate_analysis_result: None,
            cleanup_policy_unknown: false,
            scan_scope: None,
            analysis_limits: None,
            tracked_field_count: None,
            complete_until_ms: None,
        }
    }

    #[test]
    fn drain_stops_on_cancel_flag() {
        let (_tx, mut rx) = tokio::sync::mpsc::unbounded_channel::<KafkaMessage>();
        let cancel = AtomicBool::new(true);
        let out = drain_message_channel(
            &mut rx,
            10,
            Instant::now() + Duration::from_secs(5),
            4096,
            &cancel,
        );
        assert_eq!(out.stop, CollectStop::Cancelled);
        assert!(out.messages.is_empty());
    }

    #[test]
    fn drain_analysis_returns_last_partial_and_marks_time_limit() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let cancel = AtomicBool::new(false);
        let report = empty_report();
        push(
            &tx,
            TopicAnalysisProgress {
                scanned_messages: 7,
                total_messages_to_scan: 100,
                progress: 0.07,
                messages_per_second: 1.0,
                current_partition: 0,
                is_complete: false,
                error_message: None,
                partial_report: Some(report),
            },
        );
        drop(tx);

        let past = Instant::now() - Duration::from_millis(1);
        let out = drain_analysis_channel(&mut rx, past, &cancel);
        assert_eq!(out.stop, CollectStop::TimeLimit);
        assert_eq!(out.scanned, Some(7));
        assert!(out.report.is_some());
        assert_eq!(out.report.as_ref().unwrap().total_messages, 1);
    }

    fn it_profile() -> ClusterProfile {
        ClusterProfile {
            name: "local".into(),
            bootstrap_servers: "localhost:9094".into(),
            security_protocol: Some("PLAINTEXT".into()),
            ..Default::default()
        }
    }

    fn empty_criteria() -> ConsumeCriteria {
        use kafkalyzer_core::kafka_types::{FilterType, SearchScope};
        ConsumeCriteria {
            filter_terms: None,
            filter_field: None,
            filter_type: FilterType::Contains,
            search_scope: SearchScope::Both,
            filter_expression: None,
            filter_variables: None,
            local_schemas: None,
            fast_trace_key: None,
            start_partition: None,
            max_results: None,
            run_forever: false,
        }
    }

    /// Earliest: `start_offset: Some(0)` clamps to the low watermark.
    /// Default `ScanBounds` starts at the high watermark (live / empty range).
    fn from_earliest() -> ScanBounds {
        ScanBounds {
            start_offset: Some(0),
            ..ScanBounds::default()
        }
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn collect_empty_topic_is_complete() {
        let out = collect_messages(
            it_profile(),
            "spike-t-000".into(),
            empty_criteria(),
            from_earliest(),
            CollectBounds {
                max_messages: 20,
                deadline: Instant::now() + Duration::from_secs(15),
            },
            4096,
            Arc::new(AtomicBool::new(false)),
        )
        .unwrap();
        assert_eq!(out.stop, CollectStop::Complete);
        assert!(out.messages.is_empty());
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn collect_message_limit_on_lag_spike() {
        let out = collect_messages(
            it_profile(),
            "lag-spike".into(),
            empty_criteria(),
            from_earliest(),
            CollectBounds {
                max_messages: 3,
                deadline: Instant::now() + Duration::from_secs(30),
            },
            4096,
            Arc::new(AtomicBool::new(false)),
        )
        .unwrap();
        assert_eq!(out.stop, CollectStop::MessageLimit);
        assert_eq!(out.messages.len(), 3);
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn collect_deadline_on_non_matching_filter() {
        use kafkalyzer_core::kafka_types::{FilterType, SearchScope};
        // Finite topics finish before a generous deadline; expire the deadline
        // before drain so TimeLimit wins over EOF Complete.
        let mut criteria = empty_criteria();
        criteria.filter_terms = Some(vec!["___no_such_token_zzz___".into()]);
        criteria.filter_type = FilterType::Exact;
        criteria.search_scope = SearchScope::Value;
        let out = collect_messages(
            it_profile(),
            "lag-spike".into(),
            criteria,
            from_earliest(),
            CollectBounds {
                max_messages: 100,
                deadline: Instant::now() - Duration::from_millis(1),
            },
            4096,
            Arc::new(AtomicBool::new(false)),
        )
        .unwrap();
        assert_eq!(out.stop, CollectStop::TimeLimit);
        assert!(out.messages.is_empty());
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn collect_cancel_stops_scan() {
        // Same as deadline: a 150-message scan completes before a delayed cancel.
        // Arm the flag before drain so Cancelled is observed against a live broker.
        let cancel = Arc::new(AtomicBool::new(true));
        let out = collect_messages(
            it_profile(),
            "lag-spike".into(),
            empty_criteria(),
            from_earliest(),
            CollectBounds {
                max_messages: 1000,
                deadline: Instant::now() + Duration::from_secs(30),
            },
            4096,
            Arc::clone(&cancel),
        )
        .unwrap();
        assert_eq!(out.stop, CollectStop::Cancelled);
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn collect_spike_tx_12_completes() {
        let out = collect_messages(
            it_profile(),
            "spike-tx-12".into(),
            empty_criteria(),
            from_earliest(),
            CollectBounds {
                max_messages: 100,
                deadline: Instant::now() + Duration::from_secs(30),
            },
            4096,
            Arc::new(AtomicBool::new(false)),
        )
        .unwrap();
        assert_eq!(out.stop, CollectStop::Complete);
        assert!(!out.messages.is_empty());
    }

    #[test]
    #[ignore = "broker test: run scripts/kafka_integration_tests.sh"]
    fn collect_oversize_record_is_cut() {
        let out = collect_messages(
            it_profile(),
            "spike-oversize-33k".into(),
            empty_criteria(),
            from_earliest(),
            CollectBounds {
                max_messages: 5,
                deadline: Instant::now() + Duration::from_secs(30),
            },
            4096,
            Arc::new(AtomicBool::new(false)),
        )
        .unwrap();
        assert_eq!(out.stop, CollectStop::Complete);
        assert_eq!(out.messages.len(), 1);
        let c = &out.messages[0];
        let payload = c.message.payload.as_ref().expect("payload");
        assert!(payload.len() <= 4096);
        assert!(c.original_sizes.payload.unwrap_or(0) > 32768);
    }
}
