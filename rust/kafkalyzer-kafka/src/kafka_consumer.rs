use anyhow::Result;
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::Message as KafkaMessageTrait;
use regex::Regex;
use schema_registry_converter::async_impl::avro::AvroDecoder;
use schema_registry_converter::async_impl::json::JsonDecoder;
use schema_registry_converter::async_impl::proto_decoder::ProtoDecoder;
use schema_registry_converter::async_impl::schema_registry::{get_all_subjects, SrSettings};
use std::time::{SystemTime, UNIX_EPOCH};

use tokio::runtime::Runtime;

use crate::kafka_utils::{create_config, murmur2, to_positive};
use kafkalyzer_core::kafka_types::{ClusterProfile, FilterType, KafkaMessage, SearchScope};

#[derive(Clone)]
pub struct StreamSink<T> {
    tx: tokio::sync::mpsc::UnboundedSender<T>,
}

impl<T> StreamSink<T> {
    pub fn new(tx: tokio::sync::mpsc::UnboundedSender<T>) -> Self {
        Self { tx }
    }

    pub fn add(&self, value: T) -> Result<(), String> {
        self.tx.send(value).map_err(|e| e.to_string())
    }
}

pub struct SrDecoders<'a> {
    pub settings: SrSettings,
    pub avro: AvroDecoder<'a>,
    pub json: JsonDecoder<'a>,
    pub proto: ProtoDecoder<'a>,
}

pub fn consume_with_filter(
    profile: ClusterProfile,
    topic: String,
    filter_terms: Option<Vec<String>>,
    filter_field: Option<String>,
    filter_type: FilterType,
    search_scope: SearchScope,
    start_offset: Option<i64>,
    start_timestamp: Option<i64>,
    start_partition: Option<i32>,
    fast_trace_key: Option<String>,
    end_offset: Option<i64>,
    end_timestamp: Option<i64>,
    max_results: Option<i32>,
    run_forever: bool,
    sink: StreamSink<KafkaMessage>,
) -> Result<()> {
    // 1. Setup Runtime & Config
    let tokio_runtime = Runtime::new()?;

    // 2. Setup Schema Registry (Optional)
    let sr_settings = create_sr_settings(&profile);
    let (decoders, key_is_avro, value_is_avro) = if let Some(ref settings) = sr_settings {
        setup_schema_registry(&tokio_runtime, settings, &topic)?
    } else {
        (None, false, false)
    };

    // 3. Create Consumer
    let consumer = create_consumer(
        &profile,
        start_offset.is_some() || start_timestamp.is_some(),
    )?;

    // 4. Setup Assignment
    let timeout = std::time::Duration::from_secs(10);
    let metadata = consumer.fetch_metadata(Some(&topic), timeout)?;
    let (topic_partition_list, target_partition_id) = setup_topic_assignment(
        &consumer,
        &topic,
        &metadata,
        &fast_trace_key,
        start_partition,
    )?;

    // 5. Fetch watermarks in a single pass and reuse them for start/end bounds.
    let assigned_partitions: Vec<i32> = topic_partition_list
        .elements()
        .iter()
        .map(|e| e.partition())
        .collect();
    let watermarks = fetch_partition_watermarks(
        &consumer,
        &topic,
        &assigned_partitions,
        std::time::Duration::from_secs(5),
        &sink,
    );

    // 6. Resolve start offsets from the cached watermarks (no seek yet).
    let start_offsets_map_result = resolve_start_offsets(
        &consumer,
        &topic,
        &watermarks,
        start_offset,
        start_timestamp,
        timeout,
        &sink,
    )?;

    // 7. Calculate end offsets from the same watermark map.
    let end_offsets = calculate_end_offsets(
        &consumer,
        &metadata,
        &topic,
        &topic_partition_list,
        &watermarks,
        run_forever,
        end_offset,
        end_timestamp,
        target_partition_id,
        timeout,
        &sink,
    )?;

    // 8. Calculate total to scan from the resolved bounds.
    let total_to_scan = calculate_total_to_scan(
        &topic_partition_list,
        &start_offsets_map_result,
        &end_offsets,
        target_partition_id,
    );

    // Send initial progress
    let initial_msg = KafkaMessage {
        topic: topic.clone(),
        partition: -1,
        offset: -1,
        key: None,
        payload: Some(format!("__PROGRESS__:0:{}", total_to_scan)),
        timestamp: 0,
        headers: None,
    };
    sink.add(initial_msg).ok();

    // Fast-path: empty topics and exhausted ranges skip seek + poll entirely.
    if should_fast_path_empty(run_forever, total_to_scan) {
        send_eof(&sink, &topic);
        return Ok(());
    }

    // 9. Seek only after the fast-path check, and only when a start was requested.
    if start_offset.is_some() || start_timestamp.is_some() {
        apply_start_seeks(&consumer, &topic, &start_offsets_map_result, timeout, &sink);
    }

    // 10. Run Main Loop
    run_poll_loop(
        consumer,
        topic,
        start_offsets_map_result,
        end_offsets,
        filter_terms,
        filter_field,
        filter_type,
        search_scope,
        max_results,
        run_forever,
        sink,
        tokio_runtime,
        decoders,
        key_is_avro,
        value_is_avro,
        total_to_scan,
    )?;

    Ok(())
}

