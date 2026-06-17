use anyhow::Result;
use rdkafka::consumer::{BaseConsumer, Consumer};
use rdkafka::Message as KafkaMessageTrait;
use std::time::{SystemTime, UNIX_EPOCH};
use regex::Regex;
use schema_registry_converter::async_impl::schema_registry::{SrSettings, get_all_subjects};
use schema_registry_converter::async_impl::avro::AvroDecoder;

use tokio::runtime::Runtime;

use kafkalyzer_core::kafka_types::{ClusterProfile, FilterType, SearchScope, KafkaMessage};
use crate::kafka_utils::{create_config, murmur2, to_positive};

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
    let (decoder, key_is_avro, value_is_avro) = if let Some(ref settings) = sr_settings {
        setup_schema_registry(&tokio_runtime, settings, &topic)?
    } else {
        (None, false, false)
    };

    // 3. Create Consumer
    let consumer = create_consumer(&profile, start_offset.is_some() || start_timestamp.is_some())?;
    
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

    // 5. Initial Poll to stabilize
    for _ in 0..20 {
        consumer.poll(std::time::Duration::from_millis(100));
    }

    // 6. Handle Seek (Start Offsets)
    let start_offsets_map_result = if start_offset.is_some() || start_timestamp.is_some() {
        handle_seek_logic(
             &consumer, 
             &metadata, 
             &topic, 
             start_offset, 
             start_timestamp, 
             target_partition_id, 
             timeout, 
             &sink,
             &tokio_runtime,
             &decoder,
             key_is_avro,
             value_is_avro,
             &filter_terms,
             &filter_field,
             &filter_type,
             search_scope,
        )?
    } else {
        std::collections::HashMap::new()
    };

    // 7. Calculate End Offsets
    let end_offsets = calculate_end_offsets(
        &consumer,
        &metadata,
        &topic,
        &topic_partition_list,
        run_forever,
        end_offset,
        end_timestamp,
        target_partition_id,
        timeout,
        &sink,
    )?;

    // 8. Calculate Total to Scan
    let total_to_scan = calculate_total_to_scan(
        &consumer, 
        &topic_partition_list, 
        &start_offsets_map_result, 
        &end_offsets, 
        target_partition_id
    );

    // Send initial progress
    let initial_msg = KafkaMessage {
        topic: topic.clone(),
        partition: -1,
        offset: -1,
        key: None,
        payload: Some(format!("__PROGRESS__:0:{}", total_to_scan)),
        timestamp: 0,
    };
    sink.add(initial_msg).ok();

    // 9. Run Main Loop
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
        decoder,
        key_is_avro,
        value_is_avro,
        total_to_scan,
    )?;

    Ok(())
}

