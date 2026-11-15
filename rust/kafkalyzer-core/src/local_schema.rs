use std::collections::HashMap;
use std::io::Cursor;
use std::panic::{catch_unwind, AssertUnwindSafe};

use protofish::context::{Context as ProtoContext, MessageInfo, TypeRef};
use protofish::decode::{MessageValue, UnknownValue, Value};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::avro_utils::{convert_avro_value, extract_named_schemas};
use crate::proto_json::convert_protofish_message;
use crate::schema_model::{
    extract_protobuf_fields_from_sources, rewrite_proto_maps, scan_top_level_proto_messages,
    schema_fields, strip_proto_comments_and_strings, SchemaFieldModel, SchemaKind,
};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LocalSchemaFormat {
    Avro,
    ProtobufSource,
    ProtobufDescriptor,
    JsonSchema,
}

impl LocalSchemaFormat {
    pub fn display_kind(self) -> &'static str {
        match self {
            Self::Avro => "Avro",
            Self::ProtobufSource | Self::ProtobufDescriptor => "Protobuf",
            Self::JsonSchema => "JSON",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum Framing {
    #[default]
    Auto,
    Prefixed,
    Raw,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LocalDecodeErrorKind {
    FileNotFound,
    FileUnreadable,
    FileTooLarge,
    SchemaInvalid,
    UnsupportedProto2,
    UnresolvedImport,
    MessageTypeNotFound,
    MissingPrefix,
    UnknownMessageIndex,
    PayloadMismatch,
    TrailingBytes,
    NotJson,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalDecodeError {
    pub kind: LocalDecodeErrorKind,
    pub detail: String,
}

impl LocalDecodeError {
    pub fn new(kind: LocalDecodeErrorKind, detail: impl Into<String>) -> Self {
        Self {
            kind,
            detail: detail.into(),
        }
    }
}

#[derive(Debug, Clone, PartialEq)]
pub struct LocalDecodedSide {
    pub json: Option<serde_json::Value>,
    pub text: Option<String>,
    pub wire_schema_id: Option<u32>,
    pub framing_used: Framing,
    pub message_type: Option<String>,
}

pub struct LoadedLocalSchema {
    pub format: LocalSchemaFormat,
    pub file_name: String,
    pub sha256_hex: String,
    pub message_types: Vec<String>,
    pub selected_message: Option<String>,
    pub field_model: SchemaFieldModel,
    pub framing: Framing,
    inner: LoadedSchemaInner,
}

enum LoadedSchemaInner {
    Avro {
        schema: apache_avro::Schema,
    },
    JsonSchema,
    Protobuf {
        context: ProtoContext,
        top_level: Vec<String>,
    },
}

/// Guesses the local schema format from the file name extension and (for `.json`) file contents.
pub fn guess_format(file_name: &str, bytes: &[u8]) -> Option<LocalSchemaFormat> {
    let ext = file_name.rsplit('.').next().map(str::to_ascii_lowercase)?;
    match ext.as_str() {
        "avsc" => Some(LocalSchemaFormat::Avro),
        "proto" => Some(LocalSchemaFormat::ProtobufSource),
        "desc" | "pb" | "binpb" => Some(LocalSchemaFormat::ProtobufDescriptor),
        "json" => guess_json_format(bytes),
        _ => None,
    }
}

fn guess_json_format(bytes: &[u8]) -> Option<LocalSchemaFormat> {
    let val: serde_json::Value = serde_json::from_slice(bytes).ok()?;
    let Some(obj) = val.as_object() else {
        return Some(LocalSchemaFormat::JsonSchema);
    };
    if obj.contains_key("fields") {
        return Some(LocalSchemaFormat::Avro);
    }
    if obj.contains_key("$schema")
        || obj.contains_key("properties")
        || obj.contains_key("$defs")
        || obj.contains_key("definitions")
    {
        return Some(LocalSchemaFormat::JsonSchema);
    }
    if let Some(t) = obj.get("type").and_then(|v| v.as_str()) {
        if matches!(t, "record" | "enum" | "fixed") && obj.contains_key("name") {
            return Some(LocalSchemaFormat::Avro);
        }
    }
    Some(LocalSchemaFormat::JsonSchema)
}

/// Loads and parses a local schema from raw file bytes without performing filesystem I/O.
pub fn load_local_schema(
    file_name: &str,
    bytes: &[u8],
    format: LocalSchemaFormat,
    message_type: Option<&str>,
    framing: Framing,
) -> Result<LoadedLocalSchema, LocalDecodeError> {
    let sha256_hex = hex::encode(Sha256::digest(bytes));
    let selected_hint = message_type.map(str::trim).filter(|s| !s.is_empty());

    match format {
        LocalSchemaFormat::Avro => {
            let text = std::str::from_utf8(bytes).map_err(|_| {
                LocalDecodeError::new(
                    LocalDecodeErrorKind::SchemaInvalid,
                    format!("{file_name} is not valid UTF-8"),
                )
            })?;
            let schema = apache_avro::Schema::parse_str(text).map_err(|e| {
                LocalDecodeError::new(
                    LocalDecodeErrorKind::SchemaInvalid,
                    format!("Invalid Avro schema: {e}"),
                )
            })?;
            let field_model = schema_fields(SchemaKind::Avro, text, &[]);
            Ok(LoadedLocalSchema {
                format,
                file_name: file_name.to_string(),
                sha256_hex,
                message_types: Vec::new(),
                selected_message: None,
                field_model,
                framing,
                inner: LoadedSchemaInner::Avro { schema },
            })
        }
        LocalSchemaFormat::JsonSchema => {
            let text = std::str::from_utf8(bytes).map_err(|_| {
                LocalDecodeError::new(
                    LocalDecodeErrorKind::SchemaInvalid,
                    format!("{file_name} is not valid UTF-8"),
                )
            })?;
            let parsed: serde_json::Value = serde_json::from_str(text).map_err(|e| {
                LocalDecodeError::new(
                    LocalDecodeErrorKind::SchemaInvalid,
                    format!("Invalid JSON Schema: {e}"),
                )
            })?;
            if !parsed.is_object() && !parsed.is_boolean() {
                return Err(LocalDecodeError::new(
                    LocalDecodeErrorKind::SchemaInvalid,
                    "JSON Schema root must be an object or boolean",
                ));
            }
            let field_model = schema_fields(SchemaKind::Json, text, &[]);
            Ok(LoadedLocalSchema {
                format,
                file_name: file_name.to_string(),
                sha256_hex,
                message_types: Vec::new(),
                selected_message: None,
                field_model,
                framing,
                inner: LoadedSchemaInner::JsonSchema,
            })
        }
        LocalSchemaFormat::ProtobufSource => {
            let text = std::str::from_utf8(bytes).map_err(|_| {
                LocalDecodeError::new(
                    LocalDecodeErrorKind::SchemaInvalid,
                    format!("{file_name} is not valid UTF-8"),
                )
            })?;
            validate_proto3_source_preconditions(text)?;
            let sources = vec![text.to_string()];
            build_loaded_protobuf(
                format,
                file_name,
                sha256_hex,
                &sources,
                selected_hint,
                framing,
            )
        }
        LocalSchemaFormat::ProtobufDescriptor => {
            let sources = descriptor_set_to_proto3_sources(bytes)?;
            build_loaded_protobuf(
                format,
                file_name,
                sha256_hex,
                &sources,
                selected_hint,
                framing,
            )
        }
    }
}

fn validate_proto3_source_preconditions(source: &str) -> Result<(), LocalDecodeError> {
    if detect_proto2_syntax(source) {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnsupportedProto2,
            "proto2 syntax is not supported in .proto source files; compile a descriptor set instead",
        ));
    }
    if let Some(import_path) = detect_proto_import(source) {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnresolvedImport,
            format!(
                "Unresolved import '{import_path}'; compile a descriptor set with --include_imports"
            ),
        ));
    }
    Ok(())
}