pub(crate) fn create_sr_settings(profile: &ClusterProfile) -> Option<SrSettings> {
    if let Some(url) = &profile.schema_registry_url {
        let mut sr_url = url.trim().to_string();
        if !sr_url.is_empty() && !sr_url.starts_with("http://") && !sr_url.starts_with("https://") {
            sr_url = format!("http://{}", sr_url);
        }
        if !sr_url.is_empty() {
            use std::io::Read;
            let mut builder = SrSettings::new_builder(sr_url);

            // 1. Basic Auth
            if let (Some(u), Some(p)) = (
                &profile.schema_registry_username,
                &profile.schema_registry_password,
            ) {
                builder.set_basic_authorization(u, Some(p));
            }

            // 2. Client builder for SSL/TLS configuration
            let mut client_builder = reqwest::Client::builder();

            // SSL Truststore
            if let Some(truststore_path) = &profile.ssl_truststore_location {
                if !truststore_path.trim().is_empty() {
                    if let Ok(mut file) = std::fs::File::open(truststore_path) {
                        let mut cert_bytes = vec![];
                        if file.read_to_end(&mut cert_bytes).is_ok() {
                            if let Ok(cert) = reqwest::Certificate::from_pem(&cert_bytes) {
                                client_builder = client_builder.add_root_certificate(cert);
                            }
                        }
                    }
                }
            }

            // SSL Keystore (mTLS)
            if let Some(keystore_path) = &profile.ssl_keystore_location {
                if !keystore_path.trim().is_empty()
                    && (keystore_path.to_lowercase().ends_with(".p12")
                        || keystore_path.to_lowercase().ends_with(".pfx"))
                {
                    let password = profile.ssl_keystore_password.as_deref().unwrap_or("");
                    if let Ok(mut file) = std::fs::File::open(keystore_path) {
                        let mut pkcs12_bytes = vec![];
                        if file.read_to_end(&mut pkcs12_bytes).is_ok() {
                            if let Ok(identity) =
                                reqwest::Identity::from_pkcs12_der(&pkcs12_bytes, password)
                            {
                                client_builder = client_builder.identity(identity);
                            }
                        }
                    }
                }
            } else if let (Some(cert_path), Some(key_path)) = (
                &profile.ssl_pem_certificate_location,
                &profile.ssl_pem_key_location,
            ) {
                if let (Ok(cert_bytes), Ok(key_bytes)) =
                    (std::fs::read(cert_path), std::fs::read(key_path))
                {
                    if let Ok(identity) = reqwest::Identity::from_pkcs8_pem(&cert_bytes, &key_bytes)
                    {
                        client_builder = client_builder.identity(identity);
                    }
                }
            }

            if let Ok(settings) = builder.build_with(client_builder) {
                return Some(settings);
            }
        }
    }
    None
}

fn create_consumer(profile: &ClusterProfile, is_seeking: bool) -> Result<BaseConsumer> {
    let mut client_config = create_config(profile);

    let timestamp = SystemTime::now().duration_since(UNIX_EPOCH)?.as_millis();
    let group_id = format!("kafkalyzer_consumer_{}", timestamp);

    client_config.set("group.id", &group_id);
    client_config.set("enable.auto.commit", "false");
    client_config.set("enable.auto.offset.store", "false");

    let reset_strategy = if is_seeking { "earliest" } else { "latest" };
    client_config.set("auto.offset.reset", reset_strategy);

    let consumer: BaseConsumer = client_config.create()?;
    Ok(consumer)
}

fn should_fast_path_empty(run_forever: bool, total_to_scan: i64) -> bool {
    !run_forever && total_to_scan == 0
}

fn clamp_start_offset(requested: i64, low: i64) -> i64 {
    if requested < low {
        low
    } else {
        requested
    }
}

fn start_offset_from_watermarks(start_offset: Option<i64>, low: i64, high: i64) -> i64 {
    match start_offset {
        Some(offset) => clamp_start_offset(offset, low),
        None => high,
    }
}

fn range_to_scan(start: i64, end: i64) -> i64 {
    if end > start {
        end - start
    } else {
        0
    }
}

fn should_skip_beyond_end(run_forever: bool, offset: i64, end_offset: i64) -> bool {
    !run_forever && offset >= end_offset
}

fn should_stop_for_limit(matched_count: i32, max_results: Option<i32>) -> bool {
    match max_results {
        Some(limit) => matched_count >= limit,
        None => false,
    }
}

fn watermark_high(watermarks: &std::collections::HashMap<i32, (i64, i64)>, partition: i32) -> i64 {
    watermarks
        .get(&partition)
        .map(|(_, high)| *high)
        .unwrap_or(0)
}

fn calculate_total_to_scan(
    topic_partition_list: &rdkafka::TopicPartitionList,
    start_offsets_map: &std::collections::HashMap<i32, i64>,
    end_offsets: &std::collections::HashMap<i32, i64>,
    target_partition_id: Option<i32>,
) -> i64 {
    let mut total_to_scan: i64 = 0;

    let mut all_partitions = std::collections::HashSet::new();
    for elem in topic_partition_list.elements() {
        all_partitions.insert(elem.partition());
    }

    for p in all_partitions {
        if let Some(target) = target_partition_id {
            if p != target {
                continue;
            }
        }

        let end = match end_offsets.get(&p) {
            Some(e) => *e,
            None => continue,
        };
        let start = start_offsets_map.get(&p).copied().unwrap_or(0);
        total_to_scan += range_to_scan(start, end);
    }
    total_to_scan
}

