use std::fs::{self, OpenOptions};
use std::io::Write;
use std::path::Path;

use anyhow::{bail, Context, Result};
use kafkalyzer_core::kafka_types::ClusterProfile;
use log::warn;

#[cfg(unix)]
use std::os::unix::fs::{OpenOptionsExt, PermissionsExt};

use crate::secret_field::SecretField;
use crate::secret_store::SecretStore;
use crate::shared_profile::{
    split_secrets, SharedProfile, SharedProfilesFile, SHARED_PROFILES_VERSION,
};

/// Input to [`write_shared`]: domain profile still holding secrets in memory.
#[derive(Debug, Clone)]
pub struct SharedProfileInput {
    pub profile: ClusterProfile,
    pub environment_label: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SyncFailureKind {
    KeyringUnavailable,
    SecretRejected,
}

#[derive(Debug, Clone)]
pub struct SyncReport {
    pub written: Vec<String>,
    pub failed: Vec<(String, SyncFailureKind)>,
    pub file_error: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ProfileReadError {
    MissingSecret { profile: String, field: SecretField },
}

/// Classifies a keyring/store error without echoing secret values.
pub fn classify_store_error(err: &anyhow::Error) -> SyncFailureKind {
    let text = err.to_string().to_lowercase();
    if text.contains("too large")
        || text.contains("size")
        || text.contains("limit")
        || text.contains("rejected")
        || text.contains("2560")
    {
        SyncFailureKind::SecretRejected
    } else {
        SyncFailureKind::KeyringUnavailable
    }
}

fn read_previous(path: &Path) -> Option<SharedProfilesFile> {
    match fs::read_to_string(path) {
        Ok(text) => match serde_json::from_str::<SharedProfilesFile>(&text) {
            Ok(file) => Some(file),
            Err(e) => {
                warn!("shared profiles file unreadable, treating as empty: {e}");
                None
            }
        },
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => None,
        Err(e) => {
            warn!("shared profiles file unreadable, treating as empty: {e}");
            None
        }
    }
}

fn ensure_parent_dir(path: &Path) -> Result<()> {
    let Some(parent) = path.parent() else {
        return Ok(());
    };
    fs::create_dir_all(parent).with_context(|| format!("create directory {}", parent.display()))?;
    #[cfg(unix)]
    {
        let perms = fs::Permissions::from_mode(0o700);
        fs::set_permissions(parent, perms)
            .with_context(|| format!("set mode on {}", parent.display()))?;
    }
    Ok(())
}

fn atomic_write_json(path: &Path, file: &SharedProfilesFile) -> Result<()> {
    ensure_parent_dir(path)?;
    let parent = path.parent().unwrap_or_else(|| Path::new("."));
    let mut tmp = parent.join(format!(
        ".{}.tmp",
        path.file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("shared-profiles.json")
    ));
    // Unique-ish temp name if parallel writers are unlikely; sibling is enough for atomic rename.
    if tmp.exists() {
        tmp = parent.join(format!(
            ".{}.{}.tmp",
            path.file_name()
                .and_then(|s| s.to_str())
                .unwrap_or("shared-profiles.json"),
            std::process::id()
        ));
    }

    {
        let mut opts = OpenOptions::new();
        opts.write(true).create(true).truncate(true);
        #[cfg(unix)]
        opts.mode(0o600);
        let mut f = opts
            .open(&tmp)
            .with_context(|| format!("create temp file {}", tmp.display()))?;
        let json = serde_json::to_vec_pretty(file).context("serialize shared profiles")?;
        f.write_all(&json)
            .with_context(|| format!("write temp file {}", tmp.display()))?;
        f.sync_all()
            .with_context(|| format!("sync temp file {}", tmp.display()))?;
    }

    #[cfg(unix)]
    {
        let perms = fs::Permissions::from_mode(0o600);
        fs::set_permissions(&tmp, perms)
            .with_context(|| format!("set mode on {}", tmp.display()))?;
    }

    fs::rename(&tmp, path)
        .with_context(|| format!("rename {} over {}", tmp.display(), path.display()))?;
    Ok(())
}

fn store_secrets_for_profile(
    store: &dyn SecretStore,
    name: &str,
    shared: &SharedProfile,
    values: &[(SecretField, String)],
) -> Result<(), SyncFailureKind> {
    for (field, value) in values {
        store
            .set(name, *field, value)
            .map_err(|e| classify_store_error(&e))?;
    }
    for field in SecretField::ALL {
        if !shared.secret_fields.contains(&field) {
            store
                .delete(name, field)
                .map_err(|e| classify_store_error(&e))?;
        }
    }
    Ok(())
}

/// Writes shared profiles: secrets → atomic file → cleanup orphaned keyring entries.
pub fn write_shared(
    path: &Path,
    store: &dyn SecretStore,
    inputs: &[SharedProfileInput],
) -> SyncReport {
    let previous = read_previous(path);
    let previous_by_name: Vec<(String, Vec<SecretField>)> = previous
        .as_ref()
        .map(|f| {
            f.profiles
                .iter()
                .map(|p| (p.profile.name.clone(), p.secret_fields.clone()))
                .collect()
        })
        .unwrap_or_default();

    let mut written_profiles = Vec::new();
    let mut failed = Vec::new();

    for input in inputs {
        let name = input.profile.name.clone();
        let (shared, values) =
            split_secrets(input.profile.clone(), input.environment_label.clone());
        match store_secrets_for_profile(store, &name, &shared, &values) {
            Ok(()) => written_profiles.push(shared),
            Err(kind) => failed.push((name, kind)),
        }
    }

    let written_names: Vec<String> = written_profiles
        .iter()
        .map(|p| p.profile.name.clone())
        .collect();

    let file = SharedProfilesFile {
        version: SHARED_PROFILES_VERSION,
        profiles: written_profiles,
    };

    let file_error = match atomic_write_json(path, &file) {
        Ok(()) => None,
        Err(e) => Some(format!("{e:#}")),
    };

    if file_error.is_none() {
        for (old_name, fields) in &previous_by_name {
            if written_names.iter().any(|n| n == old_name) {
                continue;
            }
            for field in fields {
                if let Err(e) = store.delete(old_name, *field) {
                    warn!(
                        "failed to delete orphaned shared secret for profile {old_name} field {}: {e}",
                        field.as_str()
                    );
                }
            }
        }
    }

    SyncReport {
        written: written_names,
        failed,
        file_error,
    }
}

/// Reads the shared file and restores secrets from `store`.
///
/// Unknown file versions return `Err`. Per-profile missing secrets are `Err` items in the vec.
pub fn read_shared(
    path: &Path,
    store: &dyn SecretStore,
) -> Result<Vec<Result<SharedProfile, ProfileReadError>>> {
    let text = fs::read_to_string(path)
        .with_context(|| format!("read shared profiles {}", path.display()))?;
    let file: SharedProfilesFile =
        serde_json::from_str(&text).context("parse shared profiles JSON")?;
    if file.version != SHARED_PROFILES_VERSION {
        bail!(
            "unknown shared profiles file version {} (supported: {})",
            file.version,
            SHARED_PROFILES_VERSION
        );
    }

    let mut out = Vec::with_capacity(file.profiles.len());
    for mut shared in file.profiles {
        let name = shared.profile.name.clone();
        let mut ok = true;
        for field in &shared.secret_fields {
            match store.get(&name, *field) {
                Ok(Some(value)) => field.put(&mut shared.profile, Some(value)),
                Ok(None) => {
                    out.push(Err(ProfileReadError::MissingSecret {
                        profile: name.clone(),
                        field: *field,
                    }));
                    ok = false;
                    break;
                }
                Err(e) => {
                    return Err(e).context(format!(
                        "read secret for profile {name} field {}",
                        field.as_str()
                    ));
                }
            }
        }
        if ok {
            out.push(Ok(shared));
        }
    }
    Ok(out)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::secret_store::MemorySecretStore;
    use std::path::PathBuf;
    use std::sync::Mutex;

    struct FailingStore {
        inner: MemorySecretStore,
        fail_profile: Mutex<Option<String>>,
    }

    impl FailingStore {
        fn new(fail_on: &str) -> Self {
            Self {
                inner: MemorySecretStore::new(),
                fail_profile: Mutex::new(Some(fail_on.to_string())),
            }
        }
    }

    impl SecretStore for FailingStore {
        fn set(&self, profile: &str, field: SecretField, value: &str) -> Result<()> {
            if self.fail_profile.lock().unwrap().as_deref() == Some(profile) {
                bail!("keyring unavailable for test");
            }
            self.inner.set(profile, field, value)
        }

        fn get(&self, profile: &str, field: SecretField) -> Result<Option<String>> {
            self.inner.get(profile, field)
        }

        fn delete(&self, profile: &str, field: SecretField) -> Result<()> {
            self.inner.delete(profile, field)
        }
    }

    fn input(name: &str, password: Option<&str>) -> SharedProfileInput {
        SharedProfileInput {
            profile: ClusterProfile {
                name: name.into(),
                bootstrap_servers: "broker:9092".into(),
                sasl_password: password.map(str::to_string),
                ..ClusterProfile::default()
            },
            environment_label: None,
        }
    }

    fn temp_path(label: &str) -> PathBuf {
        let mut dir = std::env::temp_dir();
        dir.push(format!(
            "kafkalyzer-profiles-{}-{}",
            label,
            std::process::id()
        ));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        dir.join("shared-profiles.json")
    }

    #[test]
    fn write_add_edit_rename_delete_unshare() {
        let path = temp_path("crud");
        let store = MemorySecretStore::new();

        // add
        let report = write_shared(&path, &store, &[input("a", Some("p1"))]);
        assert_eq!(report.written, vec!["a".to_string()]);
        assert!(report.failed.is_empty());
        assert!(report.file_error.is_none());
        assert_eq!(
            store
                .get("a", SecretField::SaslPassword)
                .unwrap()
                .as_deref(),
            Some("p1")
        );

        // edit secret
        let report = write_shared(&path, &store, &[input("a", Some("p2"))]);
        assert_eq!(report.written, vec!["a".to_string()]);
        assert_eq!(
            store
                .get("a", SecretField::SaslPassword)
                .unwrap()
                .as_deref(),
            Some("p2")
        );

        // rename a -> b
        let report = write_shared(&path, &store, &[input("b", Some("p2"))]);
        assert_eq!(report.written, vec!["b".to_string()]);
        assert_eq!(store.get("a", SecretField::SaslPassword).unwrap(), None);
        assert_eq!(
            store
                .get("b", SecretField::SaslPassword)
                .unwrap()
                .as_deref(),
            Some("p2")
        );

        // unshare / delete (empty input)
        let report = write_shared(&path, &store, &[]);
        assert!(report.written.is_empty());
        assert_eq!(store.get("b", SecretField::SaslPassword).unwrap(), None);
        let file: SharedProfilesFile =
            serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        assert!(file.profiles.is_empty());
    }

    #[test]
    fn store_failure_excludes_only_that_profile() {
        let path = temp_path("fail-one");
        let store = FailingStore::new("bad");
        let report = write_shared(
            &path,
            &store,
            &[input("ok", Some("x")), input("bad", Some("y"))],
        );
        assert_eq!(report.written, vec!["ok".to_string()]);
        assert_eq!(
            report.failed,
            vec![("bad".to_string(), SyncFailureKind::KeyringUnavailable)]
        );
        let file: SharedProfilesFile =
            serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(file.profiles.len(), 1);
        assert_eq!(file.profiles[0].profile.name, "ok");
    }

    #[test]
    fn unreadable_previous_file_is_replaced() {
        let path = temp_path("bad-json");
        fs::write(&path, "not-json{{{").unwrap();
        let store = MemorySecretStore::new();
        let report = write_shared(&path, &store, &[input("a", Some("p"))]);
        assert_eq!(report.written, vec!["a".to_string()]);
        assert!(report.file_error.is_none());
        let file: SharedProfilesFile =
            serde_json::from_str(&fs::read_to_string(&path).unwrap()).unwrap();
        assert_eq!(file.profiles.len(), 1);
    }

    #[test]
    fn unwritable_directory_sets_file_error() {
        let path = PathBuf::from("/proc/kafkalyzer-profiles-no-write/shared-profiles.json");
        let store = MemorySecretStore::new();
        let report = write_shared(&path, &store, &[input("a", Some("p"))]);
        assert!(report.file_error.is_some());
    }

    #[test]
    #[cfg(unix)]
    fn unix_file_mode_is_owner_only() {
        let path = temp_path("mode");
        let store = MemorySecretStore::new();
        let report = write_shared(&path, &store, &[input("a", Some("p"))]);
        assert!(report.file_error.is_none());
        let mode = fs::metadata(&path).unwrap().permissions().mode() & 0o777;
        assert_eq!(mode, 0o600);
        let dir_mode = fs::metadata(path.parent().unwrap())
            .unwrap()
            .permissions()
            .mode()
            & 0o777;
        assert_eq!(dir_mode, 0o700);
    }

    #[test]
    fn read_restores_secrets_and_reports_missing() {
        let path = temp_path("read");
        let store = MemorySecretStore::new();
        write_shared(&path, &store, &[input("a", Some("secret-a"))]);

        let restored = read_shared(&path, &store).unwrap();
        assert_eq!(restored.len(), 1);
        let shared = restored[0].as_ref().unwrap();
        assert_eq!(shared.profile.sasl_password.as_deref(), Some("secret-a"));

        store.delete("a", SecretField::SaslPassword).unwrap();
        let restored = read_shared(&path, &store).unwrap();
        match &restored[0] {
            Err(ProfileReadError::MissingSecret { profile, field }) => {
                assert_eq!(profile, "a");
                assert_eq!(*field, SecretField::SaslPassword);
            }
            other => panic!("expected missing secret, got {other:?}"),
        }
    }

    #[test]
    fn unknown_file_version_is_error() {
        let path = temp_path("version");
        fs::write(&path, r#"{"version":99,"profiles":[]}"#).unwrap();
        let store = MemorySecretStore::new();
        let err = read_shared(&path, &store).unwrap_err();
        assert!(err
            .to_string()
            .contains("unknown shared profiles file version"));
    }
}