fn create_sr_settings(profile: &ClusterProfile) -> Option<SrSettings> {
    if let Some(url) = &profile.schema_registry_url {
        let mut sr_url = url.trim().to_string();
        if !sr_url.is_empty() && !sr_url.starts_with("http://") && !sr_url.starts_with("https://") {
            sr_url = format!("http://{}", sr_url);
        }
        if !sr_url.is_empty() {
             return Some(SrSettings::new(sr_url));
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

fn handle_seek_logic(
    consumer: &BaseConsumer,
    metadata: &rdkafka::metadata::Metadata,
    topic: &str,
    start_offset: Option<i64>,
    start_timestamp: Option<i64>,
    target_partition_id: Option<i32>,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
    tokio_runtime: &Runtime,
    decoder: &Option<AvroDecoder>,
    key_is_avro: bool,
    value_is_avro: bool,
    filter_terms: &Option<Vec<String>>,
    filter_field: &Option<String>,
    filter_type: &FilterType,
    search_scope: SearchScope,
) -> Result<std::collections::HashMap<i32, i64>> {
    // We poll a bit more to ensure the assignment is settled
    for _ in 0..5 {
        consumer.poll(std::time::Duration::from_millis(100));
    }

    let (start_offsets_map, initial_messages) = perform_seek(
        consumer,
        metadata,
        topic,
        start_offset,
        start_timestamp,
        target_partition_id,
        timeout,
        sink,
    )?;
    
    // Process any messages consumed during stabilization
    for msg in initial_messages {
         process_and_send_message(
             &msg, 
             tokio_runtime, 
             decoder, 
             key_is_avro, 
             value_is_avro, 
             filter_terms, 
             filter_field, 
             filter_type, 
             search_scope, 
             sink, 
             &mut 0 
         );
    }
    
    Ok(start_offsets_map)
}

fn calculate_total_to_scan(
    consumer: &BaseConsumer,
    topic_partition_list: &rdkafka::TopicPartitionList,
    start_offsets_map: &std::collections::HashMap<i32, i64>,
    end_offsets: &std::collections::HashMap<i32, i64>,
    target_partition_id: Option<i32>,
) -> i64 {
    let mut total_to_scan: i64 = 0;
    
    // Get unique partitions from assignment
    let mut all_partitions = std::collections::HashSet::new();
    for elem in topic_partition_list.elements() { all_partitions.insert(elem.partition()); }
    
    let current_positions = consumer.position().ok();

    for p in all_partitions {
        if let Some(target) = target_partition_id {
            if p != target { continue; }
        }
        
        let end = match end_offsets.get(&p) {
            Some(e) => *e,
            None => continue, 
        };

        let start = if let Some(s) = start_offsets_map.get(&p) {
            *s
        } else {
            let mut pos = 0;
            if let Some(ref list) = current_positions {
                for elem in list.elements() {
                    if elem.partition() == p {
                         if let rdkafka::Offset::Offset(o) = elem.offset() {
                             pos = o;
                         }
                         break;
                    }
                }
            }
            pos
        };

        if end > start {
            total_to_scan += end - start;
        }
    }
    total_to_scan
}

fn run_poll_loop(
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
    decoder: Option<AvroDecoder>,
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
        if let Some(limit) = max_results {
            if matched_count >= limit {
                log_to_dart(&sink, format!("Max results limit ({}) reached. Stopping.", limit));
                send_progress(&sink, &topic, scanned_count, total_to_scan).ok();
                send_eof(&sink, &topic);
                break;
            }
        }
        
        // Log every 5000 messages
        if scanned_count > 0 && scanned_count % 5000 == 0 {
             log_to_dart(&sink, format!("Scanned {} messages.", scanned_count));
        }

        match consumer.poll(std::time::Duration::from_millis(200)) {
            Some(Ok(msg)) => {
                 if let Some(target_end_offset) = end_offsets.get(&msg.partition()) {
                     if msg.offset() >= *target_end_offset {
                          current_offsets.insert(msg.partition(), msg.offset() + 1);
                          continue; // Skip processing and emitting messages beyond boundary
                     }
                 }

                 scanned_count += 1;
                 current_offsets.insert(msg.partition(), msg.offset() + 1);

                 if last_report_time.elapsed().as_millis() > 500 {
                       if let Err(e) = send_progress(&sink, &topic, scanned_count, total_to_scan) {
                           log_to_dart(&sink, format!("Sink closed (progress), breaking loop. Error: {:?}", e));
                           break; 
                       }
                       last_report_time = std::time::Instant::now();
                 }

                 if !run_forever && last_eof_check_time.elapsed().as_secs() >= 1 {
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
                     &mut matched_count
                 );
                 
            }
            Some(Err(e)) => {
                match e {
                    rdkafka::error::KafkaError::PartitionEOF(_) => {}, // Handled by check_done
                    rdkafka::error::KafkaError::MessageConsumption(rdkafka::types::RDKafkaErrorCode::OperationTimedOut) => {},
                    _ => {
                        log_to_dart(&sink, format!("Kafka error during poll: {}", e));
                    }
                }
            }
            None => {
                 if !run_forever && last_eof_check_time.elapsed().as_secs() >= 1 {
                     if check_done(&consumer, &end_offsets, &current_offsets, &topic, &sink) {
                         all_done_log(&topic);
                         send_progress(&sink, &topic, scanned_count, total_to_scan).ok();
                         send_eof(&sink, &topic);
                         break;
                     }
                     last_eof_check_time = std::time::Instant::now();
                 }
                
                 // Heartbeat
                 let heartbeat_msg = KafkaMessage {
                      topic: topic.clone(),
                      partition: -1, 
                      offset: -1,
                      key: None,
                      payload: Some(format!("__HEARTBEAT__:{}:{}", scanned_count, total_to_scan)),
                      timestamp: 0,
                 };
                 if let Err(e) = sink.add(heartbeat_msg) { 
                     log_to_dart(&sink, format!("Sink closed (heartbeat), breaking. Error: {:?}", e));
                     break; 
                 }
            }
        }
    }
    Ok(())
}

fn send_progress(sink: &StreamSink<KafkaMessage>, topic: &str, scanned: u64, total: i64) -> Result<(), anyhow::Error> {
    let progress_msg = KafkaMessage {
        topic: topic.to_string(),
        partition: -1,
        offset: -1,
        key: None,
        payload: Some(format!("__PROGRESS__:{}:{}", scanned, total)),
        timestamp: 0,
    };
    sink.add(progress_msg).map_err(|e| anyhow::anyhow!("Sink Error: {:?}", e))
}

fn process_and_send_message<M: KafkaMessageTrait>(
    msg: &M,
    tokio_runtime: &Runtime,
    decoder: &Option<AvroDecoder>,
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

     let kafka_msg = KafkaMessage {
         topic: msg.topic().to_string(),
         partition: msg.partition(),
         offset: msg.offset(),
         timestamp: msg.timestamp().to_millis().unwrap_or(0),
         key,
         payload,
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
        if *high == 0 { continue; }
        
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
             if let Ok((low, _)) = consumer.fetch_watermarks(topic, *p, std::time::Duration::from_millis(100)) {
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
             if *high == 0 { continue; }
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

fn setup_schema_registry<'a>(
    tokio_runtime: &Runtime,
    sr_settings: &'a SrSettings,
    topic: &str,
) -> Result<(Option<AvroDecoder<'a>>, bool, bool)> {
    let decoder = Some(AvroDecoder::new(sr_settings.clone()));

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
    Ok((decoder, key_avro, value_avro))
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

fn perform_seek(
    consumer: &BaseConsumer,
    metadata: &rdkafka::metadata::Metadata,
    topic: &str,
    start_offset: Option<i64>,
    start_timestamp: Option<i64>,
    target_partition_id: Option<i32>,
    timeout: std::time::Duration,
    sink: &StreamSink<KafkaMessage>,
) -> Result<(std::collections::HashMap<i32, i64>, Vec<rdkafka::message::OwnedMessage>)> {
    let mut actual_start_offsets = std::collections::HashMap::new();

    if let Some(timestamp) = start_timestamp {
        // log_to_dart(sink, format!("Seeking to timestamp: {}", timestamp));
        let mut tpl_for_times = rdkafka::TopicPartitionList::new();
        for topic_meta in metadata.topics() {
            if topic_meta.name() == topic {
                for partition_meta in topic_meta.partitions() {
                    if let Some(target) = target_partition_id {
                        if partition_meta.id() != target {
                            continue;
                        }
                    }
                    tpl_for_times.add_partition_offset(
                        topic,
                        partition_meta.id(),
                        rdkafka::Offset::from_raw(timestamp),
                    )?;
                }
            }
        }
        match consumer.offsets_for_times(tpl_for_times, timeout) {
            Ok(offsets) => {
                let mut assigned_offsets = rdkafka::TopicPartitionList::new();
                
                for elem in offsets.elements() {
                     let p_topic = elem.topic();
                     let p_id = elem.partition();
                     let p_offset = elem.offset();

                     let final_offset = match p_offset {
                         rdkafka::Offset::Offset(raw) => {
                             // log_to_dart(sink, format!("Resolved offset for timestamp {}: partition {}, offset {}", timestamp, p_id, raw));
                             rdkafka::Offset::Offset(raw)
                         },
                         _ => {
                             // Invalid/Not Found -> Assume Future -> Seek to End
                             match consumer.fetch_watermarks(p_topic, p_id, timeout) {
                                 Ok((_low, high)) => {
                                     // log_to_dart(sink, format!("Timestamp {} unresolved for partition {}-{} (likely in future). Defaulting to High Watermark: {}", timestamp, p_topic, p_id, high));
                                     rdkafka::Offset::Offset(high)
                                 },
                                 Err(_e) => {
                                     // log_to_dart(sink, format!("Failed to fetch watermarks for {}-{}: {}. Keeping original offset {:?}", p_topic, p_id, e, p_offset));
                                     p_offset
                                 }
                             }
                         }
                     };
                     
                     if let rdkafka::Offset::Offset(o) = final_offset {
                         actual_start_offsets.insert(p_id, o);
                     }
                     
                     assigned_offsets.add_partition_offset(p_topic, p_id, final_offset)?;
                }

                consumer.assign(&assigned_offsets).map_err(|e| anyhow::anyhow!("Assign error after offsets_for_times: {}", e))?;
                
                // CRITICAL: Poll to ensure assignment is active before seeking
                let mut initial_messages = Vec::new();
                match consumer.poll(std::time::Duration::from_millis(200)) {
                    Some(Ok(m)) => {
                        // log_to_dart(sink, format!("Consumed message during stabilization: Partition {} Offset {}", m.partition(), m.offset()));
                        initial_messages.push(m.detach());
                    },
                    Some(Err(e)) => log_to_dart(sink, format!("Error during stabilization poll: {}", e)),
                    None => {}
                }

                for elem in assigned_offsets.elements() {
                    if let rdkafka::Offset::Offset(offset) = elem.offset() {
                        if let Err(error) = seek_with_retry(
                            consumer,
                            elem.topic(),
                            elem.partition(),
                            rdkafka::Offset::Offset(offset),
                            timeout,
                            sink
                        ) {
                            log_to_dart(sink, format!(
                                "Error seeking to timestamp in partition {}: {}",
                                elem.partition(),
                                error
                            ));
                        }
                    }
                }
                
                return Ok((actual_start_offsets, initial_messages));
            }
            Err(error) => {
                 log_to_dart(sink, format!("Error fetching start offsets for times: {}", error));
                 return Err(anyhow::anyhow!("Error fetching start offsets: {}", error));
            }
        }
    } else if let Some(offset) = start_offset {
        // log_to_dart(sink, format!("Seeking to explicit offset: {}", offset));
        for topic_meta in metadata.topics() {
            if topic_meta.name() == topic {
                for partition_meta in topic_meta.partitions() {
                    if let Some(target) = target_partition_id {
                        if partition_meta.id() != target {
                            continue;
                        }
                    }
                    let mut target_offset = offset;
                    match consumer.fetch_watermarks(topic, partition_meta.id(), timeout) {
                        Ok((low, _high)) => {
                            if offset < low {
                                log_to_dart(sink, format!("Offset {} is below low watermark {}, adjusting to {}", offset, low, low));
                                target_offset = low;
                            }
                        }
                        Err(error) => log_to_dart(sink, format!(
                            "Error fetching watermarks for partition {}: {}",
                            partition_meta.id(),
                            error
                        )),
                    }
                    
                    actual_start_offsets.insert(partition_meta.id(), target_offset);

                    if let Err(error) = seek_with_retry(
                        consumer,
                        topic,
                        partition_meta.id(),
                        rdkafka::Offset::Offset(target_offset),
                        timeout,
                        sink
                    ) {
                        log_to_dart(sink, format!(
                            "Error seeking to offset {} in partition {}: {}",
                            target_offset,
                            partition_meta.id(),
                            error
                        ));
                    } else {
                        // log_to_dart(sink, format!("Successfully sought to offset {} in partition {}", target_offset, partition_meta.id()));
                    }
                }
            }
        }
    }
    Ok((actual_start_offsets, Vec::new()))
}

fn calculate_end_offsets(
    consumer: &BaseConsumer,
    metadata: &rdkafka::metadata::Metadata,
    topic: &str,
    topic_partition_list: &rdkafka::TopicPartitionList,
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
                        rdkafka::Offset::End => {
                            // The requested timestamp is beyond the latest message in this partition.
                            // We should consume up to the High Watermark instead.
                            if let Ok((_low, high)) = consumer.fetch_watermarks(elem.topic(), elem.partition(), timeout) {
                                end_offsets.insert(elem.partition(), high);
                            }
                        }
                        _ => {
                            // Invalid offset or not found, default to high watermark
                            if let Ok((_low, high)) = consumer.fetch_watermarks(elem.topic(), elem.partition(), timeout) {
                                end_offsets.insert(elem.partition(), high);
                            }
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
        let metadata_timeout = std::time::Duration::from_secs(5);
        for partition_item in topic_partition_list.elements() {
            match consumer.fetch_watermarks(topic, partition_item.partition(), metadata_timeout)
            {
                Ok((_low, high)) => {
                    end_offsets.insert(partition_item.partition(), high);
                }
                Err(error) => log_to_dart(sink, format!(
                    "Error fetching watermarks for partition {}: {}",
                    partition_item.partition(),
                    error
                )),
            }
        }
    }
    log_to_dart(sink, format!("End Offsets: {:?}", end_offsets));
    Ok(end_offsets)
}

fn decode_message_component<'a>(
    tokio_runtime: &Runtime,
    decoder: &Option<AvroDecoder<'a>>,
    data: Option<&[u8]>,
    is_avro: bool,
    binary_placeholder: &str,
) -> Option<String> {
    let bytes = data?;

    let mut decoded_val = None;
    if is_avro {
        if let Some(avro_decoder) = decoder {
            // Use decode_with_schema to get the schema alongside the value
            let future = avro_decoder.decode_with_schema(Some(bytes));
            if let Ok(Some(decoded_result)) = tokio_runtime.block_on(future) {
                 // decoded_result has .value and .schema (Arc<AvroSchema>)
                 // AvroSchema wraps apache_avro::Schema in .parsed
                 let schema = &decoded_result.schema.parsed;
                 
                 let mut resolved_schemas = std::collections::HashMap::new();
                 kafkalyzer_core::avro_utils::extract_named_schemas(schema, &mut resolved_schemas);

                 match kafkalyzer_core::avro_utils::convert_avro_value(&decoded_result.value, Some(schema), &resolved_schemas) {
                     Ok(json_val) => {
                         match serde_json::to_string_pretty(&json_val) {
                             Ok(json) => decoded_val = Some(json),
                             Err(err) => {
                                 println!("Error serializing JSON: {}", err);
                                 decoded_val = Some(format!("{:?}", decoded_result.value));
                             }
                         }
                     },
                     Err(err) => {
                         println!("Error converting Avro to JsonValue: {}", err);
                         decoded_val = Some(format!("{:?}", decoded_result.value));
                     }
                 }
            } else {
                 // Fallback if decode_with_schema fails or returns None?
                 // Trying standard decode if needed, but decode_with_schema handles it.
                 // If it failed, let's treat as binary/fail.
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
                let ptr = if field.starts_with('/') { field.clone() } else { format!("/{}", field) };
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
                    } else {
                         if let Ok(re) = Regex::new(term) {
                             re.is_match(&target_val)
                         } else {
                             target_val.contains(term)
                         }
                    }
                }
                FilterType::Contains => target_val.contains(term),
                FilterType::Exact => {
                    let trimmed = target_val.trim();
                    trimmed == term
                },
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
            if check_match(key) { return true; }
        }
    }

    if search_scope == SearchScope::Value || search_scope == SearchScope::Both {
        if let Some(payload) = payload_str {
            if check_match(payload) { return true; }
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

        assert!(matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
    }

    #[test]
    fn test_matches_filter_exact_strict() {
        let key = Some("foo".to_string());
        let payload = None;
        let terms = Some(vec!["foo".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        assert!(matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
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
        assert!(!matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
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
        assert!(matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
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
        assert!(!matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
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
        assert!(!matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
    }

    #[test]
    fn test_matches_filter_exact_mismatch() {
        let key = Some("bar".to_string());
        let payload = None;
        let terms = Some(vec!["foo".to_string()]);
        let field = None;
        let scope = SearchScope::Key;
        let regex = None;

        assert!(!matches_filter(&key, &payload, &terms, &field, &FilterType::Exact, scope, &regex, &None));
    }

    #[test]
    fn test_convert_avro_value_decimal() {
        // Construct Decimal manually: 123
        let decimal = apache_avro::types::Value::Decimal(apache_avro::Decimal::from(vec![0x00, 0x7B]));
        let map = std::collections::HashMap::new();
        let json = kafkalyzer_core::avro_utils::convert_avro_value(&decimal, None, &map).expect("Should convert");
        
        match json {
            serde_json::Value::Number(n) => assert_eq!(n.as_i64(), Some(123)),
            serde_json::Value::String(s) => assert_eq!(s, "123"),
            _ => panic!("Expected Number or String for Decimal, got {:?}", json),
        }
    }

    #[test]
    fn test_convert_avro_value_nested() {
        let decimal = apache_avro::types::Value::Decimal(apache_avro::Decimal::from(vec![0x00, 0x7B]));
        let record = apache_avro::types::Value::Record(vec![("field".to_string(), decimal)]);
        
        // We test via convert_avro_value directly
        let map = std::collections::HashMap::new();
        let json = kafkalyzer_core::avro_utils::convert_avro_value(&record, None, &map).expect("Should convert");
        
        assert!(json.is_object());
        let obj = json.as_object().unwrap();
        assert!(obj.contains_key("field"));
        let val = obj.get("field").unwrap();
         match val {
            serde_json::Value::Number(n) => assert_eq!(n.as_i64(), Some(123)),
            serde_json::Value::String(s) => assert_eq!(s, "123"),
            _ => panic!("Expected Number or String for nested Decimal, got {:?}", val),
        }
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
    };
    sink.add(msg).ok();
}

fn seek_with_retry(
    consumer: &BaseConsumer, 
    topic: &str, 
    partition: i32, 
    offset: rdkafka::Offset, 
    timeout: std::time::Duration, 
    sink: &StreamSink<KafkaMessage>
) -> Result<(), rdkafka::error::KafkaError> {
    let mut last_error = None;
    for attempt in 1..=3 {
        match consumer.seek(topic, partition, offset, timeout) {
            Ok(_) => return Ok(()),
            Err(e) => {
                let msg = format!("Seek attempt {}/3 failed for {}-{}: {}", attempt, topic, partition, e);
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
       };
       let _ = sink.add(eof_msg);
}