fn run_poll_loop<'a>(
    consumer: BaseConsumer,
    topic: String,
    start_offsets_map: std::collections::HashMap<i32, i64>,
    end_offsets: std::collections::HashMap<i32, i64>,
    filter_terms: Option<Vec<String>>,
    filter_field: Option<String>,
    filter_type: FilterType,
    search_scope: SearchScope,
    max_results: Option<i32>,
    run_forever: bool,
    sink: StreamSink<KafkaMessage>,
    tokio_runtime: Runtime,
    decoder: Option<SrDecoders<'a>>,
    key_is_avro: bool,
    value_is_avro: bool,
    total_to_scan: i64,
) -> Result<()> {
    let mut scanned_count: u64 = 0;
    let mut last_report_time = std::time::Instant::now();
    let mut last_eof_check_time = std::time::Instant::now();

    let mut current_offsets = start_offsets_map.clone();
    let mut matched_count: i32 = 0;

    loop {
        // Check Limit
        if should_stop_for_limit(matched_count, max_results) {
            if let Some(limit) = max_results {
                log_to_dart(
                    &sink,
                    format!("Max results limit ({}) reached. Stopping.", limit),
                );
            }
            send_progress(&sink, &topic, scanned_count, total_to_scan).ok();
            send_eof(&sink, &topic);
            break;
        }

        // Log every 5000 messages
        if scanned_count > 0 && scanned_count.is_multiple_of(5000) {
            log_to_dart(&sink, format!("Scanned {} messages.", scanned_count));
        }

        match consumer.poll(std::time::Duration::from_millis(100)) {
            Some(Ok(msg)) => {
                if let Some(target_end_offset) = end_offsets.get(&msg.partition()) {
                    if should_skip_beyond_end(run_forever, msg.offset(), *target_end_offset) {
                        current_offsets.insert(msg.partition(), msg.offset() + 1);
                        continue; // Skip processing and emitting messages beyond boundary
                    }
                }

                scanned_count += 1;
                current_offsets.insert(msg.partition(), msg.offset() + 1);

                if last_report_time.elapsed().as_millis() > 250 {
                    if let Err(e) = send_progress(&sink, &topic, scanned_count, total_to_scan) {
                        log_to_dart(
                            &sink,
                            format!("Sink closed (progress), breaking loop. Error: {:?}", e),
                        );
                        break;
                    }
                    last_report_time = std::time::Instant::now();
                }

                if !run_forever && last_eof_check_time.elapsed().as_millis() >= 500 {
                    if check_done(&consumer, &end_offsets, &current_offsets, &topic, &sink) {
                        all_done_log(&topic);
                        send_progress(&sink, &topic, scanned_count, total_to_scan).ok();
                        send_eof(&sink, &topic);
                        break;
                    }
                    last_eof_check_time = std::time::Instant::now();
                }

                let _found_match = process_and_send_message(
                    &msg,
                    &tokio_runtime,
                    &decoder,
                    key_is_avro,
                    value_is_avro,
                    &filter_terms,
                    &filter_field,
                    &filter_type,
                    search_scope,
                    &sink,
                    &mut matched_count,
                );
            }
            Some(Err(e)) => match e {
                rdkafka::error::KafkaError::PartitionEOF(_) => {
                    if !run_forever
                        && check_done(&consumer, &end_offsets, &current_offsets, &topic, &sink)
                    {
                        all_done_log(&topic);
                        send_progress(&sink, &topic, scanned_count, total_to_scan).ok();
                        send_eof(&sink, &topic);
                        break;
                    }
                }
                rdkafka::error::KafkaError::MessageConsumption(
                    rdkafka::types::RDKafkaErrorCode::OperationTimedOut,
                ) => {}
                _ => {
                    log_to_dart(&sink, format!("Kafka error during poll: {}", e));
                }
            },
            None => {
                if !run_forever
                    && check_done(&consumer, &end_offsets, &current_offsets, &topic, &sink)
                {
                    all_done_log(&topic);
                    send_progress(&sink, &topic, scanned_count, total_to_scan).ok();
                    send_eof(&sink, &topic);
                    break;
                }

                // Heartbeat
                let heartbeat_msg = KafkaMessage {
                    topic: topic.clone(),
                    partition: -1,
                    offset: -1,
                    key: None,
                    payload: Some(format!("__HEARTBEAT__:{}:{}", scanned_count, total_to_scan)),
                    timestamp: 0,
                    headers: None,
                };
                if let Err(e) = sink.add(heartbeat_msg) {
                    log_to_dart(
                        &sink,
                        format!("Sink closed (heartbeat), breaking. Error: {:?}", e),
                    );
                    break;
                }
            }
        }
    }
    Ok(())
}

fn send_progress(
    sink: &StreamSink<KafkaMessage>,
    topic: &str,
    scanned: u64,
    total: i64,
) -> Result<(), anyhow::Error> {
    let progress_msg = KafkaMessage {
        topic: topic.to_string(),
        partition: -1,
        offset: -1,
        key: None,
        payload: Some(format!("__PROGRESS__:{}:{}", scanned, total)),
        timestamp: 0,
        headers: None,
    };
    sink.add(progress_msg)
        .map_err(|e| anyhow::anyhow!("Sink Error: {:?}", e))
}

fn process_and_send_message<'a, M: KafkaMessageTrait>(
    msg: &M,
    tokio_runtime: &Runtime,
    decoder: &Option<SrDecoders<'a>>,
    key_is_avro: bool,
    value_is_avro: bool,
    filter_terms: &Option<Vec<String>>,
    filter_field: &Option<String>,
    filter_type: &FilterType,
    search_scope: SearchScope,
    sink: &StreamSink<KafkaMessage>,
    matched_count: &mut i32,
) -> bool {
    let payload = decode_message_component(
        tokio_runtime,
        decoder,
        msg.payload(),
        value_is_avro,
        "<Binary Data>",
    );

    let key = decode_message_component(
        tokio_runtime,
        decoder,
        msg.key(),
        key_is_avro,
        "<Binary Key>",
    );

    if !matches_filter(
        &key,
        &payload,
        filter_terms,
        filter_field,
        filter_type,
        search_scope,
        &None,
        &Some(sink.clone()),
    ) {
        return false;
    }

    use rdkafka::message::Headers;
    let headers = msg.headers().map(|headers| {
        let mut list = Vec::new();
        for i in 0..headers.count() {
            let header = headers.get(i);
            let key = header.key.to_string();
            let value = match header.value {
                Some(bytes) => match std::str::from_utf8(bytes) {
                    Ok(val_str) => val_str.to_string(),
                    Err(_) => format!("0x{}", hex::encode(bytes)),
                },
                None => "".to_string(),
            };
            list.push(kafkalyzer_core::kafka_types::KafkaHeader { key, value });
        }
        list
    });

    let kafka_msg = KafkaMessage {
        topic: msg.topic().to_string(),
        partition: msg.partition(),
        offset: msg.offset(),
        timestamp: msg.timestamp().to_millis().unwrap_or(0),
        key,
        payload,
        headers,
    };

    if let Err(_e) = sink.add(kafka_msg) {
        // log_to_dart(sink, format!("Sink closed (message send), match found but failed to send. Error: {:?}", e));
        return true; // it was a match, even if send failed
    }
    *matched_count += 1;
    true
}

fn all_done_log(topic: &str) {
    println!("All partitions done for topic {}", topic);
}