fn detect_proto2_syntax(source: &str) -> bool {
    // Check syntax = "proto2" ignoring comments
    for line in source.lines() {
        let code = line.split("//").next().unwrap_or("").trim();
        if let Some(rest) = code.strip_prefix("syntax") {
            let rest = rest.trim_start();
            if let Some(rest) = rest.strip_prefix('=') {
                let val = rest.trim().trim_end_matches(';').trim();
                if val == "\"proto2\"" || val == "'proto2'" {
                    return true;
                }
            }
        }
    }
    false
}

fn detect_proto_import(source: &str) -> Option<String> {
    let cleaned = strip_proto_comments_and_strings(source);
    let mut depth = 0i32;
    for line in cleaned.lines() {
        let trimmed = line.trim();
        if depth == 0 && (trimmed.starts_with("import ") || trimmed.starts_with("import\t")) {
            return Some(trimmed.trim_end_matches(';').trim().to_string());
        }
        depth += trimmed.matches('{').count() as i32;
        depth -= trimmed.matches('}').count() as i32;
        if depth < 0 {
            depth = 0;
        }
    }
    None
}

fn build_loaded_protobuf(
    format: LocalSchemaFormat,
    file_name: &str,
    sha256_hex: String,
    sources: &[String],
    selected_hint: Option<&str>,
    framing: Framing,
) -> Result<LoadedLocalSchema, LocalDecodeError> {
    let mut top_level = Vec::new();
    for src in sources {
        for m in scan_top_level_proto_messages(src) {
            if !top_level.contains(&m) {
                top_level.push(m);
            }
        }
    }

    let parse_sources: Vec<String> = sources.iter().map(|s| rewrite_proto_maps(s).0).collect();
    let parse_attempt = catch_unwind(AssertUnwindSafe(|| ProtoContext::parse(&parse_sources)));
    let context = match parse_attempt {
        Ok(Ok(ctx)) => ctx,
        Ok(Err(err)) => {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::SchemaInvalid,
                format!("Protobuf parse error: {err}"),
            ));
        }
        Err(_) => {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::SchemaInvalid,
                "Protobuf parser failed on unsupported syntax",
            ));
        }
    };

    let mut message_types = Vec::new();
    for top in &top_level {
        if let Some(info) = context.get_message(top) {
            collect_message_names(&context, info, &mut message_types);
        }
    }
    if message_types.is_empty() {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::SchemaInvalid,
            "Protobuf schema defines no message types",
        ));
    }

    let selected_message = match selected_hint {
        Some(hint) => {
            if context.get_message(hint).is_none() {
                return Err(LocalDecodeError::new(
                    LocalDecodeErrorKind::MessageTypeNotFound,
                    format!("Message type '{hint}' not found in {file_name}"),
                ));
            }
            Some(hint.to_string())
        }
        None if message_types.len() == 1 => Some(message_types[0].clone()),
        None => None,
    };

    let field_target = selected_message
        .as_deref()
        .or_else(|| top_level.first().map(String::as_str));
    let field_model = extract_protobuf_fields_from_sources(sources, field_target);

    Ok(LoadedLocalSchema {
        format,
        file_name: file_name.to_string(),
        sha256_hex,
        message_types,
        selected_message,
        field_model,
        framing,
        inner: LoadedSchemaInner::Protobuf { context, top_level },
    })
}

fn collect_message_names(ctx: &ProtoContext, info: &MessageInfo, out: &mut Vec<String>) {
    if !out.contains(&info.full_name) {
        out.push(info.full_name.clone());
    }
    for t in &info.inner_types {
        if let TypeRef::Message(mref) = t {
            let child = ctx.resolve_message(*mref);
            // Skip synthetic map entry helper messages emitted by rewrite_proto_maps
            if !child.name.starts_with("__MapEntry_") {
                collect_message_names(ctx, child, out);
            }
        }
    }
}

/// Decodes a non-empty payload using the loaded local schema.
/// Callers must handle null/tombstone and 0-byte payloads before invoking this function.
pub fn decode_with_local(
    loaded: &LoadedLocalSchema,
    bytes: &[u8],
) -> Result<LocalDecodedSide, LocalDecodeError> {
    match &loaded.inner {
        LoadedSchemaInner::Avro { schema } => decode_avro(schema, bytes, loaded.framing),
        LoadedSchemaInner::JsonSchema => decode_json(bytes, loaded.framing),
        LoadedSchemaInner::Protobuf { context, top_level } => decode_protobuf(
            context,
            top_level,
            loaded.selected_message.as_deref(),
            bytes,
            loaded.framing,
        ),
    }
}

fn parse_confluent_prefix(bytes: &[u8]) -> Option<(u32, &[u8])> {
    if bytes.len() >= 5 && bytes[0] == 0x00 {
        let mut id_bytes = [0u8; 4];
        id_bytes.copy_from_slice(&bytes[1..5]);
        Some((u32::from_be_bytes(id_bytes), &bytes[5..]))
    } else {
        None
    }
}

