//! Shared-profile allowlist and internal-topic rule (design D7).

use std::collections::HashSet;
use std::path::{Path, PathBuf};

use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_profiles::{read_shared, ProfileReadError, SecretStore, SharedProfile};

/// Errors from resolving or listing shared clusters.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ClusterError {
    /// Cluster name is not shared, or excluded by `--cluster`. Same message either way.
    NotAvailable { name: String },
    /// Several clusters are available and no name was given.
    Ambiguous { available: Vec<String> },
    /// Shared profiles file exists but cannot be read or parsed.
    Unreadable { message: String },
    /// A recorded secret for the profile is missing from the store.
    MissingSecret { profile: String, field: String },
    /// Topic is internal and `include_internal` was not set.
    InternalTopic { topic: String },
}

impl ClusterError {
    pub fn message(&self) -> String {
        match self {
            ClusterError::NotAvailable { name } => {
                format!("cluster '{name}' is not available to the server")
            }
            ClusterError::Ambiguous { available } => {
                format!("cluster name required; available: {}", available.join(", "))
            }
            ClusterError::Unreadable { message } => {
                format!("shared profiles cannot be read: {message}")
            }
            ClusterError::MissingSecret { profile, field } => {
                format!("shared secret for profile '{profile}' field '{field}' is missing")
            }
            ClusterError::InternalTopic { topic } => {
                format!("topic '{topic}' is internal; pass include_internal to allow it")
            }
        }
    }
}

/// Runtime allowlist: path to shared-profiles.json, secret store, optional `--cluster` names.
pub struct Clusters {
    path: PathBuf,
    /// Empty means every shared profile is allowed.
    restrict_to: HashSet<String>,
}

impl Clusters {
    pub fn new(path: impl Into<PathBuf>, restrict_to: impl IntoIterator<Item = String>) -> Self {
        Self {
            path: path.into(),
            restrict_to: restrict_to.into_iter().collect(),
        }
    }

    pub fn path(&self) -> &Path {
        &self.path
    }

    /// `true` when the topic name is treated as internal (`_` prefix).
    pub fn is_internal_topic(name: &str) -> bool {
        name.starts_with('_')
    }

    /// Refuse internal topics unless `include_internal` is set.
    pub fn ensure_topic_allowed(topic: &str, include_internal: bool) -> Result<(), ClusterError> {
        if Self::is_internal_topic(topic) && !include_internal {
            return Err(ClusterError::InternalTopic {
                topic: topic.to_string(),
            });
        }
        Ok(())
    }

    /// Profiles available after applying `--cluster`. Missing file → empty.
    /// Unreadable file → error. Profiles with missing secrets are omitted from
    /// the list but surface as [`ClusterError::MissingSecret`] on [`Self::resolve`].
    pub fn list(&self, store: &dyn SecretStore) -> Result<Vec<SharedProfile>, ClusterError> {
        let loaded = self.load(store)?;
        Ok(loaded
            .into_iter()
            .filter_map(|r| r.ok())
            .filter(|p| self.is_allowed(&p.profile.name))
            .collect())
    }

    /// Resolve a cluster for a tool call. Reads shared profiles on every call.
    pub fn resolve(
        &self,
        store: &dyn SecretStore,
        name: Option<&str>,
    ) -> Result<ClusterProfile, ClusterError> {
        let loaded = self.load(store)?;
        let mut available: Vec<SharedProfile> = Vec::new();
        let mut missing_for_name: Option<ClusterError> = None;

        for entry in loaded {
            match entry {
                Ok(shared) => {
                    if self.is_allowed(&shared.profile.name) {
                        available.push(shared);
                    }
                }
                Err(ProfileReadError::MissingSecret { profile, field }) => {
                    if name == Some(profile.as_str()) {
                        missing_for_name = Some(ClusterError::MissingSecret {
                            profile,
                            field: field.as_str().to_string(),
                        });
                    }
                }
            }
        }

        if let Some(err) = missing_for_name {
            return Err(err);
        }

        match name {
            Some(n) => available
                .into_iter()
                .find(|p| p.profile.name == n)
                .map(|p| p.profile)
                .ok_or_else(|| ClusterError::NotAvailable {
                    name: n.to_string(),
                }),
            None => match available.len() {
                0 => Err(ClusterError::NotAvailable {
                    name: String::new(),
                }),
                1 => Ok(available.pop().unwrap().profile),
                _ => {
                    let names: Vec<String> =
                        available.into_iter().map(|p| p.profile.name).collect();
                    Err(ClusterError::Ambiguous { available: names })
                }
            },
        }
    }

    fn is_allowed(&self, name: &str) -> bool {
        self.restrict_to.is_empty() || self.restrict_to.contains(name)
    }