fn check_done(
    consumer: &BaseConsumer,
    end_offsets: &std::collections::HashMap<i32, i64>,
    current_offsets: &std::collections::HashMap<i32, i64>,
    topic: &str,
    _sink: &StreamSink<KafkaMessage>,
) -> bool {
    let mut all_done = true;
    let mut pending_partitions = Vec::new();

    // Optimize: Fetch position once for all partitions
    let positions = consumer.position().ok();

    for (p, high) in end_offsets {
        if *high == 0 {
            continue;
        }

        let mut part_done = false;

        // 1. Check actual consumer position (canonical truth)
        if let Some(ref pos_list) = positions {
            for elem in pos_list.elements() {
                if elem.partition() == *p {
                    if let rdkafka::Offset::Offset(curr_off) = elem.offset() {
                        if curr_off >= *high {
                            part_done = true;
                        }
                    }
                    break;
                }
            }
        }

        // 2. Fallback: Check manually tracked offsets (if position didn't confirm done)
        if !part_done {
            let tracked = *current_offsets.get(p).unwrap_or(&0);
            if tracked >= *high {
                part_done = true;
            }
        }

        // 3. Fallback: Check Watermarks (Empty/Expired partitions)
        if !part_done {
            // Use a short timeout to avoid stalling the loop significantly
            if let Ok((low, _)) =
                consumer.fetch_watermarks(topic, *p, std::time::Duration::from_millis(100))
            {
                if low >= *high {
                    part_done = true;
                }
            }
        }

        if !part_done {
            all_done = false;
            let _tracked = *current_offsets.get(p).unwrap_or(&0);
            pending_partitions.push(format!("P{}: tracked={}/high={}", p, _tracked, high));
        }
    }

    if !all_done && !pending_partitions.is_empty() {
        // log_to_dart(sink, format!("[{}] Waiting for partitions: {:?}", topic, pending_partitions));
    } else if all_done {
        // log_to_dart(sink, format!("[{}] All partitions done. Final check state:", topic));
        for (p, high) in end_offsets {
            if *high == 0 {
                continue;
            }
            let _tracked = *current_offsets.get(p).unwrap_or(&0);
            // let mut pos = rdkafka::Offset::Invalid;
            if let Some(ref l) = positions {
                for elem in l.elements() {
                    if elem.partition() == *p {
                        // pos = elem.offset();
                        break;
                    }
                }
            }
            // log_to_dart(sink, format!("  P{}: High={}, Tracked={}, ConsumerPos={:?}", p, high, tracked, pos));
        }
    }

    all_done
}

pub(crate) fn setup_schema_registry<'a>(
    tokio_runtime: &Runtime,
    sr_settings: &'a SrSettings,
    topic: &str,
) -> Result<(Option<SrDecoders<'a>>, bool, bool)> {
    let decoders = Some(SrDecoders {
        settings: sr_settings.clone(),
        avro: AvroDecoder::new(sr_settings.clone()),
        json: JsonDecoder::new(sr_settings.clone()),
        proto: ProtoDecoder::new(sr_settings.clone()),
    });

    let (key_avro, value_avro) = match tokio_runtime.block_on(get_all_subjects(sr_settings)) {
        Ok(subjects) => {
            let subjects_list: Vec<String> = subjects;
            let key_subject = format!("{}-key", topic);
            let value_subject = format!("{}-value", topic);
            (
                subjects_list.contains(&key_subject),
                subjects_list.contains(&value_subject),
            )
        }
        Err(error) => {
            println!(
                "Warning: Could not fetch subjects from Schema Registry: {}",
                error
            );
            (false, false)
        }
    };
    Ok((decoders, key_avro, value_avro))
}

fn setup_topic_assignment(
    consumer: &BaseConsumer,
    topic: &str,
    metadata: &rdkafka::metadata::Metadata,
    fast_trace_key: &Option<String>,
    start_partition: Option<i32>,
) -> Result<(rdkafka::TopicPartitionList, Option<i32>)> {
    let mut topic_partition_list = rdkafka::TopicPartitionList::new();
    let mut found_topic = false;
    let mut target_partition_id = start_partition;

    if let Some(key) = fast_trace_key {
        for topic_meta in metadata.topics() {
            if topic_meta.name() == topic {
                let partition_count = topic_meta.partitions().len();
                if partition_count > 0 {
                    let hash = to_positive(murmur2(key.as_bytes()));
                    let p_id = (hash % partition_count as u32) as i32;
                    println!(
                        "Fast Trace: Key '{}' hashes to {} % {} = Partition {}",
                        key, hash, partition_count, p_id
                    );
                    target_partition_id = Some(p_id);
                }
            }
        }
    }

    for topic_meta in metadata.topics() {
        if topic_meta.name() == topic {
            found_topic = true;
            for partition_meta in topic_meta.partitions() {
                if let Some(target) = target_partition_id {
                    if partition_meta.id() == target {
                        topic_partition_list.add_partition(topic, partition_meta.id());
                    }
                } else {
                    topic_partition_list.add_partition(topic, partition_meta.id());
                }
            }
        }
    }

    if !found_topic {
        return Err(anyhow::anyhow!("Topic {} not found", topic));
    }

    consumer
        .assign(&topic_partition_list)
        .map_err(|error| anyhow::anyhow!("Assign error: {}", error))?;

    Ok((topic_partition_list, target_partition_id))
}

fn fetch_partition_watermarks(
    consumer: &BaseConsumer,
    topic: &str,
    partitions: &[i32],
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) -> std::collections::HashMap<i32, (i64, i64)> {
    let mut watermarks = std::collections::HashMap::new();
    for &p in partitions {
        match consumer.fetch_watermarks(topic, p, timeout) {
            Ok((low, high)) => {
                watermarks.insert(p, (low, high));
            }
            Err(e) => {
                log_to_dart(
                    sink,
                    format!("Error fetching watermarks for partition {}: {}", p, e),
                );
            }
        }
    }
    watermarks
}