fn decode_avro_datum(
    schema: &apache_avro::Schema,
    body: &[u8],
) -> Result<serde_json::Value, LocalDecodeError> {
    let mut cursor = Cursor::new(body);
    let avro_val = apache_avro::from_avro_datum(schema, &mut cursor, None).map_err(|e| {
        LocalDecodeError::new(
            LocalDecodeErrorKind::PayloadMismatch,
            format!("Avro datum decode failed: {e}"),
        )
    })?;
    let consumed = cursor.position() as usize;
    let remaining = body.len().saturating_sub(consumed);
    if remaining > 0 {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::TrailingBytes,
            format!("{remaining} unread trailing bytes after Avro record"),
        ));
    }
    let mut resolved_schemas = HashMap::new();
    extract_named_schemas(schema, &mut resolved_schemas);
    convert_avro_value(&avro_val, Some(schema), &resolved_schemas).map_err(|e| {
        LocalDecodeError::new(
            LocalDecodeErrorKind::PayloadMismatch,
            format!("Avro JSON conversion failed: {e}"),
        )
    })
}

fn decode_avro(
    schema: &apache_avro::Schema,
    bytes: &[u8],
    framing: Framing,
) -> Result<LocalDecodedSide, LocalDecodeError> {
    match framing {
        Framing::Prefixed => {
            let Some((schema_id, body)) = parse_confluent_prefix(bytes) else {
                return Err(LocalDecodeError::new(
                    LocalDecodeErrorKind::MissingPrefix,
                    "Expected 5-byte Schema Registry prefix (0x00 + 4-byte schema id)",
                ));
            };
            let json = decode_avro_datum(schema, body)?;
            let text = serde_json::to_string_pretty(&json).ok();
            Ok(LocalDecodedSide {
                json: Some(json),
                text,
                wire_schema_id: Some(schema_id),
                framing_used: Framing::Prefixed,
                message_type: None,
            })
        }
        Framing::Raw => {
            let json = decode_avro_datum(schema, bytes)?;
            let text = serde_json::to_string_pretty(&json).ok();
            Ok(LocalDecodedSide {
                json: Some(json),
                text,
                wire_schema_id: None,
                framing_used: Framing::Raw,
                message_type: None,
            })
        }
        Framing::Auto => {
            if let Some((schema_id, body)) = parse_confluent_prefix(bytes) {
                if let Ok(json) = decode_avro_datum(schema, body) {
                    let text = serde_json::to_string_pretty(&json).ok();
                    return Ok(LocalDecodedSide {
                        json: Some(json),
                        text,
                        wire_schema_id: Some(schema_id),
                        framing_used: Framing::Prefixed,
                        message_type: None,
                    });
                }
            }
            let json = decode_avro_datum(schema, bytes)?;
            let text = serde_json::to_string_pretty(&json).ok();
            Ok(LocalDecodedSide {
                json: Some(json),
                text,
                wire_schema_id: None,
                framing_used: Framing::Raw,
                message_type: None,
            })
        }
    }
}

fn decode_json(bytes: &[u8], framing: Framing) -> Result<LocalDecodedSide, LocalDecodeError> {
    match framing {
        Framing::Prefixed => {
            let Some((schema_id, body)) = parse_confluent_prefix(bytes) else {
                return Err(LocalDecodeError::new(
                    LocalDecodeErrorKind::MissingPrefix,
                    "Expected 5-byte Schema Registry prefix (0x00 + 4-byte schema id)",
                ));
            };
            let json = parse_json_slice(body)?;
            let text = serde_json::to_string_pretty(&json).ok();
            Ok(LocalDecodedSide {
                json: Some(json),
                text,
                wire_schema_id: Some(schema_id),
                framing_used: Framing::Prefixed,
                message_type: None,
            })
        }
        Framing::Raw => {
            let json = parse_json_slice(bytes)?;
            let text = serde_json::to_string_pretty(&json).ok();
            Ok(LocalDecodedSide {
                json: Some(json),
                text,
                wire_schema_id: None,
                framing_used: Framing::Raw,
                message_type: None,
            })
        }
        Framing::Auto => {
            if let Some((schema_id, body)) = parse_confluent_prefix(bytes) {
                if let Ok(json) = parse_json_slice(body) {
                    let text = serde_json::to_string_pretty(&json).ok();
                    return Ok(LocalDecodedSide {
                        json: Some(json),
                        text,
                        wire_schema_id: Some(schema_id),
                        framing_used: Framing::Prefixed,
                        message_type: None,
                    });
                }
            }
            let json = parse_json_slice(bytes)?;
            let text = serde_json::to_string_pretty(&json).ok();
            Ok(LocalDecodedSide {
                json: Some(json),
                text,
                wire_schema_id: None,
                framing_used: Framing::Raw,
                message_type: None,
            })
        }
    }
}

fn parse_json_slice(bytes: &[u8]) -> Result<serde_json::Value, LocalDecodeError> {
    serde_json::from_slice::<serde_json::Value>(bytes).map_err(|e| {
        LocalDecodeError::new(
            LocalDecodeErrorKind::NotJson,
            format!("Payload is not valid JSON: {e}"),
        )
    })
}

fn decode_zigzag_varint_i64(input: &[u8]) -> Result<(i64, &[u8]), LocalDecodeError> {
    let mut val: u64 = 0;
    let mut shift = 0u32;
    for (idx, &b) in input.iter().enumerate() {
        if idx >= 10 {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::UnknownMessageIndex,
                "Malformed message index list: varint exceeds 10 bytes",
            ));
        }
        val |= u64::from(b & 0x7f) << shift;
        if b & 0x80 == 0 {
            let signed = ((val >> 1) as i64) ^ -((val & 1) as i64);
            return Ok((signed, &input[idx + 1..]));
        }
        shift += 7;
    }
    Err(LocalDecodeError::new(
        LocalDecodeErrorKind::UnknownMessageIndex,
        "Malformed message index list: truncated varint",
    ))
}

