use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_kafka::schema_registry::{fetch_subjects, SchemaRegistryError};
use serde::Serialize;

use super::schema_errors::map_registry_error;
use super::{ToolContext, ToolError};
use crate::shape::{ResultMeta, StopReason};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ListSchemasOutput {
    pub subjects: Vec<String>,
    pub total: usize,
    pub meta: ResultMeta,
}

pub fn kafka_list_schemas(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
) -> Result<ListSchemasOutput, ToolError> {
    kafka_list_schemas_with(ctx, cluster, fetch_subjects)
}

pub fn kafka_list_schemas_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    fetch: F,
) -> Result<ListSchemasOutput, ToolError>
where
    F: FnOnce(ClusterProfile) -> Result<Vec<String>, SchemaRegistryError>,
{
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let mut subjects = fetch(profile.clone()).map_err(|e| map_registry_error(e, &profile))?;
    subjects.sort();
    let total = subjects.len();
    let truncated = total > ctx.limits.max_list_entries;
    if truncated {
        subjects.truncate(ctx.limits.max_list_entries);
    }
    let mut meta = ResultMeta::new(&ctx.limits);
    if truncated {
        meta.stop_reason = Some(StopReason::MessageLimit);
        meta.notes.push(format!(
            "list truncated to {} of {total} subjects",
            ctx.limits.max_list_entries
        ));
    }
    Ok(ListSchemasOutput {
        subjects,
        total,
        meta,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
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
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-list-schemas-{nanos}"));
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

    #[test]
    fn not_configured_is_distinct_error() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let err = kafka_list_schemas_with(&ctx, Some("local"), |_| {
            Err(SchemaRegistryError {
                kind: SchemaRegistryErrorKind::NotConfigured,
                status: None,
                registry_error_code: None,
                detail: "".into(),
            })
        })
        .unwrap_err();
        assert!(err.message().contains("no Schema Registry is configured"));
        let _ = fs::remove_dir_all(&dir);
    }
}