fn resolve_start_offsets(
    consumer: &BaseConsumer,
    topic: &str,
    watermarks: &std::collections::HashMap<i32, (i64, i64)>,
    start_offset: Option<i64>,
    start_timestamp: Option<i64>,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) -> Result<std::collections::HashMap<i32, i64>> {
    if let Some(timestamp) = start_timestamp {
        return resolve_start_offsets_for_timestamp(
            consumer, topic, watermarks, timestamp, timeout, sink,
        );
    }

    let mut actual_start_offsets = std::collections::HashMap::new();
    for (&partition, &(low, high)) in watermarks {
        let resolved = start_offset_from_watermarks(start_offset, low, high);
        if let Some(offset) = start_offset {
            if offset < low {
                log_to_dart(
                    sink,
                    format!(
                        "Offset {} is below low watermark {}, adjusting to {}",
                        offset, low, low
                    ),
                );
            }
        }
        actual_start_offsets.insert(partition, resolved);
    }
    Ok(actual_start_offsets)
}

fn resolve_start_offsets_for_timestamp(
    consumer: &BaseConsumer,
    topic: &str,
    watermarks: &std::collections::HashMap<i32, (i64, i64)>,
    timestamp: i64,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) -> Result<std::collections::HashMap<i32, i64>> {
    let mut tpl_for_times = rdkafka::TopicPartitionList::new();
    for &partition in watermarks.keys() {
        tpl_for_times.add_partition_offset(
            topic,
            partition,
            rdkafka::Offset::from_raw(timestamp),
        )?;
    }

    match consumer.offsets_for_times(tpl_for_times, timeout) {
        Ok(offsets) => {
            let mut actual_start_offsets = std::collections::HashMap::new();
            for elem in offsets.elements() {
                let p_id = elem.partition();
                let resolved = match elem.offset() {
                    rdkafka::Offset::Offset(raw) => raw,
                    _ => watermark_high(watermarks, p_id),
                };
                actual_start_offsets.insert(p_id, resolved);
            }
            Ok(actual_start_offsets)
        }
        Err(error) => {
            log_to_dart(
                sink,
                format!("Error fetching start offsets for times: {}", error),
            );
            Err(anyhow::anyhow!("Error fetching start offsets: {}", error))
        }
    }
}

fn apply_start_seeks(
    consumer: &BaseConsumer,
    topic: &str,
    start_offsets: &std::collections::HashMap<i32, i64>,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) {
    for (&partition, &offset) in start_offsets {
        if let Err(error) = seek_with_retry(
            consumer,
            topic,
            partition,
            rdkafka::Offset::Offset(offset),
            timeout,
            sink,
        ) {
            log_to_dart(
                sink,
                format!(
                    "Error seeking to offset {} in partition {}: {}",
                    offset, partition, error
                ),
            );
        }
    }
}

fn calculate_end_offsets(
    consumer: &BaseConsumer,
    metadata: &rdkafka::metadata::Metadata,
    topic: &str,
    topic_partition_list: &rdkafka::TopicPartitionList,
    watermarks: &std::collections::HashMap<i32, (i64, i64)>,
    _run_forever: bool,
    end_offset: Option<i64>,
    end_timestamp: Option<i64>,
    target_partition_id: Option<i32>,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) -> Result<std::collections::HashMap<i32, i64>> {
    let mut end_offsets: std::collections::HashMap<i32, i64> = std::collections::HashMap::new();

    if let Some(end_timestamp_val) = end_timestamp {
        let mut tpl_for_end = rdkafka::TopicPartitionList::new();
        for topic_meta in metadata.topics() {
            if topic_meta.name() == topic {
                for partition_meta in topic_meta.partitions() {
                    if let Some(target) = target_partition_id {
                        if partition_meta.id() != target {
                            continue;
                        }
                    }
                    tpl_for_end.add_partition_offset(
                        topic,
                        partition_meta.id(),
                        rdkafka::Offset::Offset(end_timestamp_val),
                    )?;
                }
            }
        }
        match consumer.offsets_for_times(tpl_for_end, timeout) {
            Ok(offsets) => {
                for elem in offsets.elements() {
                    match elem.offset() {
                        rdkafka::Offset::Offset(offset) => {
                            end_offsets.insert(elem.partition(), offset);
                        }
                        _ => {
                            end_offsets.insert(
                                elem.partition(),
                                watermark_high(watermarks, elem.partition()),
                            );
                        }
                    }
                }
            }
            Err(error) => log_to_dart(sink, format!("Error fetching end offsets: {}", error)),
        }
    } else if let Some(end_offset_val) = end_offset {
        for topic_meta in metadata.topics() {
            if topic_meta.name() == topic {
                for partition_meta in topic_meta.partitions() {
                    if let Some(target) = target_partition_id {
                        if partition_meta.id() != target {
                            continue;
                        }
                    }
                    end_offsets.insert(partition_meta.id(), end_offset_val);
                }
            }
        }
    } else {
        for partition_item in topic_partition_list.elements() {
            let p_id = partition_item.partition();
            end_offsets.insert(p_id, watermark_high(watermarks, p_id));
        }
    }
    log_to_dart(sink, format!("End Offsets: {:?}", end_offsets));
    Ok(end_offsets)
}

