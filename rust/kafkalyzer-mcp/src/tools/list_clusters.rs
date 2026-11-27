use serde::Serialize;

use super::{ToolContext, ToolError};
use crate::shape::ResultMeta;

/// Non-secret attributes of one shared cluster (spec: Cluster And Connection Tools).
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ClusterInfo {
    pub name: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub environment: Option<String>,
    pub security_protocol: String,
    pub schema_registry_configured: bool,
    pub tls_verification_disabled: bool,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct ListClustersOutput {
    pub clusters: Vec<ClusterInfo>,
    pub meta: ResultMeta,
}

/// List clusters available to this server process.
pub fn kafka_list_clusters(ctx: &ToolContext<'_>) -> Result<ListClustersOutput, ToolError> {
    let shared = ctx.clusters.list(ctx.store)?;
    let clusters = shared
        .into_iter()
        .map(|s| {
            let p = &s.profile;
            ClusterInfo {
                name: p.name.clone(),
                environment: s.environment_label.clone(),
                security_protocol: p.effective_security_protocol(),
                schema_registry_configured: p
                    .schema_registry_url
                    .as_deref()
                    .is_some_and(|u| !u.trim().is_empty()),
                tls_verification_disabled: p.ssl_verification_disabled,
            }
        })
        .collect();
    Ok(ListClustersOutput {
        clusters,
        meta: ResultMeta::new(&ctx.limits),
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::clusters::Clusters;
    use crate::limits::Limits;
    use kafkalyzer_core::kafka_types::ClusterProfile;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::sync::atomic::AtomicBool;
    use std::sync::Arc;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn tmp_dir(label: &str) -> std::path::PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-list-{label}-{nanos}"));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir
    }

    #[test]
    fn list_clusters_has_exactly_documented_attributes() {
        let dir = tmp_dir("attrs");
        let path = dir.join("shared-profiles.json");
        let store = MemorySecretStore::new();
        let report = write_shared(
            &path,
            &store,
            &[
                SharedProfileInput {
                    profile: ClusterProfile {
                        name: "orders-test".into(),
                        bootstrap_servers: "secret-broker:9092".into(),
                        sasl_username: Some("alice".into()),
                        sasl_password: Some("pw".into()),
                        security_protocol: Some("SASL_SSL".into()),
                        schema_registry_url: Some("https://sr.example".into()),
                        ssl_verification_disabled: true,
                        ssl_keystore_location: Some("/secret/path.jks".into()),
                        ..ClusterProfile::default()
                    },
                    environment_label: Some("staging".into()),
                },
                SharedProfileInput {
                    profile: ClusterProfile {
                        name: "plain".into(),
                        bootstrap_servers: "localhost:9092".into(),
                        ..ClusterProfile::default()
                    },
                    environment_label: None,
                },
            ],
        );
        assert!(report.file_error.is_none());

        let clusters = Clusters::new(&path, None::<String>);
        let ctx = ToolContext {
            clusters: &clusters,
            store: &store,
            limits: Limits::defaults(),
            cancel: Arc::new(AtomicBool::new(false)),
        };
        let out = kafka_list_clusters(&ctx).unwrap();
        assert_eq!(out.clusters.len(), 2);

        let first = out
            .clusters
            .iter()
            .find(|c| c.name == "orders-test")
            .unwrap();
        assert_eq!(first.environment.as_deref(), Some("staging"));
        assert_eq!(first.security_protocol, "SASL_SSL");
        assert!(first.schema_registry_configured);
        assert!(first.tls_verification_disabled);

        let plain = out.clusters.iter().find(|c| c.name == "plain").unwrap();
        assert!(plain.environment.is_none());
        assert_eq!(plain.security_protocol, "PLAINTEXT");
        assert!(!plain.schema_registry_configured);
        assert!(!plain.tls_verification_disabled);

        let json = serde_json::to_value(&out.clusters).unwrap();
        for cluster in json.as_array().unwrap() {
            let obj = cluster.as_object().unwrap();
            for key in obj.keys() {
                assert!(
                    matches!(
                        key.as_str(),
                        "name"
                            | "environment"
                            | "security_protocol"
                            | "schema_registry_configured"
                            | "tls_verification_disabled"
                    ),
                    "unexpected attribute {key}"
                );
            }
            assert!(!obj.contains_key("bootstrap_servers"));
            assert!(!obj.contains_key("sasl_username"));
            assert!(!obj.contains_key("sasl_password"));
            assert!(!obj.contains_key("ssl_keystore_location"));
        }

        let _ = fs::remove_dir_all(&dir);
    }
}
