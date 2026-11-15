use std::path::Path;
use std::sync::Arc;

use kafkalyzer_core::kafka_types::{LocalSchemaAssignment, LocalSchemaMode, TopicLocalSchemas};
use kafkalyzer_core::local_schema::{
    guess_format, load_local_schema, Framing, LoadedLocalSchema, LocalDecodeError,
    LocalDecodeErrorKind, LocalSchemaFormat,
};

pub const MAX_LOCAL_SCHEMA_BYTES: u64 = 10 * 1024 * 1024;

#[derive(Clone)]
pub enum SideLocalSchema {
    Loaded {
        schema: Arc<LoadedLocalSchema>,
        mode: LocalSchemaMode,
    },
    LoadError {
        file_name: String,
        format: LocalSchemaFormat,
        message_type: Option<String>,
        framing: Framing,
        mode: LocalSchemaMode,
        error: LocalDecodeError,
    },
}

impl SideLocalSchema {
    pub fn mode(&self) -> LocalSchemaMode {
        match self {
            Self::Loaded { mode, .. } | Self::LoadError { mode, .. } => *mode,
        }
    }

    pub fn load_error(&self) -> Option<(&str, &LocalDecodeError)> {
        match self {
            Self::LoadError {
                file_name, error, ..
            } => Some((file_name.as_str(), error)),
            Self::Loaded { .. } => None,
        }
    }
}

#[derive(Clone, Default)]
pub struct LoadedTopicLocalSchemas {
    pub key: Option<SideLocalSchema>,
    pub value: Option<SideLocalSchema>,
}

pub fn base_file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .and_then(|s| s.to_str())
        .filter(|s| !s.is_empty())
        .unwrap_or("<schema>")
        .to_string()
}

pub fn read_local_schema_file(
    path: &str,
    format: Option<LocalSchemaFormat>,
    message_type: Option<&str>,
    framing: Framing,
) -> Result<LoadedLocalSchema, LocalDecodeError> {
    let file_name = base_file_name(path);
    let meta = match std::fs::metadata(path) {
        Ok(m) => m,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::FileNotFound,
                format!("Local schema file '{file_name}' was not found"),
            ));
        }
        Err(e) => {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::FileUnreadable,
                format!("Cannot stat '{file_name}': {}", e.kind()),
            ));
        }
    };

    if !meta.is_file() {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::FileUnreadable,
            format!("'{file_name}' is not a regular file"),
        ));
    }

    if meta.len() > MAX_LOCAL_SCHEMA_BYTES {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::FileTooLarge,
            format!(
                "Local schema file '{file_name}' exceeds the {} MiB limit ({} bytes)",
                MAX_LOCAL_SCHEMA_BYTES / (1024 * 1024),
                meta.len()
            ),
        ));
    }

    let bytes = match std::fs::read(path) {
        Ok(b) => b,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::FileNotFound,
                format!("Local schema file '{file_name}' was not found"),
            ));
        }
        Err(e) => {
            return Err(LocalDecodeError::new(
                LocalDecodeErrorKind::FileUnreadable,
                format!("Cannot read '{file_name}': {}", e.kind()),
            ));
        }
    };

    if bytes.len() as u64 > MAX_LOCAL_SCHEMA_BYTES {
        return Err(LocalDecodeError::new(
            LocalDecodeErrorKind::FileTooLarge,
            format!(
                "Local schema file '{file_name}' exceeds the {} MiB limit",
                MAX_LOCAL_SCHEMA_BYTES / (1024 * 1024)
            ),
        ));
    }

    let resolved_format = format
        .or_else(|| guess_format(&file_name, &bytes))
        .ok_or_else(|| {
            LocalDecodeError::new(
                LocalDecodeErrorKind::SchemaInvalid,
                format!("Cannot determine schema format for '{file_name}'"),
            )
        })?;

    load_local_schema(&file_name, &bytes, resolved_format, message_type, framing)
}

pub fn load_side_assignment(assignment: &LocalSchemaAssignment) -> SideLocalSchema {
    let file_name = base_file_name(&assignment.path);
    match read_local_schema_file(
        &assignment.path,
        Some(assignment.format),
        assignment.message_type.as_deref(),
        assignment.framing,
    ) {
        Ok(loaded) => SideLocalSchema::Loaded {
            schema: Arc::new(loaded),
            mode: assignment.mode,
        },
        Err(error) => SideLocalSchema::LoadError {
            file_name,
            format: assignment.format,
            message_type: assignment.message_type.clone(),
            framing: assignment.framing,
            mode: assignment.mode,
            error,
        },
    }
}

pub fn load_topic_local_schemas(
    local_schemas: Option<&TopicLocalSchemas>,
) -> LoadedTopicLocalSchemas {
    let Some(ls) = local_schemas else {
        return LoadedTopicLocalSchemas::default();
    };
    LoadedTopicLocalSchemas {
        key: ls.key.as_ref().map(load_side_assignment),
        value: ls.value.as_ref().map(load_side_assignment),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs::OpenOptions;

    #[test]
    fn loader_handles_missing_dir_oversize_and_valid_avsc() {
        let dir = std::env::temp_dir().join(format!(
            "kafkalyzer_local_schema_test_{}",
            std::process::id()
        ));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();

        // Missing file
        let missing = dir.join("missing.avsc");
        let err_missing = read_local_schema_file(
            missing.to_str().unwrap(),
            Some(LocalSchemaFormat::Avro),
            None,
            Framing::Auto,
        )
        .err()
        .unwrap();
        assert_eq!(err_missing.kind, LocalDecodeErrorKind::FileNotFound);
        assert!(err_missing.detail.contains("missing.avsc"));
        assert!(!err_missing.detail.contains(dir.to_str().unwrap()));

        // Directory instead of regular file
        let err_dir = read_local_schema_file(
            dir.to_str().unwrap(),
            Some(LocalSchemaFormat::Avro),
            None,
            Framing::Auto,
        )
        .err()
        .unwrap();
        assert_eq!(err_dir.kind, LocalDecodeErrorKind::FileUnreadable);

        // Over-size sparse file (> 10 MiB)
        let big = dir.join("big.avsc");
        let f = OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(true)
            .open(&big)
            .unwrap();
        f.set_len(MAX_LOCAL_SCHEMA_BYTES + 1).unwrap();
        let err_big = read_local_schema_file(
            big.to_str().unwrap(),
            Some(LocalSchemaFormat::Avro),
            None,
            Framing::Auto,
        )
        .err()
        .unwrap();
        assert_eq!(err_big.kind, LocalDecodeErrorKind::FileTooLarge);

        // Valid .avsc
        let valid = dir.join("orders.avsc");
        let avro_json =
            r#"{"type":"record","name":"Order","fields":[{"name":"id","type":"string"}]}"#;
        std::fs::write(&valid, avro_json).unwrap();
        let loaded =
            read_local_schema_file(valid.to_str().unwrap(), None, None, Framing::Auto).unwrap();
        assert_eq!(loaded.file_name, "orders.avsc");
        assert_eq!(loaded.format, LocalSchemaFormat::Avro);
        assert_eq!(loaded.field_model.fields.len(), 1);

        let _ = std::fs::remove_dir_all(&dir);
    }
}