pub(crate) fn decode_message_component<'a>(
    tokio_runtime: &Runtime,
    decoders: &Option<SrDecoders<'a>>,
    data: Option<&[u8]>,
    has_schema: bool,
    binary_placeholder: &str,
) -> Option<String> {
    let bytes = data?;

    let mut decoded_val = None;
    if has_schema {
        if let Some(ref sr_decoders) = decoders {
            if bytes.len() >= 5 && bytes[0] == 0 {
                let mut id_bytes = [0u8; 4];
                id_bytes.copy_from_slice(&bytes[1..5]);
                let schema_id = u32::from_be_bytes(id_bytes);

                let schema_future =
                    schema_registry_converter::async_impl::schema_registry::get_schema_by_id(
                        schema_id,
                        &sr_decoders.settings,
                    );
                if let Ok(registered_schema) = tokio_runtime.block_on(schema_future) {
                    match registered_schema.schema_type {
                        schema_registry_converter::schema_registry_common::SchemaType::Avro => {
                            let future = sr_decoders.avro.decode_with_schema(Some(bytes));
                            if let Ok(Some(decoded_result)) = tokio_runtime.block_on(future) {
                                let schema = &decoded_result.schema.parsed;
                                let mut resolved_schemas = std::collections::HashMap::new();
                                kafkalyzer_core::avro_utils::extract_named_schemas(
                                    schema,
                                    &mut resolved_schemas,
                                );
                                if let Ok(json_val) =
                                    kafkalyzer_core::avro_utils::convert_avro_value(
                                        &decoded_result.value,
                                        Some(schema),
                                        &resolved_schemas,
                                    )
                                {
                                    if let Ok(json) = serde_json::to_string_pretty(&json_val) {
                                        decoded_val = Some(json);
                                    }
                                }
                            }
                        }
                        schema_registry_converter::schema_registry_common::SchemaType::Json => {
                            let future = sr_decoders.json.decode(Some(bytes));
                            if let Ok(Some(decoded_result)) = tokio_runtime.block_on(future) {
                                if let Ok(json) =
                                    serde_json::to_string_pretty(&decoded_result.value)
                                {
                                    decoded_val = Some(json);
                                }
                            }
                        }
                        schema_registry_converter::schema_registry_common::SchemaType::Protobuf => {
                            let future = sr_decoders.proto.decode_with_context(Some(bytes));
                            if let Ok(Some(decoded_result)) = tokio_runtime.block_on(future) {
                                let json_val = convert_protofish_message(
                                    &decoded_result.value,
                                    &decoded_result.context.context,
                                );
                                if let Ok(json) = serde_json::to_string_pretty(&json_val) {
                                    decoded_val = Some(json);
                                }
                            }
                        }
                        _ => {}
                    }
                }
            }
        }
    }

    if decoded_val.is_some() {
        decoded_val
    } else {
        match std::str::from_utf8(bytes) {
            Ok(string_val) => Some(string_val.to_string()),
            Err(_) => {
                let hex_str = hex::encode(bytes);
                Some(format!("{}:{}", binary_placeholder, hex_str))
            }
        }
    }
}