/// Parses a Confluent Schema Registry Protobuf message-index list (`0x00` -> `[0]`,
/// or zigzag varint count <= 32 followed by non-negative zigzag varint indexes).
pub fn parse_message_indexes(
    payload_after_id: &[u8],
) -> Result<(Vec<i32>, &[u8]), LocalDecodeError> {
    let Some((&first, rest)) = payload_after_id.split_first() else {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnknownMessageIndex,
            "Malformed message index list: empty index list",
        ));
    };
    if first == 0 {
        return Ok((vec![0], rest));
    }
    let (count, mut cursor) = decode_zigzag_varint_i64(payload_after_id)?;
    if count <= 0 || count > 32 {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnknownMessageIndex,
            format!("Malformed message index list: invalid count {count}"),
        ));
    }
    let mut indexes = Vec::with_capacity(count as usize);
    for _ in 0..count {
        let (idx, next) = decode_zigzag_varint_i64(cursor)?;
        if idx < 0 || idx > i64::from(i32::MAX) {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::UnknownMessageIndex,
                format!("Malformed message index list: invalid index {idx}"),
            ));
        }
        indexes.push(idx as i32);
        cursor = next;
    }
    Ok((indexes, cursor))
}

/// Resolves a Confluent message-index path against `top_level` messages and `inner_types`
/// filtered to `TypeRef::Message`.
pub fn resolve_message_index_path<'a>(
    ctx: &'a ProtoContext,
    top_level: &[String],
    indexes: &[i32],
) -> Result<&'a MessageInfo, LocalDecodeError> {
    let Some((&first, rest)) = indexes.split_first() else {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnknownMessageIndex,
            "Message index list [] is empty",
        ));
    };
    let Some(first_usize) = usize::try_from(first).ok() else {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnknownMessageIndex,
            format!("Message index list {indexes:?} contains negative index"),
        ));
    };
    let Some(top_name) = top_level.get(first_usize) else {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnknownMessageIndex,
            format!("Message index list {indexes:?} not present in schema"),
        ));
    };
    let Some(mut current) = ctx.get_message(top_name) else {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::UnknownMessageIndex,
            format!("Message index list {indexes:?} resolved to missing '{top_name}'"),
        ));
    };
    for &idx in rest {
        let Some(idx_usize) = usize::try_from(idx).ok() else {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::UnknownMessageIndex,
                format!("Message index list {indexes:?} contains negative index"),
            ));
        };
        let Some(msg_ref) = current
            .inner_types
            .iter()
            .filter_map(|t| match t {
                TypeRef::Message(m) => Some(*m),
                _ => None,
            })
            .nth(idx_usize)
        else {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::UnknownMessageIndex,
                format!("Message index list {indexes:?} not present in schema"),
            ));
        };
        current = ctx.resolve_message(msg_ref);
    }
    Ok(current)
}

fn decode_protobuf(
    context: &ProtoContext,
    top_level: &[String],
    selected_message: Option<&str>,
    bytes: &[u8],
    framing: Framing,
) -> Result<LocalDecodedSide, LocalDecodeError> {
    let has_prefix = bytes.len() >= 5 && bytes[0] == 0x00;
    let use_prefix = match framing {
        Framing::Prefixed => true,
        Framing::Raw => false,
        Framing::Auto => has_prefix,
    };

    if use_prefix {
        let Some((schema_id, after_id)) = parse_confluent_prefix(bytes) else {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::MissingPrefix,
                "Expected 5-byte Schema Registry prefix (0x00 + 4-byte schema id)",
            ));
        };
        let (indexes, body) = parse_message_indexes(after_id)?;
        let msg_info = resolve_message_index_path(context, top_level, &indexes)?;
        let decoded = decode_protobuf_body(context, msg_info, body)?;
        let text = serde_json::to_string_pretty(&decoded).ok();
        Ok(LocalDecodedSide {
            json: Some(decoded),
            text,
            wire_schema_id: Some(schema_id),
            framing_used: Framing::Prefixed,
            message_type: Some(msg_info.full_name.clone()),
        })
    } else {
        let Some(msg_name) = selected_message else {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::MessageTypeNotFound,
                "No Protobuf message type selected for raw payload",
            ));
        };
        let Some(msg_info) = context.get_message(msg_name) else {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::MessageTypeNotFound,
                format!("Protobuf message type '{msg_name}' not found"),
            ));
        };
        let decoded = decode_protobuf_body(context, msg_info, bytes)?;
        let text = serde_json::to_string_pretty(&decoded).ok();
        Ok(LocalDecodedSide {
            json: Some(decoded),
            text,
            wire_schema_id: None,
            framing_used: Framing::Raw,
            message_type: Some(msg_info.full_name.clone()),
        })
    }
}

fn decode_protobuf_body(
    context: &ProtoContext,
    msg_info: &MessageInfo,
    body: &[u8],
) -> Result<serde_json::Value, LocalDecodeError> {
    let decoded = context.decode(msg_info.self_ref, body);
    for field in &decoded.fields {
        if matches!(
            field.value,
            Value::Incomplete(_, _) | Value::Unknown(UnknownValue::Invalid(_, _))
        ) {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::PayloadMismatch,
                format!(
                    "Protobuf wire bytes do not match message '{}' at field {}",
                    msg_info.full_name, field.number
                ),
            ));
        }
    }
    Ok(convert_protofish_message(&decoded, context))
}

// ---------------------------------------------------------------------------
// Descriptor-set (.desc / .pb / .binpb) -> proto3 synthesis (Spike S2 Option A)
// ---------------------------------------------------------------------------

const DESCRIPTOR_PROTO_SUBSET: &str = r#"
syntax = "proto3";
package google.protobuf;

message FileDescriptorSet {
  repeated FileDescriptorProto file = 1;
}

message FileDescriptorProto {
  string name = 1;
  string package = 2;
  repeated string dependency = 3;
  repeated DescriptorProto message_type = 4;
  repeated EnumDescriptorProto enum_type = 5;
  repeated FieldDescriptorProto extension = 7;
  string syntax = 12;
}

message DescriptorProto {
  string name = 1;
  repeated FieldDescriptorProto field = 2;
  repeated DescriptorProto nested_type = 3;
  repeated EnumDescriptorProto enum_type = 4;
  repeated FieldDescriptorProto extension = 6;
  MessageOptions options = 7;
  repeated OneofDescriptorProto oneof_decl = 8;
}

message MessageOptions {
  bool map_entry = 7;
}

message OneofDescriptorProto {
  string name = 1;
}