    fn load(
        &self,
        store: &dyn SecretStore,
    ) -> Result<Vec<Result<SharedProfile, ProfileReadError>>, ClusterError> {
        if !self.path.exists() {
            return Ok(Vec::new());
        }
        read_shared(&self.path, store).map_err(|e| ClusterError::Unreadable {
            message: e.to_string(),
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_profiles::{write_shared, MemorySecretStore, SharedProfileInput};
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn tmp_path(label: &str) -> PathBuf {
        let nanos = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let dir = std::env::temp_dir().join(format!("kafkalyzer-mcp-clusters-{label}-{nanos}"));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir.join("shared-profiles.json")
    }

    fn input(name: &str, password: Option<&str>) -> SharedProfileInput {
        SharedProfileInput {
            profile: ClusterProfile {
                name: name.into(),
                bootstrap_servers: "broker:9092".into(),
                sasl_password: password.map(str::to_string),
                ..ClusterProfile::default()
            },
            environment_label: Some("test".into()),
        }
    }

    #[test]
    fn missing_file_lists_nothing() {
        let path = tmp_path("missing");
        let store = MemorySecretStore::new();
        let clusters = Clusters::new(&path, None::<String>);
        let listed = clusters.list(&store).unwrap();
        assert!(listed.is_empty());
    }

    #[test]
    fn unshared_and_excluded_give_same_not_available() {
        let path = tmp_path("allow");
        let store = MemorySecretStore::new();
        let report = write_shared(&path, &store, &[input("orders-test", Some("pw"))]);
        assert!(report.file_error.is_none());

        let open = Clusters::new(&path, None::<String>);
        let err_unshared = open.resolve(&store, Some("orders-prod")).unwrap_err();
        assert!(matches!(
            err_unshared,
            ClusterError::NotAvailable { ref name } if name == "orders-prod"
        ));

        let restricted = Clusters::new(&path, ["orders-test".into()]);
        // Excluded by --cluster — same error shape as unshared.
        let err_excluded = restricted.resolve(&store, Some("orders-prod")).unwrap_err();
        assert_eq!(err_unshared, err_excluded);
        assert!(err_unshared.message().contains("not available"));

        let _ = fs::remove_file(&path);
    }

    #[test]
    fn restrict_hides_other_shared_clusters() {
        let path = tmp_path("restrict");
        let store = MemorySecretStore::new();
        let report = write_shared(
            &path,
            &store,
            &[
                input("orders-test", Some("a")),
                input("orders-prod", Some("b")),
            ],
        );
        assert!(report.file_error.is_none());

        let clusters = Clusters::new(&path, ["orders-test".into()]);
        let listed = clusters.list(&store).unwrap();
        assert_eq!(listed.len(), 1);
        assert_eq!(listed[0].profile.name, "orders-test");

        let err = clusters.resolve(&store, Some("orders-prod")).unwrap_err();
        assert!(matches!(err, ClusterError::NotAvailable { .. }));

        let _ = fs::remove_file(&path);
    }

    #[test]
    fn missing_secret_is_error_on_resolve() {
        // File lists a secret field but the store has no value for it.
        let path = tmp_path("secret");
        fs::write(
            &path,
            r#"{"version":1,"profiles":[{"profile":{"name":"a","bootstrap_servers":"broker:9092"},"secret_fields":["sasl_password"]}]}"#,
        )
        .unwrap();
        let store = MemorySecretStore::new();
        let clusters = Clusters::new(&path, None::<String>);
        let err = clusters.resolve(&store, Some("a")).unwrap_err();
        assert!(matches!(
            err,
            ClusterError::MissingSecret { ref profile, .. } if profile == "a"
        ));
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn unreadable_file_is_error() {
        let path = tmp_path("bad");
        fs::write(&path, "not-json{{{").unwrap();
        let store = MemorySecretStore::new();
        let clusters = Clusters::new(&path, None::<String>);
        let err = clusters.list(&store).unwrap_err();
        assert!(matches!(err, ClusterError::Unreadable { .. }));
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn default_cluster_when_exactly_one() {
        let path = tmp_path("one");
        let store = MemorySecretStore::new();
        let report = write_shared(&path, &store, &[input("solo", Some("pw"))]);
        assert!(report.file_error.is_none());
        let clusters = Clusters::new(&path, None::<String>);
        let profile = clusters.resolve(&store, None).unwrap();
        assert_eq!(profile.name, "solo");
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn ambiguous_when_several_and_no_name() {
        let path = tmp_path("many");
        let store = MemorySecretStore::new();
        let report = write_shared(
            &path,
            &store,
            &[input("a", Some("1")), input("b", Some("2"))],
        );
        assert!(report.file_error.is_none());
        let clusters = Clusters::new(&path, None::<String>);
        let err = clusters.resolve(&store, None).unwrap_err();
        assert!(matches!(err, ClusterError::Ambiguous { .. }));
        let _ = fs::remove_file(&path);
    }

    #[test]
    fn internal_topic_rule() {
        assert!(Clusters::is_internal_topic("__consumer_offsets"));
        assert!(Clusters::is_internal_topic("_schemas"));
        assert!(!Clusters::is_internal_topic("orders"));
        assert!(Clusters::ensure_topic_allowed("__consumer_offsets", false).is_err());
        assert!(Clusters::ensure_topic_allowed("__consumer_offsets", true).is_ok());
        assert!(Clusters::ensure_topic_allowed("orders", false).is_ok());
    }
}