fn matches_filter(
    key_str: &Option<String>,
    payload_str: &Option<String>,
    filter_terms: &Option<Vec<String>>,
    filter_field: &Option<String>,
    filter_type: &FilterType,
    search_scope: SearchScope,
    regex_pattern: &Option<Regex>,
    sink: &Option<StreamSink<KafkaMessage>>,
) -> bool {
    let terms = match filter_terms {
        Some(t) if !t.is_empty() => t,
        _ => return true,
    };

    let check_match = |content: &str| -> bool {
        let target_val = if let Some(field) = filter_field {
            if let Ok(json) = serde_json::from_str::<serde_json::Value>(content) {
                let ptr = if field.starts_with('/') {
                    field.clone()
                } else {
                    format!("/{}", field)
                };
                if let Some(val) = json.pointer(&ptr) {
                    match val {
                        serde_json::Value::String(s) => s.clone(),
                        _ => val.to_string(),
                    }
                } else {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            content.to_string()
        };

        for term in terms {
            let matched = match filter_type {
                FilterType::Regex => {
                    if let Some(re) = regex_pattern {
                        re.is_match(&target_val)
                    } else if let Ok(re) = Regex::new(term) {
                        re.is_match(&target_val)
                    } else {
                        target_val.contains(term)
                    }
                }
                FilterType::Contains => target_val.contains(term),
                FilterType::Exact => {
                    let trimmed = target_val.trim();
                    trimmed == term
                }
            };
            if matched {
                if let Some(s) = sink {
                    log_to_dart(s, format!("MATCH FOUND! Type: {:?}, Term: '{}', Term Bytes: {:?}, Target: '{}', Target Bytes: {:?}, Key: '{:?}', Key Bytes: {:?}", 
                        filter_type, term, term.as_bytes(), target_val, target_val.as_bytes(), key_str, key_str.as_ref().map(|k| k.as_bytes())));
                }
                return true;
            }
        }
        false
    };

    if search_scope == SearchScope::Key || search_scope == SearchScope::Both {
        if let Some(key) = key_str {
            if check_match(key) {
                return true;
            }
        }
    }

    if search_scope == SearchScope::Value || search_scope == SearchScope::Both {
        if let Some(payload) = payload_str {
            if check_match(payload) {
                return true;
            }
        }
    }

    false
}

#[cfg(test)]
mod tests {
    use super::*;

    // Mock sink not easily available for unit tests without boilerplate.
    // We will bypass sink requirement for tests or mock it if necessary.
    // However, since we changed the signature, we MUST update call sites and tests.

    // Helper to create a dummy sink or ignore usage in tests?
    // Actually, `matches_filter` now requires a sink.
    // We should probably pass `Option<&StreamSink>` to make it easier for tests or just pass the sink.
    // But `StreamSink` is from `frb_generated`.
    // Let's modify matches_filter to take `Option<&StreamSink<KafkaMessage>>` to avoid test breakage?
    // No, tests need to pass something.
    // For unit tests in `rust`, mocking `StreamSink` is hard.
    // That's cleaner.

    #[test]
    fn test_matches_filter_exact_with_newline() {
        let key = Some("foo\n".to_string());
        let payload = None;
        let terms = Some(vec!["foo".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        assert!(matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_matches_filter_exact_strict() {
        let key = Some("foo".to_string());
        let payload = None;
        let terms = Some(vec!["foo".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        assert!(matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_matches_filter_exact_quoted_json_vs_raw() {
        let key = Some("\"foo\"".to_string()); // JSON string "foo"
        let payload = None;
        let terms = Some(vec!["foo".to_string()]); // Raw search term foo
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        // SHOULD FAIL: "foo" != foo
        assert!(!matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_matches_filter_exact_quoted_json_vs_quoted() {
        let key = Some("\"foo\"".to_string());
        let payload = None;
        let terms = Some(vec!["\"foo\"".to_string()]); // Search term includes quotes
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        // SHOULD PASS: "foo" == "foo"
        assert!(matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_matches_filter_exact_manual_unquote() {
        // "foo" (manually quoted) vs foo
        let key = Some("\"foo\"".to_string());
        let payload = None;
        let terms = Some(vec!["foo".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        // SHOULD FAIL: "foo" != foo
        assert!(!matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_matches_filter_exact_invalid_json_quoted() {
        // "bad\escape" -> invalid JSON because \e is not a valid escape (usually) or just raw backslash
        // If we treat it as raw string inside quotes: bad\escape
        let key = Some("\"bad\\escape\"".to_string());
        let payload = None;
        let terms = Some(vec!["bad\\escape".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        // SHOULD FAIL: "bad\escape" != bad\escape
        assert!(!matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_matches_filter_exact_mismatch() {
        let key = Some("bar".to_string());
        let payload = None;
        let terms = Some(vec!["foo".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        assert!(!matches_filter(
            &key,
            &payload,
            &terms,
            &field,
            &FilterType::Exact,
            scope,
            &regex,
            &None
        ));
    }

    #[test]
    fn test_convert_avro_value_decimal() {
        // Construct Decimal manually: 123
        let decimal =
            apache_avro::types::Value::Decimal(apache_avro::Decimal::from(vec![0x00, 0x7B]));
        let map = std::collections::HashMap::new();
        let json = match kafkalyzer_core::avro_utils::convert_avro_value(&decimal, None, &map) {
            Ok(j) => j,
            Err(e) => panic!("Should convert: {}", e),
        };

        match json {
            serde_json::Value::Number(n) => assert_eq!(n.as_i64(), Some(123)),
            serde_json::Value::String(s) => assert_eq!(s, "123"),
            _ => panic!("Expected Number or String for Decimal, got {:?}", json),
        }
    }

    #[test]
    fn test_convert_avro_value_nested() {
        let decimal =
            apache_avro::types::Value::Decimal(apache_avro::Decimal::from(vec![0x00, 0x7B]));
        let record = apache_avro::types::Value::Record(vec![("field".to_string(), decimal)]);

        // We test via convert_avro_value directly
        let map = std::collections::HashMap::new();
        let json = match kafkalyzer_core::avro_utils::convert_avro_value(&record, None, &map) {
            Ok(j) => j,
            Err(e) => panic!("Should convert: {}", e),
        };

        assert!(json.is_object());
        let obj = json.as_object().unwrap();
        assert!(obj.contains_key("field"));
        let val = obj.get("field").unwrap();
        match val {
            serde_json::Value::Number(n) => assert_eq!(n.as_i64(), Some(123)),
            serde_json::Value::String(s) => assert_eq!(s, "123"),
            _ => panic!(
                "Expected Number or String for nested Decimal, got {:?}",
                val
            ),
        }
    }

    #[test]
    fn test_calculate_total_to_scan_empty_and_bounded() {
        let mut start_offsets = std::collections::HashMap::new();
        start_offsets.insert(0, 0);
        start_offsets.insert(1, 0);

        let mut end_offsets = std::collections::HashMap::new();
        end_offsets.insert(0, 0);
        end_offsets.insert(1, 0);

        let mut tpl = rdkafka::TopicPartitionList::new();
        tpl.add_partition("test-topic", 0);
        tpl.add_partition("test-topic", 1);

        assert_eq!(
            calculate_total_to_scan(&tpl, &start_offsets, &end_offsets, None),
            0
        );

        end_offsets.insert(0, 150);
        end_offsets.insert(1, 200);
        assert_eq!(
            calculate_total_to_scan(&tpl, &start_offsets, &end_offsets, None),
            350
        );

        start_offsets.insert(0, 200);
        start_offsets.insert(1, 250);
        assert_eq!(
            calculate_total_to_scan(&tpl, &start_offsets, &end_offsets, None),
            0
        );
    }

    #[test]
    fn test_fast_path_empty_topic_earliest_start() {
        let mut watermarks = std::collections::HashMap::new();
        watermarks.insert(0, (0, 0));
        watermarks.insert(1, (0, 0));

        let mut start_offsets = std::collections::HashMap::new();
        let mut end_offsets = std::collections::HashMap::new();
        for (&partition, &(low, high)) in &watermarks {
            start_offsets.insert(partition, start_offset_from_watermarks(Some(0), low, high));
            end_offsets.insert(partition, high);
        }

        let mut tpl = rdkafka::TopicPartitionList::new();
        tpl.add_partition("empty-topic", 0);
        tpl.add_partition("empty-topic", 1);

        let total = calculate_total_to_scan(&tpl, &start_offsets, &end_offsets, None);
        assert_eq!(total, 0);
        assert!(should_fast_path_empty(false, total));
    }

    #[test]
    fn test_exhausted_offset_range_fast_path() {
        let start = start_offset_from_watermarks(Some(500), 0, 200);
        assert_eq!(start, 500);
        assert_eq!(range_to_scan(start, 200), 0);
        assert!(should_fast_path_empty(false, 0));
    }

    #[test]
    fn test_populated_topic_oldest_200_does_not_fast_path() {
        let mut watermarks = std::collections::HashMap::new();
        watermarks.insert(0, (0, 600));
        watermarks.insert(1, (0, 400));

        let mut start_offsets = std::collections::HashMap::new();
        let mut end_offsets = std::collections::HashMap::new();
        for (&partition, &(low, high)) in &watermarks {
            start_offsets.insert(partition, start_offset_from_watermarks(Some(0), low, high));
            end_offsets.insert(partition, high);
        }

        let mut tpl = rdkafka::TopicPartitionList::new();
        tpl.add_partition("populated-topic", 0);
        tpl.add_partition("populated-topic", 1);

        let total = calculate_total_to_scan(&tpl, &start_offsets, &end_offsets, None);
        assert_eq!(total, 1000);
        assert!(!should_fast_path_empty(false, total));
        assert!(should_stop_for_limit(200, Some(200)));
        assert!(!should_stop_for_limit(199, Some(200)));
    }

    #[test]
    fn test_live_streaming_does_not_fast_path_or_skip_new_messages() {
        assert!(!should_fast_path_empty(true, 0));
        assert!(!should_skip_beyond_end(true, 100, 100));
        assert!(should_skip_beyond_end(false, 100, 100));
        assert!(!should_skip_beyond_end(false, 99, 100));
    }

    #[test]
    fn test_start_offset_clamped_to_low_watermark() {
        assert_eq!(start_offset_from_watermarks(Some(0), 150, 200), 150);
        assert_eq!(start_offset_from_watermarks(Some(180), 150, 200), 180);
        assert_eq!(start_offset_from_watermarks(None, 150, 200), 200);
    }

    #[test]
    fn test_watermark_high_reuses_cached_map() {
        let mut watermarks = std::collections::HashMap::new();
        watermarks.insert(0, (10, 42));
        assert_eq!(watermark_high(&watermarks, 0), 42);
        assert_eq!(watermark_high(&watermarks, 7), 0);
    }
}

fn log_to_dart(sink: &StreamSink<KafkaMessage>, message: String) {
    println!("{}", message);
    let msg = KafkaMessage {
        topic: "".to_string(),
        partition: -1,
        offset: -1,
        key: None,
        payload: Some(format!("__LOG__:{}", message)),
        timestamp: 0,
        headers: None,
    };
    sink.add(msg).ok();
}

fn seek_with_retry(
    consumer: &BaseConsumer,
    topic: &str,
    partition: i32,
    offset: rdkafka::Offset,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) -> Result<(), rdkafka::error::KafkaError> {
    let mut last_error = None;
    for attempt in 1..=3 {
        match consumer.seek(topic, partition, offset, timeout) {
            Ok(_) => return Ok(()),
            Err(e) => {
                let msg = format!(
                    "Seek attempt {}/3 failed for {}-{}: {}",
                    attempt, topic, partition, e
                );
                log_to_dart(sink, msg);
                std::thread::sleep(std::time::Duration::from_millis(200));
                last_error = Some(e);
            }
        }
    }
    if let Some(e) = last_error {
        Err(e)
    } else {
        Ok(())
    }
}

fn send_eof(sink: &StreamSink<KafkaMessage>, topic: &str) {
    let eof_msg = KafkaMessage {
        topic: topic.to_string(),
        partition: -1,
        offset: -1,
        key: None,
        payload: Some("__EOF__".to_string()),
        timestamp: 0,
        headers: None,
    };
    let _ = sink.add(eof_msg);
}

fn convert_protofish_message(
    msg: &protofish::decode::MessageValue,
    context: &protofish::context::Context,
) -> serde_json::Value {
    let mut map = serde_json::Map::new();
    let message_info = context.resolve_message(msg.msg_ref);

    for field in &msg.fields {
        let field_name = message_info
            .get_field(field.number)
            .map(|f| f.name.clone())
            .unwrap_or_else(|| format!("field_{}", field.number));

        let json_val = convert_protofish_value(&field.value, context);
        map.insert(field_name, json_val);
    }
    serde_json::Value::Object(map)
}

fn convert_protofish_value(
    val: &protofish::decode::Value,
    context: &protofish::context::Context,
) -> serde_json::Value {
    use protofish::decode::Value;
    match val {
        Value::Double(v) => serde_json::json!(v),
        Value::Float(v) => serde_json::json!(v),
        Value::Int32(v) => serde_json::json!(v),
        Value::Int64(v) => serde_json::json!(v),
        Value::UInt32(v) => serde_json::json!(v),
        Value::UInt64(v) => serde_json::json!(v),
        Value::SInt32(v) => serde_json::json!(v),
        Value::SInt64(v) => serde_json::json!(v),
        Value::Fixed32(v) => serde_json::json!(v),
        Value::Fixed64(v) => serde_json::json!(v),
        Value::SFixed32(v) => serde_json::json!(v),
        Value::SFixed64(v) => serde_json::json!(v),
        Value::Bool(v) => serde_json::json!(v),
        Value::String(v) => serde_json::Value::String(v.clone()),
        Value::Bytes(v) => serde_json::Value::String(format!("0x{}", hex::encode(v))),
        Value::Message(msg) => convert_protofish_message(msg, context),
        Value::Enum(ev) => {
            let enum_info = context.resolve_enum(ev.enum_ref);
            let name = enum_info
                .get_field_by_value(ev.value)
                .map(|f| f.name.clone())
                .unwrap_or_else(|| ev.value.to_string());
            serde_json::Value::String(name)
        }
        Value::Packed(arr) => {
            use protofish::decode::PackedArray;
            match arr {
                PackedArray::Double(v) => serde_json::json!(v),
                PackedArray::Float(v) => serde_json::json!(v),
                PackedArray::Int32(v) => serde_json::json!(v),
                PackedArray::Int64(v) => serde_json::json!(v),
                PackedArray::UInt32(v) => serde_json::json!(v),
                PackedArray::UInt64(v) => serde_json::json!(v),
                PackedArray::SInt32(v) => serde_json::json!(v),
                PackedArray::SInt64(v) => serde_json::json!(v),
                PackedArray::Fixed32(v) => serde_json::json!(v),
                PackedArray::Fixed64(v) => serde_json::json!(v),
                PackedArray::SFixed32(v) => serde_json::json!(v),
                PackedArray::SFixed64(v) => serde_json::json!(v),
                PackedArray::Bool(v) => serde_json::json!(v),
            }
        }
        Value::Incomplete(_, bytes) => {
            serde_json::Value::String(format!("Incomplete: 0x{}", hex::encode(bytes)))
        }
        Value::Unknown(uk) => {
            use protofish::decode::UnknownValue;
            match uk {
                UnknownValue::Varint(v) => serde_json::json!(v.to_string()),
                UnknownValue::Fixed64(v) => serde_json::json!(v),
                UnknownValue::VariableLength(v) => {
                    serde_json::Value::String(format!("0x{}", hex::encode(v)))
                }
                UnknownValue::Fixed32(v) => serde_json::json!(v),
                UnknownValue::Invalid(_, bytes) => {
                    serde_json::Value::String(format!("Invalid: 0x{}", hex::encode(bytes)))
                }
            }
        }
    }
}
