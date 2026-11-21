use crate::api::kafka_types::{ClusterProfile, FilterType, SearchScope};
use crate::api::local_schema::{LocalSchemaUseDto, TopicLocalSchemasDto};
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
pub struct MessageSchema {
    pub schema_id: u32,
    pub subject: Option<String>,
    pub version: Option<i32>,
}

impl From<kafkalyzer_core::kafka_types::MessageSchema> for MessageSchema {
    fn from(schema: kafkalyzer_core::kafka_types::MessageSchema) -> Self {
        Self {
            schema_id: schema.schema_id,
            subject: schema.subject,
            version: schema.version,
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
    pub key_schema: Option<MessageSchema>,
    pub value_schema: Option<MessageSchema>,
    pub key_local_schema: Option<LocalSchemaUseDto>,
    pub value_local_schema: Option<LocalSchemaUseDto>,
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
            key_schema: msg.key_schema.map(MessageSchema::from),
            value_schema: msg.value_schema.map(MessageSchema::from),
            key_local_schema: msg.key_local_schema.map(LocalSchemaUseDto::from),
            value_local_schema: msg.value_local_schema.map(LocalSchemaUseDto::from),
        }
    }
}

/// One message-consumption request: what to read, how to filter it and when
/// to stop. Every criterion carries its own name, so a call site can no longer
/// exchange two optional values by position.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConsumeRequest {
    pub profile: ClusterProfile,
    pub topic: String,
    pub filter_terms: Option<Vec<String>>,
    pub filter_field: Option<String>,
    pub filter_type: FilterType,
    pub search_scope: SearchScope,
    pub filter_expression: Option<String>,
    pub filter_variables: Option<std::collections::HashMap<String, Vec<String>>>,
    pub start_offset: Option<i64>,
    pub start_timestamp: Option<i64>,
    pub start_partition: Option<i32>,
    pub fast_trace_key: Option<String>,
    pub end_offset: Option<i64>,
    pub end_timestamp: Option<i64>,
    pub max_results: Option<i32>,
    pub run_forever: bool,
    pub start_from_tail: Option<bool>,
    pub local_schemas: Option<TopicLocalSchemasDto>,
}

impl ConsumeRequest {
    /// The two shapes the scan works with: the criteria as asked for, and the
    /// offset window.
    fn into_domain(
        self,
    ) -> (
        kafkalyzer_kafka::kafka_consumer::ConsumeCriteria,
        kafkalyzer_kafka::kafka_consumer::ScanBounds,
    ) {
        (
            kafkalyzer_kafka::kafka_consumer::ConsumeCriteria {
                filter_terms: self.filter_terms,
                filter_field: self.filter_field,
                filter_type: self.filter_type.to_domain(),
                search_scope: self.search_scope.to_domain(),
                filter_expression: self.filter_expression,
                filter_variables: self.filter_variables,
                local_schemas: self.local_schemas.map(|ls| ls.to_domain()),
                fast_trace_key: self.fast_trace_key,
                start_partition: self.start_partition,
                max_results: self.max_results,
                run_forever: self.run_forever,
            },
            kafkalyzer_kafka::kafka_consumer::ScanBounds {
                start_offset: self.start_offset,
                start_timestamp: self.start_timestamp,
                end_offset: self.end_offset,
                end_timestamp: self.end_timestamp,
                start_from_tail: self.start_from_tail.unwrap_or(false),
            },
        )
    }
}

pub async fn consume_with_filter(
    request: ConsumeRequest,
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

    let domain_profile = request.profile.to_domain();
    let topic = request.topic.clone();
    let (criteria, bounds) = request.into_domain();

    tokio::task::spawn_blocking(move || {
        kafkalyzer_kafka::kafka_consumer::consume_with_filter(
            domain_profile,
            topic,
            criteria,
            bounds,
            kafka_sink,
        )
    })
    .await?
}
