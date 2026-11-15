use serde::{Deserialize, Serialize};

use crate::api::schema_registry::SchemaFieldModelDto;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LocalSchemaFormatDto {
    Avro,
    ProtobufSource,
    ProtobufDescriptor,
    JsonSchema,
}

impl From<kafkalyzer_core::local_schema::LocalSchemaFormat> for LocalSchemaFormatDto {
    fn from(f: kafkalyzer_core::local_schema::LocalSchemaFormat) -> Self {
        match f {
            kafkalyzer_core::local_schema::LocalSchemaFormat::Avro => Self::Avro,
            kafkalyzer_core::local_schema::LocalSchemaFormat::ProtobufSource => {
                Self::ProtobufSource
            }
            kafkalyzer_core::local_schema::LocalSchemaFormat::ProtobufDescriptor => {
                Self::ProtobufDescriptor
            }
            kafkalyzer_core::local_schema::LocalSchemaFormat::JsonSchema => Self::JsonSchema,
        }
    }
}

impl LocalSchemaFormatDto {
    pub(crate) fn to_domain(self) -> kafkalyzer_core::local_schema::LocalSchemaFormat {
        match self {
            Self::Avro => kafkalyzer_core::local_schema::LocalSchemaFormat::Avro,
            Self::ProtobufSource => {
                kafkalyzer_core::local_schema::LocalSchemaFormat::ProtobufSource
            }
            Self::ProtobufDescriptor => {
                kafkalyzer_core::local_schema::LocalSchemaFormat::ProtobufDescriptor
            }
            Self::JsonSchema => kafkalyzer_core::local_schema::LocalSchemaFormat::JsonSchema,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum FramingDto {
    #[default]
    Auto,
    Prefixed,
    Raw,
}

impl From<kafkalyzer_core::local_schema::Framing> for FramingDto {
    fn from(f: kafkalyzer_core::local_schema::Framing) -> Self {
        match f {
            kafkalyzer_core::local_schema::Framing::Auto => Self::Auto,
            kafkalyzer_core::local_schema::Framing::Prefixed => Self::Prefixed,
            kafkalyzer_core::local_schema::Framing::Raw => Self::Raw,
        }
    }
}

impl FramingDto {
    pub(crate) fn to_domain(self) -> kafkalyzer_core::local_schema::Framing {
        match self {
            Self::Auto => kafkalyzer_core::local_schema::Framing::Auto,
            Self::Prefixed => kafkalyzer_core::local_schema::Framing::Prefixed,
            Self::Raw => kafkalyzer_core::local_schema::Framing::Raw,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub enum LocalSchemaModeDto {
    #[default]
    Fallback,
    Always,
}

impl From<kafkalyzer_core::kafka_types::LocalSchemaMode> for LocalSchemaModeDto {
    fn from(m: kafkalyzer_core::kafka_types::LocalSchemaMode) -> Self {
        match m {
            kafkalyzer_core::kafka_types::LocalSchemaMode::Fallback => Self::Fallback,
            kafkalyzer_core::kafka_types::LocalSchemaMode::Always => Self::Always,
        }
    }
}

impl LocalSchemaModeDto {
    pub(crate) fn to_domain(self) -> kafkalyzer_core::kafka_types::LocalSchemaMode {
        match self {
            Self::Fallback => kafkalyzer_core::kafka_types::LocalSchemaMode::Fallback,
            Self::Always => kafkalyzer_core::kafka_types::LocalSchemaMode::Always,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum LocalDecodeErrorKindDto {
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

impl From<kafkalyzer_core::local_schema::LocalDecodeErrorKind> for LocalDecodeErrorKindDto {
    fn from(k: kafkalyzer_core::local_schema::LocalDecodeErrorKind) -> Self {
        use kafkalyzer_core::local_schema::LocalDecodeErrorKind as K;
        match k {
            K::FileNotFound => Self::FileNotFound,
            K::FileUnreadable => Self::FileUnreadable,
            K::FileTooLarge => Self::FileTooLarge,
            K::SchemaInvalid => Self::SchemaInvalid,
            K::UnsupportedProto2 => Self::UnsupportedProto2,
            K::UnresolvedImport => Self::UnresolvedImport,
            K::MessageTypeNotFound => Self::MessageTypeNotFound,
            K::MissingPrefix => Self::MissingPrefix,
            K::UnknownMessageIndex => Self::UnknownMessageIndex,
            K::PayloadMismatch => Self::PayloadMismatch,
            K::TrailingBytes => Self::TrailingBytes,
            K::NotJson => Self::NotJson,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalSchemaErrorDto {
    pub kind: LocalDecodeErrorKindDto,
    pub detail: String,
}

impl From<kafkalyzer_core::local_schema::LocalDecodeError> for LocalSchemaErrorDto {
    fn from(e: kafkalyzer_core::local_schema::LocalDecodeError) -> Self {
        Self {
            kind: e.kind.into(),
            detail: e.detail,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalSchemaAssignmentDto {
    pub path: String,
    pub format: LocalSchemaFormatDto,
    pub message_type: Option<String>,
    pub framing: FramingDto,
    pub mode: LocalSchemaModeDto,
    pub expected_sha256: Option<String>,
}

impl LocalSchemaAssignmentDto {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::LocalSchemaAssignment {
        kafkalyzer_core::kafka_types::LocalSchemaAssignment {
            path: self.path.clone(),
            format: self.format.to_domain(),
            message_type: self.message_type.clone(),
            framing: self.framing.to_domain(),
            mode: self.mode.to_domain(),
            expected_sha256: self.expected_sha256.clone(),
        }
    }
}

#[derive(Debug, Clone, Default, PartialEq, Eq, Serialize, Deserialize)]
pub struct TopicLocalSchemasDto {
    pub key: Option<LocalSchemaAssignmentDto>,
    pub value: Option<LocalSchemaAssignmentDto>,
}

impl TopicLocalSchemasDto {
    pub(crate) fn to_domain(&self) -> kafkalyzer_core::kafka_types::TopicLocalSchemas {
        kafkalyzer_core::kafka_types::TopicLocalSchemas {
            key: self.key.as_ref().map(LocalSchemaAssignmentDto::to_domain),
            value: self.value.as_ref().map(LocalSchemaAssignmentDto::to_domain),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct LocalSchemaUseDto {
    pub file_name: String,
    pub format: LocalSchemaFormatDto,
    pub message_type: Option<String>,
    pub framing: FramingDto,
    pub wire_schema_id: Option<u32>,
    pub error: Option<LocalSchemaErrorDto>,
}

impl From<kafkalyzer_core::kafka_types::LocalSchemaUse> for LocalSchemaUseDto {
    fn from(u: kafkalyzer_core::kafka_types::LocalSchemaUse) -> Self {
        Self {
            file_name: u.file_name,
            format: u.format.into(),
            message_type: u.message_type,
            framing: u.framing.into(),
            wire_schema_id: u.wire_schema_id,
            error: u.error.map(LocalSchemaErrorDto::from),
        }
    }
}

#[derive(Debug, Clone)]
pub struct LocalSchemaInfo {
    pub file_name: String,
    pub detected_format: Option<LocalSchemaFormatDto>,
    pub sha256_hex: Option<String>,
    pub message_types: Vec<String>,
    pub selected_message: Option<String>,
    pub fields: Option<SchemaFieldModelDto>,
    pub error: Option<LocalSchemaErrorDto>,
}

/// Reads and validates a local schema file for UI preview / state checks.
/// Never throws for file or schema problems; returns them in `error`.
pub async fn inspect_local_schema(
    path: String,
    format: Option<LocalSchemaFormatDto>,
    message_type: Option<String>,
) -> LocalSchemaInfo {
    tokio::task::spawn_blocking(move || {
        let file_name = kafkalyzer_kafka::local_schema_loader::base_file_name(&path);
        match kafkalyzer_kafka::local_schema_loader::read_local_schema_file(
            &path,
            format.map(LocalSchemaFormatDto::to_domain),
            message_type.as_deref(),
            kafkalyzer_core::local_schema::Framing::Auto,
        ) {
            Ok(loaded) => LocalSchemaInfo {
                file_name: loaded.file_name,
                detected_format: Some(loaded.format.into()),
                sha256_hex: Some(loaded.sha256_hex),
                message_types: loaded.message_types,
                selected_message: loaded.selected_message,
                fields: Some(SchemaFieldModelDto::from(loaded.field_model)),
                error: None,
            },
            Err(err) => LocalSchemaInfo {
                file_name,
                detected_format: format,
                sha256_hex: None,
                message_types: Vec::new(),
                selected_message: None,
                fields: None,
                error: Some(err.into()),
            },
        }
    })
    .await
    .unwrap_or_else(|e| LocalSchemaInfo {
        file_name: "<schema>".to_string(),
        detected_format: format,
        sha256_hex: None,
        message_types: Vec::new(),
        selected_message: None,
        fields: None,
        error: Some(LocalSchemaErrorDto {
            kind: LocalDecodeErrorKindDto::FileUnreadable,
            detail: format!("Inspection task failed: {e}"),
        }),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_core::local_schema::LocalDecodeErrorKind as K;

    #[test]
    fn maps_every_local_decode_error_kind() {
        let pairs = [
            (K::FileNotFound, LocalDecodeErrorKindDto::FileNotFound),
            (K::FileUnreadable, LocalDecodeErrorKindDto::FileUnreadable),
            (K::FileTooLarge, LocalDecodeErrorKindDto::FileTooLarge),
            (K::SchemaInvalid, LocalDecodeErrorKindDto::SchemaInvalid),
            (
                K::UnsupportedProto2,
                LocalDecodeErrorKindDto::UnsupportedProto2,
            ),
            (
                K::UnresolvedImport,
                LocalDecodeErrorKindDto::UnresolvedImport,
            ),
            (
                K::MessageTypeNotFound,
                LocalDecodeErrorKindDto::MessageTypeNotFound,
            ),
            (K::MissingPrefix, LocalDecodeErrorKindDto::MissingPrefix),
            (
                K::UnknownMessageIndex,
                LocalDecodeErrorKindDto::UnknownMessageIndex,
            ),
            (K::PayloadMismatch, LocalDecodeErrorKindDto::PayloadMismatch),
            (K::TrailingBytes, LocalDecodeErrorKindDto::TrailingBytes),
            (K::NotJson, LocalDecodeErrorKindDto::NotJson),
        ];
        for (domain, expected) in pairs {
            assert_eq!(LocalDecodeErrorKindDto::from(domain), expected);
        }
    }
}
