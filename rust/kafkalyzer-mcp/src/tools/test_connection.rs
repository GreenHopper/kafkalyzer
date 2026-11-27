use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_kafka::kafka_metadata::validate_connection;
use serde::Serialize;

use super::{ToolContext, ToolError};
use crate::shape::{redact, ResultMeta};

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TestConnectionOutput {
    pub cluster: String,
    pub reachable: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reason: Option<String>,
    pub meta: ResultMeta,
}

/// Probe whether the shared profile can reach its broker.
pub fn kafka_test_connection(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
) -> Result<TestConnectionOutput, ToolError> {
    kafka_test_connection_with(ctx, cluster, |profile| {
        validate_connection(profile).map_err(|e| e.to_string())
    })
}

/// Testable entry that injects the connection probe.
pub fn kafka_test_connection_with<F>(
    ctx: &ToolContext<'_>,
    cluster: Option<&str>,
    probe: F,
) -> Result<TestConnectionOutput, ToolError>
where
    F: FnOnce(ClusterProfile) -> Result<bool, String>,
{
    let profile = ctx.clusters.resolve(ctx.store, cluster)?;
    let name = profile.name.clone();
    match probe(profile.clone()) {
        Ok(true) => Ok(TestConnectionOutput {
            cluster: name,
            reachable: true,
            reason: None,
            meta: ResultMeta::new(&ctx.limits),
        }),
        Ok(false) => Ok(TestConnectionOutput {
            cluster: name,
            reachable: false,
            reason: Some("connection check returned false".into()),
            meta: ResultMeta::new(&ctx.limits),
        }),
        Err(err) => Ok(TestConnectionOutput {
            cluster: name,
            reachable: false,
            reason: Some(redact(&err, &profile)),
            meta: ResultMeta::new(&ctx.limits),
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
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
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-conn-{nanos}"));
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("shared-profiles.json");
        let store = MemorySecretStore::new();
        let report = write_shared(
            &path,
            &store,
            &[SharedProfileInput {
                profile: ClusterProfile {
                    name: "local".into(),
                    bootstrap_servers: "localhost:1".into(),
                    sasl_password: Some("super-secret-pw".into()),
                    ..ClusterProfile::default()
                },
                environment_label: None,
            }],
        );
        assert!(report.file_error.is_none());
        let clusters = Clusters::new(&path, None::<String>);
        (dir, store, clusters)
    }

    #[test]
    fn connection_failure_is_not_reachable_and_redacts_secret() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let out = kafka_test_connection_with(&ctx, Some("local"), |_| {
            Err("auth failed with password super-secret-pw".into())
        })
        .unwrap();
        assert!(!out.reachable);
        let reason = out.reason.unwrap();
        assert!(!reason.contains("super-secret-pw"));
        assert!(reason.contains("[redacted]"));
        let _ = fs::remove_dir_all(&dir);
    }

    #[test]
    fn connection_success_is_reachable() {
        let (dir, store, clusters) = setup();
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let out = kafka_test_connection_with(&ctx, Some("local"), |_| Ok(true)).unwrap();
        assert!(out.reachable);
        assert!(out.reason.is_none());
        let _ = fs::remove_dir_all(&dir);
    }
}
