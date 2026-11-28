use kafkalyzer_core::kafka_types::ClusterProfile;
use serde::{Deserialize, Serialize};

use crate::secret_field::SecretField;

pub const SHARED_PROFILES_VERSION: u32 = 1;

/// One shared profile as stored in the shared-profiles file (secrets stripped).
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedProfile {
    pub profile: ClusterProfile,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub environment_label: Option<String>,
    pub secret_fields: Vec<SecretField>,
}

/// Versioned envelope written to `shared-profiles.json`.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedProfilesFile {
    pub version: u32,
    pub profiles: Vec<SharedProfile>,
}

/// Splits secrets out of a domain profile for keyring storage.
///
/// Returns the secret-free [`SharedProfile`] and the non-empty `(field, value)` pairs
/// that must be written to the keyring.
pub fn split_secrets(
    mut profile: ClusterProfile,
    environment_label: Option<String>,
) -> (SharedProfile, Vec<(SecretField, String)>) {
    let mut secret_fields = Vec::new();
    let mut values = Vec::new();
    for field in SecretField::ALL {
        match field.take(&mut profile) {
            Some(value) if !value.is_empty() => {
                secret_fields.push(field);
                values.push((field, value));
            }
            _ => {}
        }
    }
    (
        SharedProfile {
            profile,
            environment_label,
            secret_fields,
        },
        values,
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample_profile() -> ClusterProfile {
        ClusterProfile {
            name: "orders-test".into(),
            bootstrap_servers: "broker:9092".into(),
            sasl_username: Some("alice".into()),
            sasl_password: Some("s3cr3t".into()),
            mechanism: Some("SCRAM-SHA-512".into()),
            schema_registry_url: Some("https://sr.example".into()),
            schema_registry_password: Some("sr-pass".into()),
            ssl_keystore_password: Some("ks-pass-9".into()),
            ssl_truststore_password: None,
            ssl_pem_key_password: Some("".into()),
            sasl_oauthbearer_token: Some("bearer-xyz".into()),
            ..ClusterProfile::default()
        }
    }

    #[test]
    fn serialized_profile_has_no_secret_values_and_lists_secret_fields() {
        let (shared, values) = split_secrets(sample_profile(), Some("TEST".into()));

        assert_eq!(
            shared.secret_fields,
            vec![
                SecretField::SaslPassword,
                SecretField::SchemaRegistryPassword,
                SecretField::SslKeystorePassword,
                SecretField::SaslOauthbearerToken,
            ]
        );
        assert_eq!(values.len(), 4);
        assert!(shared.profile.sasl_password.is_none());
        assert!(shared.profile.schema_registry_password.is_none());
        assert!(shared.profile.ssl_keystore_password.is_none());
        assert!(shared.profile.sasl_oauthbearer_token.is_none());

        let file = SharedProfilesFile {
            version: SHARED_PROFILES_VERSION,
            profiles: vec![shared],
        };
        let json = serde_json::to_string(&file).expect("serialize");
        for secret in ["s3cr3t", "sr-pass", "ks-pass-9", "bearer-xyz"] {
            assert!(
                !json.contains(secret),
                "secret value {secret:?} leaked into file JSON"
            );
        }

        let parsed: serde_json::Value = serde_json::from_str(&json).expect("parse");
        assert_eq!(parsed["version"], 1);
        assert_eq!(parsed["profiles"][0]["environment_label"], "TEST");
        assert_eq!(
            parsed["profiles"][0]["secret_fields"],
            serde_json::json!([
                "sasl_password",
                "schema_registry_password",
                "ssl_keystore_password",
                "sasl_oauthbearer_token"
            ])
        );
        let profile = &parsed["profiles"][0]["profile"];
        assert!(profile["sasl_password"].is_null());
        assert!(profile["schema_registry_password"].is_null());
        assert!(profile["ssl_keystore_password"].is_null());
        assert!(profile["sasl_oauthbearer_token"].is_null());
    }
}
