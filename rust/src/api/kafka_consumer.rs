use crate::api::kafka_types::{ClusterProfile, FilterType, SearchScope};
use crate::frb_generated::StreamSink;
use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KafkaHeader {
    pub key: String,
    pub value: String,
}

impl From<kafkalyzer_core::kafka_types::KafkaHeader> for KafkaHeader {
    fn from(h: kafkalyzer_core::kafka_types::KafkaHeader) -> Self {
        Self {
            key: h.key,
            value: h.value,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KafkaMessage {
    pub topic: String,
    pub partition: i32,
    pub offset: i64,
    pub key: Option<String>,
    pub payload: Option<String>,
    pub timestamp: i64,
    pub headers: Option<Vec<KafkaHeader>>,
}

impl From<kafkalyzer_core::kafka_types::KafkaMessage> for KafkaMessage {
    fn from(msg: kafkalyzer_core::kafka_types::KafkaMessage) -> Self {
        Self {
            topic: msg.topic,
            partition: msg.partition,
            offset: msg.offset,
            key: msg.key,
            payload: msg.payload,
            timestamp: msg.timestamp,
            headers: msg
                .headers
                .map(|list| list.into_iter().map(KafkaHeader::from).collect()),
        }
    }
}

pub async fn consume_with_filter(
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
    let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();

    let sink_clone = sink.clone();
    tokio::spawn(async move {
        while let Some(msg) = rx.recv().await {
            let bridge_msg = KafkaMessage::from(msg);
            if sink_clone.add(bridge_msg).is_err() {
                break;
            }
        }
    });

    let kafka_sink = kafkalyzer_kafka::kafka_consumer::StreamSink::new(tx);

    let domain_profile = profile.to_domain();
    let domain_filter_type = filter_type.to_domain();
    let domain_search_scope = search_scope.to_domain();

    tokio::task::spawn_blocking(move || {
        kafkalyzer_kafka::kafka_consumer::consume_with_filter(
            domain_profile,
            topic,
            filter_terms,
            filter_field,
            domain_filter_type,
            domain_search_scope,
            start_offset,
            start_timestamp,
            start_partition,
            fast_trace_key,
            end_offset,
            end_timestamp,
            max_results,
            run_forever,
            kafka_sink,
        )
    })
    .await?
}