message FieldDescriptorProto {
  enum Type {
    TYPE_UNKNOWN = 0;
    TYPE_DOUBLE = 1;
    TYPE_FLOAT = 2;
    TYPE_INT64 = 3;
    TYPE_UINT64 = 4;
    TYPE_INT32 = 5;
    TYPE_FIXED64 = 6;
    TYPE_FIXED32 = 7;
    TYPE_BOOL = 8;
    TYPE_STRING = 9;
    TYPE_GROUP = 10;
    TYPE_MESSAGE = 11;
    TYPE_BYTES = 12;
    TYPE_UINT32 = 13;
    TYPE_ENUM = 14;
    TYPE_SFIXED32 = 15;
    TYPE_SFIXED64 = 16;
    TYPE_SINT32 = 17;
    TYPE_SINT64 = 18;
  }
  enum Label {
    LABEL_UNKNOWN = 0;
    LABEL_OPTIONAL = 1;
    LABEL_REQUIRED = 2;
    LABEL_REPEATED = 3;
  }
  string name = 1;
  string extendee = 2;
  int32 number = 3;
  Label label = 4;
  Type type = 5;
  string type_name = 6;
  string default_value = 7;
  int32 oneof_index = 9;
  bool proto3_optional = 17;
}

message EnumDescriptorProto {
  string name = 1;
  repeated EnumValueDescriptorProto value = 2;
}

message EnumValueDescriptorProto {
  string name = 1;
  int32 number = 2;
}
"#;

fn fds_get_str(msg: &MessageValue, num: u64) -> Option<&str> {
    msg.fields
        .iter()
        .find(|f| f.number == num)
        .and_then(|f| match &f.value {
            Value::String(s) => Some(s.as_str()),
            _ => None,
        })
}

fn fds_get_int(msg: &MessageValue, num: u64) -> Option<i64> {
    msg.fields
        .iter()
        .find(|f| f.number == num)
        .and_then(|f| match &f.value {
            Value::Int32(v) => Some(i64::from(*v)),
            Value::Int64(v) => Some(*v),
            Value::Enum(e) => Some(e.value),
            _ => None,
        })
}

fn fds_get_bool(msg: &MessageValue, num: u64) -> bool {
    msg.fields
        .iter()
        .any(|f| f.number == num && matches!(f.value, Value::Bool(true)))
}

fn fds_get_msgs(msg: &MessageValue, num: u64) -> Vec<&MessageValue> {
    msg.fields
        .iter()
        .filter(|f| f.number == num)
        .filter_map(|f| match &f.value {
            Value::Message(m) => Some(m.as_ref()),
            _ => None,
        })
        .collect()
}

fn fds_scalar_type_name(t: i64) -> Option<&'static str> {
    Some(match t {
        1 => "double",
        2 => "float",
        3 => "int64",
        4 => "uint64",
        5 => "int32",
        6 => "fixed64",
        7 => "fixed32",
        8 => "bool",
        9 => "string",
        12 => "bytes",
        13 => "uint32",
        15 => "sfixed32",
        16 => "sfixed64",
        17 => "sint32",
        18 => "sint64",
        _ => return None,
    })
}

fn fds_field_type_str(f: &MessageValue) -> Result<String, LocalDecodeError> {
    let ftype = fds_get_int(f, 5).unwrap_or(0);
    if ftype == 10 {
        let name = fds_get_str(f, 1).unwrap_or("<unknown>");
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::SchemaInvalid,
            format!("Unsupported proto2 group field '{name}'"),
        ));
    }
    if let Some(scalar) = fds_scalar_type_name(ftype) {
        return Ok(scalar.to_string());
    }
    if ftype == 11 || ftype == 14 {
        let tn = fds_get_str(f, 6).unwrap_or("");
        return Ok(tn.trim_start_matches('.').to_string());
    }
    Err(LocalDecodeError::new(
        LocalDecodeErrorKind::SchemaInvalid,
        format!("Unsupported Protobuf field type id {ftype}"),
    ))
}

fn fds_emit_enum(e: &MessageValue, indent: &str, out: &mut String) {
    let name = fds_get_str(e, 1).unwrap_or("UnknownEnum");
    out.push_str(&format!("{indent}enum {name} {{\n"));
    for v in fds_get_msgs(e, 2) {
        let vn = fds_get_str(v, 1).unwrap_or("UNKNOWN");
        let vnum = fds_get_int(v, 2).unwrap_or(0);
        out.push_str(&format!("{indent}  {vn} = {vnum};\n"));
    }
    out.push_str(&format!("{indent}}}\n"));
}

fn fds_is_map_entry(msg: &MessageValue) -> Option<(String, String)> {
    let opts = fds_get_msgs(msg, 7).into_iter().next()?;
    if !fds_get_bool(opts, 7) {
        return None;
    }
    let fields = fds_get_msgs(msg, 2);
    let key_f = fields.iter().find(|f| fds_get_int(f, 3) == Some(1))?;
    let val_f = fields.iter().find(|f| fds_get_int(f, 3) == Some(2))?;
    let kt = fds_field_type_str(key_f).ok()?;
    let vt = fds_field_type_str(val_f).ok()?;
    Some((kt, vt))
}

fn fds_emit_message(
    msg: &MessageValue,
    scope: &str,
    indent: &str,
    out: &mut String,
) -> Result<(), LocalDecodeError> {
    if !fds_get_msgs(msg, 6).is_empty() {
        let name = fds_get_str(msg, 1).unwrap_or("<unknown>");
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::SchemaInvalid,
            format!("Unsupported extension range/field in message '{name}'"),
        ));
    }
    let name = fds_get_str(msg, 1).unwrap_or("UnknownMessage");
    let full_scope = if scope.is_empty() {
        name.to_string()
    } else {
        format!("{scope}.{name}")
    };
    out.push_str(&format!("{indent}message {name} {{\n"));
    let inner_indent = format!("{indent}  ");

    for e in fds_get_msgs(msg, 4) {
        fds_emit_enum(e, &inner_indent, out);
    }

    let mut map_entries: HashMap<String, (String, String)> = HashMap::new();
    for nested in fds_get_msgs(msg, 3) {
        let nname = fds_get_str(nested, 1).unwrap_or("Nested");
        if let Some((kt, vt)) = fds_is_map_entry(nested) {
            map_entries.insert(format!("{full_scope}.{nname}"), (kt, vt));
        } else {
            fds_emit_message(nested, &full_scope, &inner_indent, out)?;
        }
    }

    let oneofs: Vec<String> = fds_get_msgs(msg, 8)
        .into_iter()
        .map(|o| fds_get_str(o, 1).unwrap_or("oneof").to_string())
        .collect();
    let mut oneof_fields: HashMap<usize, Vec<&MessageValue>> = HashMap::new();

    for f in fds_get_msgs(msg, 2) {
        let proto3_opt = fds_get_bool(f, 17);
        if !proto3_opt {
            if let Some(oi) = fds_get_int(f, 9) {
                if let Ok(oi_u) = usize::try_from(oi) {
                    if oi_u < oneofs.len() {
                        oneof_fields.entry(oi_u).or_default().push(f);
                        continue;
                    }
                }
            }
        }
        let fname = fds_get_str(f, 1).unwrap_or("field");
        let fnum = fds_get_int(f, 3).unwrap_or(1);
        let label = fds_get_int(f, 4).unwrap_or(1);
        let ftype_str = fds_field_type_str(f)?;
        if label == 3 {
            if let Some((kt, vt)) = map_entries.get(&ftype_str) {
                out.push_str(&format!(
                    "{inner_indent}map<{kt}, {vt}> {fname} = {fnum};\n"
                ));
                continue;
            }
            out.push_str(&format!(
                "{inner_indent}repeated {ftype_str} {fname} = {fnum};\n"
            ));
        } else {
            out.push_str(&format!("{inner_indent}{ftype_str} {fname} = {fnum};\n"));
        }
    }

    for (oi, oname) in oneofs.iter().enumerate() {
        if let Some(fields) = oneof_fields.get(&oi) {
            out.push_str(&format!("{inner_indent}oneof {oname} {{\n"));
            for f in fields {
                let fname = fds_get_str(f, 1).unwrap_or("field");
                let fnum = fds_get_int(f, 3).unwrap_or(1);
                let ftype_str = fds_field_type_str(f)?;
                out.push_str(&format!("{inner_indent}  {ftype_str} {fname} = {fnum};\n"));
            }
            out.push_str(&format!("{inner_indent}}}\n"));
        }
    }

    out.push_str(&format!("{indent}}}\n"));
    Ok(())
}

