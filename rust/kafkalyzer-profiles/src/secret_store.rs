use std::collections::HashMap;
use std::path::Path;
use std::sync::Mutex;

use anyhow::{anyhow, Result};

use crate::secret_field::SecretField;

pub const KEYRING_SERVICE: &str = "kafkalyzer-shared-profiles";

/// Stores and deletes per-field secrets for shared profiles.
pub trait SecretStore {
    fn set(&self, profile: &str, field: SecretField, value: &str) -> Result<()>;
    fn get(&self, profile: &str, field: SecretField) -> Result<Option<String>>;
    fn delete(&self, profile: &str, field: SecretField) -> Result<()>;
}

fn account(profile: &str, field: SecretField) -> String {
    format!("{}/{}", profile, field.as_str())
}

/// MCP clients often spawn the process with a stripped environment (no
/// `DBUS_SESSION_BUS_ADDRESS`). Without it, Linux Secret Service lookups fail
/// even when the login keyring holds the shared-profile secrets. Restore the
/// obvious per-uid session bus when the env var is missing.
#[cfg(target_os = "linux")]
pub fn ensure_linux_session_bus() {
    if std::env::var_os("DBUS_SESSION_BUS_ADDRESS").is_some() {
        return;
    }
    let Some(uid) = current_uid() else {
        return;
    };
    let runtime = format!("/run/user/{uid}");
    let bus_path = format!("{runtime}/bus");
    if !Path::new(&bus_path).exists() {
        return;
    }
    // shortcut: only the default user bus path; custom bus addresses need the client to pass env.
    std::env::set_var("DBUS_SESSION_BUS_ADDRESS", format!("unix:path={bus_path}"));
    if std::env::var_os("XDG_RUNTIME_DIR").is_none() {
        std::env::set_var("XDG_RUNTIME_DIR", runtime);
    }
}

#[cfg(not(target_os = "linux"))]
pub fn ensure_linux_session_bus() {}

#[cfg(target_os = "linux")]
fn current_uid() -> Option<u32> {
    let status = std::fs::read_to_string("/proc/self/status").ok()?;
    for line in status.lines() {
        if let Some(rest) = line.strip_prefix("Uid:") {
            return rest.split_whitespace().next()?.parse().ok();
        }
    }
    None
}

/// In-memory store for unit tests.
#[derive(Default)]
pub struct MemorySecretStore {
    entries: Mutex<HashMap<(String, SecretField), String>>,
}

impl MemorySecretStore {
    pub fn new() -> Self {
        Self::default()
    }
}

impl SecretStore for MemorySecretStore {
    fn set(&self, profile: &str, field: SecretField, value: &str) -> Result<()> {
        self.entries
            .lock()
            .map_err(|_| anyhow!("memory secret store lock poisoned"))?
            .insert((profile.to_string(), field), value.to_string());
        Ok(())
    }

    fn get(&self, profile: &str, field: SecretField) -> Result<Option<String>> {
        Ok(self
            .entries
            .lock()
            .map_err(|_| anyhow!("memory secret store lock poisoned"))?
            .get(&(profile.to_string(), field))
            .cloned())
    }

    fn delete(&self, profile: &str, field: SecretField) -> Result<()> {
        self.entries
            .lock()
            .map_err(|_| anyhow!("memory secret store lock poisoned"))?
            .remove(&(profile.to_string(), field));
        Ok(())
    }
}

/// OS keyring-backed store (`keyring` crate).
pub struct KeyringSecretStore;

impl KeyringSecretStore {
    pub fn new() -> Self {
        ensure_linux_session_bus();
        Self
    }

    fn entry(profile: &str, field: SecretField) -> Result<keyring::Entry> {
        keyring::Entry::new(KEYRING_SERVICE, &account(profile, field))
            .map_err(|e| anyhow!("keyring entry create failed: {e}"))
    }
}

impl Default for KeyringSecretStore {
    fn default() -> Self {
        Self::new()
    }
}

impl SecretStore for KeyringSecretStore {
    fn set(&self, profile: &str, field: SecretField, value: &str) -> Result<()> {
        Self::entry(profile, field)?
            .set_password(value)
            .map_err(|e| anyhow!("keyring set failed: {e}"))
    }

    fn get(&self, profile: &str, field: SecretField) -> Result<Option<String>> {
        match Self::entry(profile, field)?.get_password() {
            Ok(value) => Ok(Some(value)),
            Err(keyring::Error::NoEntry) => Ok(None),
            Err(e) => Err(anyhow!("keyring get failed: {e}")),
        }
    }

    fn delete(&self, profile: &str, field: SecretField) -> Result<()> {
        match Self::entry(profile, field)?.delete_credential() {
            Ok(()) => Ok(()),
            Err(keyring::Error::NoEntry) => Ok(()),
            Err(e) => Err(anyhow!("keyring delete failed: {e}")),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn memory_store_round_trips_and_deletes() {
        let store = MemorySecretStore::new();
        store
            .set("orders", SecretField::SaslPassword, "s3cr3t")
            .unwrap();
        assert_eq!(
            store.get("orders", SecretField::SaslPassword).unwrap(),
            Some("s3cr3t".into())
        );
        store.delete("orders", SecretField::SaslPassword).unwrap();
        assert_eq!(
            store.get("orders", SecretField::SaslPassword).unwrap(),
            None
        );
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn ensure_linux_session_bus_sets_default_address_when_missing() {
        let uid = current_uid().expect("uid");
        let bus_path = format!("/run/user/{uid}/bus");
        if !Path::new(&bus_path).exists() {
            return;
        }
        let prev_dbus = std::env::var_os("DBUS_SESSION_BUS_ADDRESS");
        let prev_xdg = std::env::var_os("XDG_RUNTIME_DIR");
        std::env::remove_var("DBUS_SESSION_BUS_ADDRESS");
        std::env::remove_var("XDG_RUNTIME_DIR");
        ensure_linux_session_bus();
        assert_eq!(
            std::env::var("DBUS_SESSION_BUS_ADDRESS").unwrap(),
            format!("unix:path={bus_path}")
        );
        assert_eq!(
            std::env::var("XDG_RUNTIME_DIR").unwrap(),
            format!("/run/user/{uid}")
        );
        match prev_dbus {
            Some(v) => std::env::set_var("DBUS_SESSION_BUS_ADDRESS", v),
            None => std::env::remove_var("DBUS_SESSION_BUS_ADDRESS"),
        }
        match prev_xdg {
            Some(v) => std::env::set_var("XDG_RUNTIME_DIR", v),
            None => std::env::remove_var("XDG_RUNTIME_DIR"),
        }
    }

    #[test]
    #[ignore = "requires an OS keyring (Secret Service / Keychain / Credential Manager)"]
    fn keyring_store_round_trips_when_os_keyring_available() {
        let store = KeyringSecretStore::new();
        let profile = "kafkalyzer-profiles-keyring-test";
        store
            .set(profile, SecretField::SaslPassword, "roundtrip-value")
            .expect("set");
        let got = store.get(profile, SecretField::SaslPassword).expect("get");
        assert_eq!(got.as_deref(), Some("roundtrip-value"));
        store
            .delete(profile, SecretField::SaslPassword)
            .expect("delete");
        assert_eq!(
            store
                .get(profile, SecretField::SaslPassword)
                .expect("get after delete"),
            None
        );
    }
}
