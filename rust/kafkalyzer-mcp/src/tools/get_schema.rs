use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_core::schema_model::{SchemaKind, SubjectSchema};
use kafkalyzer_kafka::schema_registry::{
    fetch_subject_schema_view, SchemaRegistryError, SubjectSchemaView,
};
use serde::Serialize;

use super::schema_errors::map_registry_error;
use super::{ToolContext, ToolError};
use crate::shape::{cap_text, CappedText, ResultMeta};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct GetSchemaOutput {
    pub subject: String,
    pub version: i32,
    pub id: i32,
    pub schema_type: String,
    pub schema: CappedText,
    pub meta: ResultMeta,
}

fn schema_type_name(kind: &SchemaKind) -> String {
    match kind {
        SchemaKind::Avro => "AVRO".into(),
        SchemaKind::Json => "JSON".into(),
        SchemaKind::Protobuf => "PROTOBUF".into(),
        SchemaKind::Other(name) => name.clone(),
    }
}

pub fn map_schema_view(
    view: SubjectSchemaView,
    max_schema_bytes: usize,
    limits: &crate::limits::Limits,
) -> GetSchemaOutput {
    let SubjectSchema {
        subject,
        version,
        id,
        schema_type,
        schema,
        ..
    } = view.schema;
    GetSchemaOutput {
        subject,
        version,
        id,
        schema_type: schema_type_name(&schema_type),
        schema: cap_text(&schema, max_schema_bytes),
        meta: ResultMeta::new(limits),
    }
}

pub fn kafka_get_schema(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    subject: &str,
    version: Option<i32>,
) -> Result<GetSchemaOutput, ToolError> {
    kafka_get_schema_with(ctx, cluster, subject, version, |profile, sub, ver| {
        fetch_subject_schema_view(profile, sub, ver)
    })
}

pub fn kafka_get_schema_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    subject: &str,
    version: Option<i32>,
    fetch: F,
) -> Result<GetSchemaOutput, ToolError>
where
    F: FnOnce(
        ClusterProfile,
        String,
        Option<i32>,
    ) -> Result<SubjectSchemaView, SchemaRegistryError>,
{
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let view = fetch(profile.clone(), subject.to_string(), version)
        .map_err(|e| map_registry_error(e, &profile))?;
    Ok(map_schema_view(
        view,
        ctx.limits.max_schema_bytes,
        &ctx.limits,
    ))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
    use kafkalyzer_core::schema_model::SchemaFieldModel;
    use kafkalyzer_kafka::schema_registry::SchemaRegistryErrorKind;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::sync::atomic::AtomicBool;
    use std::sync::Arc;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn setup() -> (std::path::PathBuf, MemorySecretStore, Clusters) {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-get-schema-{nanos}"));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("shared-profiles.json");
        let store = MemorySecretStore::new();
        let report = write_shared(
            &path,
            &store,
            &[SharedProfileInput {
                profile: ClusterProfile {
                    name: "local".into(),
                    bootstrap_servers: "localhost:9094".into(),
                    ..ClusterProfile::default()
                },
                environment_label: None,
            }],
        );
        assert!(report.file_error.is_none());
        (dir, store, Clusters::new(&path, None::<String>))
    }

    fn view(schema_text: &str) -> SubjectSchemaView {
        SubjectSchemaView {
            schema: SubjectSchema {
                subject: "orders-value".into(),
                version: 1,
                id: 42,
                schema_type: SchemaKind::Avro,
                schema: schema_text.into(),
                references: vec![],
            },
            fields: SchemaFieldModel {
                kind: SchemaKind::Avro,
                root_name: None,
                messages: vec![],
                fields: vec![],
                truncated: false,
                unavailable_reason: None,
            },
        }
    }

    #[test]
    fn schema_text_is_capped() {
        let (dir, store, clusters) = setup();
        let mut limits = Limits::defaults();
        limits.max_schema_bytes = 8;
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits,
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let out = kafka_get_schema_with(&ctx, Some("local"), "orders-value", None, |_, _, _| {
            Ok(view("0123456789abcdef"))
        })
        .unwrap();
        assert_eq!(out.schema.text, "01234567");
        assert_eq!(out.schema.original_size, Some(16));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn not_found_is_distinct_from_unreachable() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let not_found = kafka_get_schema_with(&ctx, Some("local"), "missing", None, |_, _, _| {
            Err(SchemaRegistryError {
                kind: SchemaRegistryErrorKind::NotFound,
                status: Some(404),
                registry_error_code: None,
                detail: "missing".into(),
            })
        })
        .unwrap_err()
        .message();
        let unreachable = kafka_get_schema_with(&ctx, Some("local"), "missing", None, |_, _, _| {
            Err(SchemaRegistryError {
                kind: SchemaRegistryErrorKind::Unreachable,
                status: None,
                registry_error_code: None,
                detail: "down".into(),
            })
        })
        .unwrap_err()
        .message();
        assert!(not_found.contains("not found"));
        assert!(unreachable.contains("unreachable"));
        assert_ne!(not_found, unreachable);
        let _ = fs::remove_dir_all(&dir);
    }
}