pub fn descriptor_set_to_proto3_sources(bytes: &[u8]) -> Result<Vec<String>, LocalDecodeError> {
    if bytes.is_empty() {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::SchemaInvalid,
            "Protobuf descriptor set is empty",
        ));
    }
    let desc_ctx = ProtoContext::parse([DESCRIPTOR_PROTO_SUBSET]).map_err(|e| {
        LocalDecodeError::new(
            LocalDecodeErrorKind::SchemaInvalid,
            format!("Internal descriptor schema parse error: {e}"),
        )
    })?;
    let fds_ref = desc_ctx
        .get_message("google.protobuf.FileDescriptorSet")
        .ok_or_else(|| {
            LocalDecodeError::new(
                LocalDecodeErrorKind::SchemaInvalid,
                "Internal FileDescriptorSet missing",
            )
        })?
        .self_ref;
    let fds = desc_ctx.decode(fds_ref, bytes);
    let has_corrupt = fds.fields.iter().any(|f| {
        matches!(
            f.value,
            Value::Incomplete(_, _) | Value::Unknown(UnknownValue::Invalid(_, _))
        )
    });
    let files = fds_get_msgs(&fds, 1);
    if has_corrupt || files.is_empty() {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::SchemaInvalid,
            "Invalid Protobuf FileDescriptorSet binary",
        ));
    }
    let mut sources = Vec::new();
    for file in files {
        if !fds_get_msgs(file, 7).is_empty() {
            let fname = fds_get_str(file, 1).unwrap_or("<unknown>");
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::SchemaInvalid,
                format!("Unsupported top-level extensions in '{fname}'"),
            ));
        }
        let pkg = fds_get_str(file, 2).unwrap_or("");
        let mut src = String::from("syntax = \"proto3\";\n");
        if !pkg.is_empty() {
            src.push_str(&format!("package {pkg};\n"));
        }
        for e in fds_get_msgs(file, 5) {
            fds_emit_enum(e, "", &mut src);
        }
        for m in fds_get_msgs(file, 4) {
            fds_emit_message(m, pkg, "", &mut src)?;
        }
        sources.push(src);
    }
    Ok(sources)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SAMPLE_AVRO: &str = r#"{
        "type": "record",
        "name": "Order",
        "namespace": "acme",
        "fields": [
            {"name": "id", "type": "string"},
            {"name": "amount", "type": "long"}
        ]
    }"#;

    const SAMPLE_JSON_SCHEMA: &str = r#"{
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "properties": {
            "id": {"type": "string"},
            "qty": {"type": "integer"}
        }
    }"#;

    const SAMPLE_PROTO3: &str = r#"
syntax = "proto3";
package acme;

message Order {
  enum Status {
    NEW = 0;
  }
  message Line {
    string sku = 1;
  }
  message Deep {
    enum Flag { NONE = 0; }
    message A { int32 a = 1; }
    message B { int32 b = 1; }
  }
  string id = 1;
}

enum GlobalKind {
  GK_UNSPECIFIED = 0;
}

