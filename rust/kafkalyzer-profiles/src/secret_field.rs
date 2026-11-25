use kafkalyzer_core::kafka_types::ClusterProfile;
use serde::{Deserialize, Serialize};

/// The six secret fields stored in the OS keyring for a shared profile.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SecretField {
    SaslPassword,
    SchemaRegistryPassword,
    SslKeystorePassword,
    SslTruststorePassword,
    SslPemKeyPassword,
    SaslOauthbearerToken,
}

impl SecretField {
    pub const ALL: [SecretField; 6] = [
        SecretField::SaslPassword,
        SecretField::SchemaRegistryPassword,
        SecretField::SslKeystorePassword,
        SecretField::SslTruststorePassword,
        SecretField::SslPemKeyPassword,
        SecretField::SaslOauthbearerToken,
    ];

    /// Snake_case name used in keyring account ids (`<profile>/<field>`).
    pub fn as_str(self) -> &'static str {
        match self {
            SecretField::SaslPassword => "sasl_password",
            SecretField::SchemaRegistryPassword => "schema_registry_password",
            SecretField::SslKeystorePassword => "ssl_keystore_password",
            SecretField::SslTruststorePassword => "ssl_truststore_password",
            SecretField::SslPemKeyPassword => "ssl_pem_key_password",
            SecretField::SaslOauthbearerToken => "sasl_oauthbearer_token",
        }
    }

    /// Takes the field value out of `profile`, leaving `None`.
    pub fn take(self, profile: &mut ClusterProfile) -> Option<String> {
        match self {
            SecretField::SaslPassword => profile.sasl_password.take(),
            SecretField::SchemaRegistryPassword => profile.schema_registry_password.take(),
            SecretField::SslKeystorePassword => profile.ssl_keystore_password.take(),
            SecretField::SslTruststorePassword => profile.ssl_truststore_password.take(),
            SecretField::SslPemKeyPassword => profile.ssl_pem_key_password.take(),
            SecretField::SaslOauthbearerToken => profile.sasl_oauthbearer_token.take(),
        }
    }

    /// Writes `value` into `profile` for this field.
    pub fn put(self, profile: &mut ClusterProfile, value: Option<String>) {
        match self {
            SecretField::SaslPassword => profile.sasl_password = value,
            SecretField::SchemaRegistryPassword => profile.schema_registry_password = value,
            SecretField::SslKeystorePassword => profile.ssl_keystore_password = value,
            SecretField::SslTruststorePassword => profile.ssl_truststore_password = value,
            SecretField::SslPemKeyPassword => profile.ssl_pem_key_password = value,
            SecretField::SaslOauthbearerToken => profile.sasl_oauthbearer_token = value,
        }
    }
}
