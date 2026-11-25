use std::collections::HashMap;
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