message Envelope {
  message Item {
    string name = 1;
  }
  Item item = 1;
}
"#;

    fn encode_confluent_avro(
        schema_id: u32,
        schema_str: &str,
        record: Vec<(&str, apache_avro::types::Value)>,
    ) -> Vec<u8> {
        let schema = apache_avro::Schema::parse_str(schema_str).unwrap();
        let datum = apache_avro::to_avro_datum(
            &schema,
            apache_avro::types::Value::Record(
                record
                    .into_iter()
                    .map(|(k, v)| (k.to_string(), v))
                    .collect(),
            ),
        )
        .unwrap();
        let mut out = vec![0x00];
        out.extend_from_slice(&schema_id.to_be_bytes());
        out.extend_from_slice(&datum);
        out
    }

    #[test]
    fn guess_format_handles_extensions_and_json_disambiguation() {
        assert_eq!(
            guess_format("order.avsc", b"{}"),
            Some(LocalSchemaFormat::Avro)
        );
        assert_eq!(
            guess_format("order.proto", b""),
            Some(LocalSchemaFormat::ProtobufSource)
        );
        assert_eq!(
            guess_format("order.desc", b""),
            Some(LocalSchemaFormat::ProtobufDescriptor)
        );
        assert_eq!(
            guess_format("order.pb", b""),
            Some(LocalSchemaFormat::ProtobufDescriptor)
        );
        assert_eq!(
            guess_format("order.binpb", b""),
            Some(LocalSchemaFormat::ProtobufDescriptor)
        );
        assert_eq!(
            guess_format("order.json", SAMPLE_AVRO.as_bytes()),
            Some(LocalSchemaFormat::Avro)
        );
        assert_eq!(
            guess_format("order.json", SAMPLE_JSON_SCHEMA.as_bytes()),
            Some(LocalSchemaFormat::JsonSchema)
        );
        assert_eq!(guess_format("notes.txt", b"hello"), None);
    }

    #[test]
    fn load_local_schema_valid_and_error_cases() {
        // Valid Avro, JSON Schema, Proto3
        let avro = load_local_schema(
            "orders.avsc",
            SAMPLE_AVRO.as_bytes(),
            LocalSchemaFormat::Avro,
            None,
            Framing::Auto,
        )
        .unwrap();
        assert_eq!(avro.field_model.fields.len(), 2);

        let js = load_local_schema(
            "orders.json",
            SAMPLE_JSON_SCHEMA.as_bytes(),
            LocalSchemaFormat::JsonSchema,
            None,
            Framing::Auto,
        )
        .unwrap();
        assert_eq!(js.field_model.fields.len(), 2);

        let pb = load_local_schema(
            "orders.proto",
            SAMPLE_PROTO3.as_bytes(),
            LocalSchemaFormat::ProtobufSource,
            Some("acme.Order"),
            Framing::Auto,
        )
        .unwrap();
        assert!(pb.message_types.contains(&"acme.Order".to_string()));
        assert!(pb.message_types.contains(&"acme.Envelope".to_string()));

        // Invalid files
        assert_eq!(
            load_local_schema(
                "bad.avsc",
                b"{not json",
                LocalSchemaFormat::Avro,
                None,
                Framing::Auto
            )
            .err()
            .unwrap()
            .kind,
            LocalDecodeErrorKind::SchemaInvalid
        );
        assert_eq!(
            load_local_schema(
                "bad.json",
                b"123",
                LocalSchemaFormat::JsonSchema,
                None,
                Framing::Auto
            )
            .err()
            .unwrap()
            .kind,
            LocalDecodeErrorKind::SchemaInvalid
        );
        assert_eq!(
            load_local_schema(
                "bad.desc",
                b"not-a-desc",
                LocalSchemaFormat::ProtobufDescriptor,
                None,
                Framing::Auto
            )
            .err()
            .unwrap()
            .kind,
            LocalDecodeErrorKind::SchemaInvalid
        );

        // Proto2 source & import source & missing message type
        let proto2 = "syntax = \"proto2\";\nmessage Foo { required string id = 1; }";
        assert_eq!(
            load_local_schema(
                "old.proto",
                proto2.as_bytes(),
                LocalSchemaFormat::ProtobufSource,
                None,
                Framing::Auto
            )
            .err()
            .unwrap()
            .kind,
            LocalDecodeErrorKind::UnsupportedProto2
        );
        let imported =
            "syntax = \"proto3\";\nimport \"other.proto\";\nmessage Foo { string id = 1; }";
        assert_eq!(
            load_local_schema(
                "imp.proto",
                imported.as_bytes(),
                LocalSchemaFormat::ProtobufSource,
                None,
                Framing::Auto
            )
            .err()
            .unwrap()
            .kind,
            LocalDecodeErrorKind::UnresolvedImport
        );
        assert_eq!(
            load_local_schema(
                "orders.proto",
                SAMPLE_PROTO3.as_bytes(),
                LocalSchemaFormat::ProtobufSource,
                Some("acme.DoesNotExist"),
                Framing::Auto
            )
            .err()
            .unwrap()
            .kind,
            LocalDecodeErrorKind::MessageTypeNotFound
        );
    }

    #[test]
    fn decode_avro_and_json_framing_and_strict_checks() {
        let avro = load_local_schema(
            "orders.avsc",
            SAMPLE_AVRO.as_bytes(),
            LocalSchemaFormat::Avro,
            None,
            Framing::Auto,
        )
        .unwrap();

        // Prefixed Avro (id 42)
        let prefixed = encode_confluent_avro(
            42,
            SAMPLE_AVRO,
            vec![
                ("id", apache_avro::types::Value::String("o-1".into())),
                ("amount", apache_avro::types::Value::Long(99)),
            ],
        );
        let dec = decode_with_local(&avro, &prefixed).unwrap();
        assert_eq!(dec.wire_schema_id, Some(42));
        assert_eq!(dec.framing_used, Framing::Prefixed);
        assert_eq!(dec.json.unwrap()["id"], "o-1");

        // Raw Avro
        let raw = &prefixed[5..];
        let dec_raw = decode_with_local(&avro, raw).unwrap();
        assert_eq!(dec_raw.wire_schema_id, None);
        assert_eq!(dec_raw.framing_used, Framing::Raw);
        assert_eq!(dec_raw.json.unwrap()["amount"], 99);

        // Raw Avro starting with 0x00 (empty string in Avro starts with zigzag len 0 = 0x00)
        let schema = apache_avro::Schema::parse_str(SAMPLE_AVRO).unwrap();
        let raw_zero = apache_avro::to_avro_datum(
            &schema,
            apache_avro::types::Value::Record(vec![
                (
                    "id".to_string(),
                    apache_avro::types::Value::String(String::new()),
                ),
                ("amount".to_string(), apache_avro::types::Value::Long(7)),
            ]),
        )
        .unwrap();
        assert_eq!(raw_zero[0], 0x00);
        let dec_zero = decode_with_local(&avro, &raw_zero).unwrap();
        assert_eq!(dec_zero.framing_used, Framing::Raw);
        assert_eq!(dec_zero.json.unwrap()["amount"], 7);

        // Forced Prefixed without prefix -> MissingPrefix
        let avro_prefixed_only = load_local_schema(
            "orders.avsc",
            SAMPLE_AVRO.as_bytes(),
            LocalSchemaFormat::Avro,
            None,
            Framing::Prefixed,
        )
        .unwrap();
        assert_eq!(
            decode_with_local(&avro_prefixed_only, raw)
                .unwrap_err()
                .kind,
            LocalDecodeErrorKind::MissingPrefix
        );

        // Trailing bytes -> TrailingBytes
        let mut with_trailing = raw.to_vec();
        with_trailing.extend_from_slice(&[0x01, 0x02]);
        let err = decode_with_local(&avro, &with_trailing).unwrap_err();
        assert_eq!(err.kind, LocalDecodeErrorKind::TrailingBytes);
        assert!(err.detail.contains("2"));

        // JSON Schema prefixed & non-JSON
        let js = load_local_schema(
            "orders.json",
            SAMPLE_JSON_SCHEMA.as_bytes(),
            LocalSchemaFormat::JsonSchema,
            None,
            Framing::Auto,
        )
        .unwrap();
        let mut prefixed_json = vec![0x00];
        prefixed_json.extend_from_slice(&9u32.to_be_bytes());
        prefixed_json.extend_from_slice(br#"{"id":"x","qty":3}"#);
        let dec_js = decode_with_local(&js, &prefixed_json).unwrap();
        assert_eq!(dec_js.wire_schema_id, Some(9));
        assert_eq!(dec_js.framing_used, Framing::Prefixed);
        assert_eq!(dec_js.json.unwrap()["qty"], 3);

        assert_eq!(
            decode_with_local(&js, b"not-json").unwrap_err().kind,
            LocalDecodeErrorKind::NotJson
        );
    }

    #[test]
    fn decode_protobuf_indexes_raw_mismatch_and_unknown_fields() {
        let pb = load_local_schema(
            "orders.proto",
            SAMPLE_PROTO3.as_bytes(),
            LocalSchemaFormat::ProtobufSource,
            Some("acme.Order"),
            Framing::Auto,
        )
        .unwrap();

        // [0] -> acme.Order (id: "o1")
        let mut p0 = vec![0x00, 0, 0, 0, 10, 0x00];
        p0.extend_from_slice(&[0x0a, 0x02, b'o', b'1']);
        let d0 = decode_with_local(&pb, &p0).unwrap();
        assert_eq!(d0.message_type.as_deref(), Some("acme.Order"));
        assert_eq!(d0.wire_schema_id, Some(10));
        assert_eq!(d0.json.unwrap()["id"], "o1");

        // [1, 0] -> acme.Envelope.Item (name: "it")
        // zigzag: count=2 -> 0x04, idx1=1 -> 0x02, idx2=0 -> 0x00
        let mut p10 = vec![0x00, 0, 0, 0, 11, 0x04, 0x02, 0x00];
        p10.extend_from_slice(&[0x0a, 0x02, b'i', b't']);
        let d10 = decode_with_local(&pb, &p10).unwrap();
        assert_eq!(d10.message_type.as_deref(), Some("acme.Envelope.Item"));
        assert_eq!(d10.json.unwrap()["name"], "it");

        // Index not in schema [9] (zigzag count=1 -> 0x02, idx=9 -> 0x12)
        let p_bad_idx = vec![0x00, 0, 0, 0, 11, 0x02, 0x12, 0x0a, 0x01, b'x'];
        assert_eq!(
            decode_with_local(&pb, &p_bad_idx).unwrap_err().kind,
            LocalDecodeErrorKind::UnknownMessageIndex
        );

        // Malformed index list (truncated varint)
        let p_truncated_idx = vec![0x00, 0, 0, 0, 11, 0x80];
        assert_eq!(
            decode_with_local(&pb, &p_truncated_idx).unwrap_err().kind,
            LocalDecodeErrorKind::UnknownMessageIndex
        );

        // Raw payload with selected message acme.Order
        let raw = &[0x0a, 0x03, b'r', b'a', b'w'];
        let d_raw = decode_with_local(&pb, raw).unwrap();
        assert_eq!(d_raw.framing_used, Framing::Raw);
        assert_eq!(d_raw.message_type.as_deref(), Some("acme.Order"));
        assert_eq!(d_raw.json.unwrap()["id"], "raw");

        // Mismatching payload (truncated length-delimited field -> Incomplete)
        let mismatch = &[0x0a, 0x10, b'a'];
        assert_eq!(
            decode_with_local(&pb, mismatch).unwrap_err().kind,
            LocalDecodeErrorKind::PayloadMismatch
        );

        // Unknown field number kept
        let with_unknown = &[0x0a, 0x02, b'o', b'2', 0x98, 0x06, 0x07];
        let d_unk = decode_with_local(&pb, with_unknown).unwrap();
        let json_unk = d_unk.json.unwrap();
        assert_eq!(json_unk["id"], "o2");
        assert_eq!(json_unk["field_99"], "7");
    }

    #[test]
    fn decode_descriptor_set_fixtures_cross_file_map_oneof_and_proto2() {
        let multi_bytes = include_bytes!("../tests/fixtures/orders_multi.desc");
        let loaded = load_local_schema(
            "orders_multi.desc",
            multi_bytes,
            LocalSchemaFormat::ProtobufDescriptor,
            Some("acme.orders.Order"),
            Framing::Auto,
        )
        .unwrap();
        assert!(loaded
            .message_types
            .contains(&"acme.common.Money".to_string()));
        assert!(loaded
            .message_types
            .contains(&"acme.orders.Order".to_string()));

        // Encode acme.orders.Order:
        // 1: id = "ord-1" -> 0x0a 0x05 "ord-1"
        // 2: total (acme.common.Money: currency="EUR", units=500) -> 0x12 0x07 (0x0a 0x03 "EUR" 0x10 0xf4 0x03)
        // 3: attrs map<"a", 42> -> 0x1a 0x05 (0x0a 0x01 "a" 0x10 0x2a)
        // 4: oneof note = "fast" -> 0x22 0x04 "fast"
        let wire: &[u8] = &[
            0x0a, 0x05, b'o', b'r', b'd', b'-', b'1', 0x12, 0x08, 0x0a, 0x03, b'E', b'U', b'R',
            0x10, 0xf4, 0x03, 0x1a, 0x05, 0x0a, 0x01, b'a', 0x10, 0x2a, 0x22, 0x04, b'f', b'a',
            b's', b't',
        ];
        let dec = decode_with_local(&loaded, wire).unwrap();
        let json = dec.json.unwrap();
        assert_eq!(json["id"], "ord-1");
        assert_eq!(json["total"]["currency"], "EUR");
        assert_eq!(json["total"]["units"], 500);
        assert_eq!(json["attrs"]["key"], "a");
        assert_eq!(json["attrs"]["value"], 42);
        assert_eq!(json["note"], "fast");

        // Proto2 descriptor set
        let legacy_bytes = include_bytes!("../tests/fixtures/legacy_proto2.desc");
        let legacy = load_local_schema(
            "legacy_proto2.desc",
            legacy_bytes,
            LocalSchemaFormat::ProtobufDescriptor,
            Some("acme.legacy.LegacyEvent"),
            Framing::Auto,
        )
        .unwrap();
        let legacy_wire: &[u8] = &[0x0a, 0x03, b'e', b'v', b'1', 0x10, 0x05];
        let leg_dec = decode_with_local(&legacy, legacy_wire)
            .unwrap()
            .json
            .unwrap();
        assert_eq!(leg_dec["event_id"], "ev1");
        assert_eq!(leg_dec["retries"], 5);
    }
}
