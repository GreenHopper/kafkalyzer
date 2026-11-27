//! Shared mapping for consume / search message tools.

use kafkalyzer_core::kafka_types::{FilterType, KafkaMessage, MessageSchema, SearchScope};
use kafkalyzer_kafka::bounded::{CollectStop, CollectedMessage, CollectedMessages};
use kafkalyzer_kafka::kafka_consumer::ScanBounds;
use kafkalyzer_kafka::kafka_metadata::{TopicMetadata, TopicMetadataErrorKind};
use serde::Serialize;

use super::ToolError;
use crate::shape::{CappedText, StopReason};

/// Where a consume/search starts reading.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ConsumePosition {
    Oldest,
    Newest,
    Offset(i64),
    Timestamp(i64),
}

/// Map a tool position to the broker scan window.
pub fn position_to_bounds(position: ConsumePosition) -> ScanBounds {
    match position {
        ConsumePosition::Oldest => ScanBounds {
            start_offset: Some(0),
            ..ScanBounds::default()
        },
        ConsumePosition::Newest => ScanBounds {
            start_from_tail: true,
            ..ScanBounds::default()
        },
        ConsumePosition::Offset(offset) => ScanBounds {
            start_offset: Some(offset),
            ..ScanBounds::default()
        },
        ConsumePosition::Timestamp(ts) => ScanBounds {
            start_timestamp: Some(ts),
            ..ScanBounds::default()
        },
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct SchemaInfo {
    pub schema_id: u32,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub subject: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub version: Option<i32>,
}

impl From<&MessageSchema> for SchemaInfo {
    fn from(s: &MessageSchema) -> Self {
        Self {
            schema_id: s.schema_id,
            subject: s.subject.clone(),
            version: s.version,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct HeaderInfo {
    pub key: String,
    pub value: CappedText,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct MessageOut {
    pub topic: String,
    pub partition: i32,
    pub offset: i64,
    pub timestamp: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key: Option<CappedText>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value: Option<CappedText>,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub headers: Vec<HeaderInfo>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub key_schema: Option<SchemaInfo>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub value_schema: Option<SchemaInfo>,
}

fn capped_opt(text: Option<String>, original: Option<usize>) -> Option<CappedText> {
    text.map(|t| CappedText {
        text: t,
        original_size: original,
    })
}

pub fn map_collected_message(m: CollectedMessage) -> MessageOut {
    let KafkaMessage {
        topic,
        partition,
        offset,
        key,
        payload,
        timestamp,
        headers,
        key_schema,
        value_schema,
        ..
    } = m.message;
    let sizes = m.original_sizes;
    let headers = headers
        .unwrap_or_default()
        .into_iter()
        .enumerate()
        .map(|(i, h)| HeaderInfo {
            key: h.key,
            value: CappedText {
                text: h.value,
                original_size: sizes.header_values.get(i).copied().flatten(),
            },
        })
        .collect();
    MessageOut {
        topic,
        partition,
        offset,
        timestamp,
        key: capped_opt(key, sizes.key),
        value: capped_opt(payload, sizes.payload),
        headers,
        key_schema: key_schema.as_ref().map(SchemaInfo::from),
        value_schema: value_schema.as_ref().map(SchemaInfo::from),
    }
}

pub fn stop_reason(stop: CollectStop) -> StopReason {
    match stop {
        CollectStop::Complete => StopReason::Complete,
        CollectStop::MessageLimit => StopReason::MessageLimit,
        CollectStop::TimeLimit => StopReason::TimeLimit,
        CollectStop::Cancelled => StopReason::Cancelled,
    }
}

pub fn map_collected(collected: CollectedMessages) -> (Vec<MessageOut>, StopReason) {
    let stop = stop_reason(collected.stop);
    let messages = collected
        .messages
        .into_iter()
        .map(map_collected_message)
        .collect();
    (messages, stop)
}

/// Fail with a distinct error when the topic is missing or not readable.
pub fn ensure_topic_readable(meta: &TopicMetadata) -> Result<(), ToolError> {
    match &meta.metadata_error {
        Some(err) if err.kind == TopicMetadataErrorKind::NotFound => Err(ToolError::Message(
            format!("topic '{}' was not found", meta.name),
        )),
        Some(err) if err.kind == TopicMetadataErrorKind::NotAuthorized => Err(ToolError::Message(
            format!("topic '{}' is not readable", meta.name),
        )),
        Some(err) => Err(ToolError::Message(format!(
            "topic '{}': {}",
            meta.name, err.message
        ))),
        None => Ok(()),
    }
}

pub fn parse_filter_type(s: &str) -> Result<FilterType, ToolError> {
    match s {
        "contains" => Ok(FilterType::Contains),
        "exact" => Ok(FilterType::Exact),
        "regex" => Ok(FilterType::Regex),
        other => Err(ToolError::Message(format!(
            "unknown filter type '{other}'; expected contains, exact or regex"
        ))),
    }
}

/// Parse `oldest` / `newest` / `offset:<n>` / `timestamp:<ms>` (default: oldest).
pub fn parse_position(s: Option<&str>) -> Result<ConsumePosition, ToolError> {
    match s {
        None | Some("") | Some("oldest") => Ok(ConsumePosition::Oldest),
        Some("newest") => Ok(ConsumePosition::Newest),
        Some(raw) => {
            if let Some(rest) = raw.strip_prefix("offset:") {
                return rest
                    .parse::<i64>()
                    .map(ConsumePosition::Offset)
                    .map_err(|_| {
                        ToolError::Message(format!("invalid offset in position '{raw}'"))
                    });
            }
            if let Some(rest) = raw.strip_prefix("timestamp:") {
                return rest
                    .parse::<i64>()
                    .map(ConsumePosition::Timestamp)
                    .map_err(|_| {
                        ToolError::Message(format!("invalid timestamp in position '{raw}'"))
                    });
            }
            Err(ToolError::Message(format!(
                "unknown position '{raw}'; expected oldest, newest, offset:<n> or timestamp:<ms>"
            )))
        }
    }
}

pub fn parse_search_scope(s: Option<&str>) -> SearchScope {
    match s {
        Some("key") => SearchScope::Key,
        Some("value") => SearchScope::Value,
        _ => SearchScope::Both,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn position_mapping() {
        let oldest = position_to_bounds(ConsumePosition::Oldest);
        assert_eq!(oldest.start_offset, Some(0));
        assert!(!oldest.start_from_tail);

        let newest = position_to_bounds(ConsumePosition::Newest);
        assert!(newest.start_from_tail);
        assert!(newest.start_offset.is_none());

        let at = position_to_bounds(ConsumePosition::Offset(42));
        assert_eq!(at.start_offset, Some(42));

        let ts = position_to_bounds(ConsumePosition::Timestamp(1_700_000_000_000));
        assert_eq!(ts.start_timestamp, Some(1_700_000_000_000));
    }
}
