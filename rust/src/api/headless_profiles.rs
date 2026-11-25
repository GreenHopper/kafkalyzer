use std::path::{Path, PathBuf};

use kafkalyzer_profiles::{
    default_path, write_shared, KeyringSecretStore, SecretStore, SharedProfileInput,
    SyncFailureKind, SyncReport,
};

use crate::api::kafka_types::ClusterProfile;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SharedProfileFailureKind {
    KeyringUnavailable,
    SecretRejected,
}

impl From<SyncFailureKind> for SharedProfileFailureKind {
    fn from(kind: SyncFailureKind) -> Self {
        match kind {
            SyncFailureKind::KeyringUnavailable => SharedProfileFailureKind::KeyringUnavailable,
            SyncFailureKind::SecretRejected => SharedProfileFailureKind::SecretRejected,
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SharedProfileFailure {
    pub name: String,
    pub kind: SharedProfileFailureKind,
}

#[derive(Debug, Clone)]
pub struct SharedProfilesSyncRequest {
    pub profiles: Vec<ClusterProfile>,
}

#[derive(Debug, Clone)]
pub struct SharedProfilesSyncResult {
    pub failed: Vec<SharedProfileFailure>,
    pub file_error: Option<String>,
    pub file_path: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct McpServerLaunch {
    pub command: String,
    pub leading_args: Vec<String>,
    pub exists: bool,
}

/// Profiles marked `headless_shared == Some(true)`, mapped for [`write_shared`].
pub(crate) fn shared_inputs(profiles: &[ClusterProfile]) -> Vec<SharedProfileInput> {
    profiles
        .iter()
        .filter(|p| p.headless_shared == Some(true))
        .map(|p| SharedProfileInput {
            profile: p.to_domain(),
            environment_label: p.environment_label.clone(),
        })
        .collect()
}

fn report_to_result(path: &Path, report: SyncReport) -> SharedProfilesSyncResult {
    SharedProfilesSyncResult {
        failed: report
            .failed
            .into_iter()
            .map(|(name, kind)| SharedProfileFailure {
                name,
                kind: kind.into(),
            })
            .collect(),
        file_error: report.file_error,
        file_path: path.display().to_string(),
    }
}

pub(crate) fn sync_shared_profiles_with(
    path: &Path,
    store: &dyn SecretStore,
    request: SharedProfilesSyncRequest,
) -> SharedProfilesSyncResult {
    let inputs = shared_inputs(&request.profiles);
    let report = write_shared(path, store, &inputs);
    report_to_result(path, report)
}

/// Syncs shared profiles to the user config file and the dedicated keyring service.
pub fn sync_shared_profiles(request: SharedProfilesSyncRequest) -> SharedProfilesSyncResult {
    let path = match default_path() {
        Ok(path) => path,
        Err(e) => {
            return SharedProfilesSyncResult {
                failed: Vec::new(),
                file_error: Some(format!("{e:#}")),
                file_path: String::new(),
            };
        }
    };
    sync_shared_profiles_with(&path, &KeyringSecretStore::new(), request)
}

/// Resolves how an MCP client should launch `kafkalyzer-mcp` next to this app binary.
pub fn mcp_server_launch() -> McpServerLaunch {
    mcp_server_launch_with_env(|key| std::env::var(key).ok(), std::env::current_exe().ok())
}

pub(crate) fn mcp_server_launch_with_env(
    env: impl Fn(&str) -> Option<String>,
    current_exe: Option<PathBuf>,
) -> McpServerLaunch {
    if let Some(appimage) = env("APPIMAGE").filter(|v| !v.is_empty()) {
        let exists = Path::new(&appimage).is_file();
        return McpServerLaunch {
            command: appimage,
            leading_args: vec!["--mcp".to_string()],
            exists,
        };
    }

    let mut command = current_exe
        .and_then(|exe| exe.parent().map(|dir| dir.to_path_buf()))
        .unwrap_or_else(|| PathBuf::from("."));
    #[cfg(windows)]
    command.push("kafkalyzer-mcp.exe");
    #[cfg(not(windows))]
    command.push("kafkalyzer-mcp");

    let exists = command.is_file();
    McpServerLaunch {
        command: command.display().to_string(),
        leading_args: Vec::new(),
        exists,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_profiles::MemorySecretStore;
    use std::fs;

    #[test]
    fn only_some_true_profiles_are_passed_on() {
        let profiles = vec![
            ClusterProfile {
                name: "shared".into(),
                bootstrap_servers: "b:9092".into(),
                headless_shared: Some(true),
                environment_label: Some("PROD".into()),
                sasl_password: Some("secret".into()),
                ..ClusterProfile::default()
            },
            ClusterProfile {
                name: "off".into(),
                bootstrap_servers: "b:9092".into(),
                headless_shared: Some(false),
                sasl_password: Some("nope".into()),
                ..ClusterProfile::default()
            },
            ClusterProfile {
                name: "legacy".into(),
                bootstrap_servers: "b:9092".into(),
                headless_shared: None,
                ..ClusterProfile::default()
            },
        ];

        let inputs = shared_inputs(&profiles);
        assert_eq!(inputs.len(), 1);
        assert_eq!(inputs[0].profile.name, "shared");
        assert_eq!(inputs[0].environment_label.as_deref(), Some("PROD"));
        assert_eq!(inputs[0].profile.sasl_password.as_deref(), Some("secret"));
    }

    #[test]
    fn failure_kinds_map_one_to_one() {
        assert_eq!(
            SharedProfileFailureKind::from(SyncFailureKind::KeyringUnavailable),
            SharedProfileFailureKind::KeyringUnavailable
        );
        assert_eq!(
            SharedProfileFailureKind::from(SyncFailureKind::SecretRejected),
            SharedProfileFailureKind::SecretRejected
        );
    }

    #[test]
    fn sync_writes_only_shared_profiles() {
        let dir =
            std::env::temp_dir().join(format!("kafkalyzer-headless-sync-{}", std::process::id()));
        let _ = fs::remove_dir_all(&dir);
        fs::create_dir_all(&dir).unwrap();
        let path = dir.join("shared-profiles.json");
        let store = MemorySecretStore::new();

        let result = sync_shared_profiles_with(
            &path,
            &store,
            SharedProfilesSyncRequest {
                profiles: vec![
                    ClusterProfile {
                        name: "a".into(),
                        bootstrap_servers: "b:9092".into(),
                        headless_shared: Some(true),
                        sasl_password: Some("p".into()),
                        ..ClusterProfile::default()
                    },
                    ClusterProfile {
                        name: "b".into(),
                        bootstrap_servers: "b:9092".into(),
                        headless_shared: None,
                        sasl_password: Some("q".into()),
                        ..ClusterProfile::default()
                    },
                ],
            },
        );

        assert!(result.file_error.is_none());
        assert!(result.failed.is_empty());
        let text = fs::read_to_string(&path).unwrap();
        assert!(text.contains("\"a\""));
        assert!(!text.contains("\"b\""));
        assert!(!text.contains("\"p\""));
    }

    #[test]
    fn mcp_launch_uses_appimage_when_set() {
        let launch = mcp_server_launch_with_env(
            |_| Some("/tmp/does-not-exist.AppImage".into()),
            Some(PathBuf::from("/opt/kafkalyzer/bin/kafkalyzer")),
        );
        assert_eq!(launch.command, "/tmp/does-not-exist.AppImage");
        assert_eq!(launch.leading_args, vec!["--mcp".to_string()]);
        assert!(!launch.exists);
    }

    #[test]
    fn mcp_launch_uses_sibling_binary_by_default() {
        let launch = mcp_server_launch_with_env(
            |_| None,
            Some(PathBuf::from("/opt/kafkalyzer/bin/kafkalyzer")),
        );
        #[cfg(windows)]
        assert!(launch.command.ends_with("kafkalyzer-mcp.exe"));
        #[cfg(not(windows))]
        assert_eq!(launch.command, "/opt/kafkalyzer/bin/kafkalyzer-mcp");
        assert!(launch.leading_args.is_empty());
    }
}
