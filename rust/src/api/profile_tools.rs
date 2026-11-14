use crate::api::kafka_types::{ClusterProfile, TlsVerification};
use flutter_rust_bridge::frb;
use kafkalyzer_core::bootstrap::{self, BootstrapIssueKind};
use kafkalyzer_core::client_properties::{self, PropertyIssueKind, SkipReason as CoreSkipReason};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BootstrapServerIssueKind {
    NoEntries,
    MissingPort,
    InvalidPort,
    InvalidHost,
    SchemeNotAllowed,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BootstrapServerIssue {
    pub entry: String,
    pub kind: BootstrapServerIssueKind,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ExtraPropertyIssueKind {
    Syntax,
    NotAllowed,
    InvalidValue,
    Duplicate,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExtraPropertyIssue {
    pub line: usize,
    pub key: String,
    pub kind: ExtraPropertyIssueKind,
    pub allowed: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AllowedExtraProperty {
    pub key: String,
    pub value_hint: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ClientPropertySkipReason {
    NotAllowed,
    Unsupported,
    Placeholder,
    VerificationOverride,
    InvalidValue,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkippedClientProperty {
    pub key: String,
    pub reason: ClientPropertySkipReason,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ClientPropertiesPreview {
    pub profile: ClusterProfile,
    pub extra_properties: String,
    pub skipped: Vec<SkippedClientProperty>,
}

#[frb(sync)]
pub fn validate_bootstrap_servers(value: String) -> Vec<BootstrapServerIssue> {
    match bootstrap::parse_bootstrap_servers(&value) {
        Ok(_) => Vec::new(),
        Err(issues) => issues
            .into_iter()
            .map(|issue| BootstrapServerIssue {
                entry: issue.entry,
                kind: match issue.kind {
                    BootstrapIssueKind::NoEntries => BootstrapServerIssueKind::NoEntries,
                    BootstrapIssueKind::MissingPort => BootstrapServerIssueKind::MissingPort,
                    BootstrapIssueKind::InvalidPort => BootstrapServerIssueKind::InvalidPort,
                    BootstrapIssueKind::InvalidHost => BootstrapServerIssueKind::InvalidHost,
                    BootstrapIssueKind::SchemeNotAllowed => {
                        BootstrapServerIssueKind::SchemeNotAllowed
                    }
                },
            })
            .collect(),
    }
}

#[frb(sync)]
pub fn validate_extra_properties(text: String) -> Vec<ExtraPropertyIssue> {
    client_properties::validate(&text)
        .into_iter()
        .map(|issue| ExtraPropertyIssue {
            line: issue.line_no,
            key: issue.key,
            kind: match issue.kind {
                PropertyIssueKind::Syntax => ExtraPropertyIssueKind::Syntax,
                PropertyIssueKind::NotAllowed => ExtraPropertyIssueKind::NotAllowed,
                PropertyIssueKind::InvalidValue => ExtraPropertyIssueKind::InvalidValue,
                PropertyIssueKind::Duplicate => ExtraPropertyIssueKind::Duplicate,
            },
            allowed: issue.allowed,
        })
        .collect()
}

#[frb(sync)]
pub fn allowed_extra_properties() -> Vec<AllowedExtraProperty> {
    client_properties::ALLOWED
        .iter()
        .map(|prop| AllowedExtraProperty {
            key: prop.key.to_string(),
            value_hint: prop.value_hint(),
        })
        .collect()
}

pub async fn parse_client_properties(content: String) -> ClientPropertiesPreview {
    let mapped = client_properties::map_client_properties(&content);
    let extra_properties = mapped
        .extras
        .iter()
        .map(|(k, v)| format!("{k}={v}"))
        .collect::<Vec<_>>()
        .join("\n");

    let profile = ClusterProfile {
        name: String::new(),
        bootstrap_servers: mapped.fields.bootstrap_servers.unwrap_or_default(),
        sasl_username: mapped.fields.sasl_username,
        sasl_password: mapped.fields.sasl_password,
        mechanism: mapped.fields.mechanism,
        security_protocol: mapped.fields.security_protocol,
        schema_registry_url: mapped.fields.schema_registry_url,
        ssl_keystore_location: mapped.fields.ssl_keystore_location,
        ssl_keystore_password: mapped.fields.ssl_keystore_password,
        ssl_truststore_location: mapped.fields.ssl_truststore_location,
        ssl_truststore_password: mapped.fields.ssl_truststore_password,
        schema_registry_username: mapped.fields.schema_registry_username,
        schema_registry_password: mapped.fields.schema_registry_password,
        sasl_kerberos_service_name: mapped.fields.sasl_kerberos_service_name,
        sasl_kerberos_keytab: mapped.fields.sasl_kerberos_keytab,
        sasl_kerberos_principal: mapped.fields.sasl_kerberos_principal,
        sasl_kerberos_conf: None,
        sasl_oauthbearer_token: None,
        ssl_pem_certificate_location: mapped.fields.ssl_pem_certificate_location,
        ssl_pem_key_location: mapped.fields.ssl_pem_key_location,
        ssl_pem_key_password: mapped.fields.ssl_pem_key_password,
        tls_verification: TlsVerification::Unreviewed,
        environment_label: None,
        environment_color: None,
        extra_properties: if extra_properties.is_empty() {
            None
        } else {
            Some(extra_properties.clone())
        },
    };

    let skipped = mapped
        .skipped
        .into_iter()
        .map(|s| SkippedClientProperty {
            key: s.key,
            reason: match s.reason {
                CoreSkipReason::NotAllowed => ClientPropertySkipReason::NotAllowed,
                CoreSkipReason::Unsupported => ClientPropertySkipReason::Unsupported,
                CoreSkipReason::Placeholder => ClientPropertySkipReason::Placeholder,
                CoreSkipReason::VerificationOverride => {
                    ClientPropertySkipReason::VerificationOverride
                }
                CoreSkipReason::InvalidValue => ClientPropertySkipReason::InvalidValue,
            },
        })
        .collect();

    ClientPropertiesPreview {
        profile,
        extra_properties,
        skipped,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn bootstrap_validator_maps_issue_kinds() {
        assert!(validate_bootstrap_servers("b1:9092,[::1]:9093".to_string()).is_empty());
        let issues = validate_bootstrap_servers("http://b1:9092,b2,b3:99999".to_string());
        assert_eq!(
            issues,
            vec![
                BootstrapServerIssue {
                    entry: "http://b1:9092".to_string(),
                    kind: BootstrapServerIssueKind::SchemeNotAllowed,
                },
                BootstrapServerIssue {
                    entry: "b2".to_string(),
                    kind: BootstrapServerIssueKind::MissingPort,
                },
                BootstrapServerIssue {
                    entry: "b3:99999".to_string(),
                    kind: BootstrapServerIssueKind::InvalidPort,
                },
            ]
        );
    }

    #[test]
    fn extra_properties_validator_maps_issue_kinds_and_lists_allowed() {
        assert!(!allowed_extra_properties().is_empty());
        let issues = validate_extra_properties(
            "client.id=a\nclient.id=b\nsocket.timeout.ms=1\ngroup.id=x\nbad".to_string(),
        );
        assert_eq!(
            issues,
            vec![
                ExtraPropertyIssue {
                    line: 2,
                    key: "client.id".to_string(),
                    kind: ExtraPropertyIssueKind::Duplicate,
                    allowed: None,
                },
                ExtraPropertyIssue {
                    line: 3,
                    key: "socket.timeout.ms".to_string(),
                    kind: ExtraPropertyIssueKind::InvalidValue,
                    allowed: Some("10..300000".to_string()),
                },
                ExtraPropertyIssue {
                    line: 4,
                    key: "group.id".to_string(),
                    kind: ExtraPropertyIssueKind::NotAllowed,
                    allowed: None,
                },
                ExtraPropertyIssue {
                    line: 5,
                    key: String::new(),
                    kind: ExtraPropertyIssueKind::Syntax,
                    allowed: None,
                },
            ]
        );
    }

    #[tokio::test]
    async fn parse_client_properties_maps_preview_and_skipped_reasons() {
        let preview = parse_client_properties(
            "bootstrap.servers=b1:9092\nclient.id=k1\nacks=all\n".to_string(),
        )
        .await;
        assert_eq!(preview.profile.bootstrap_servers, "b1:9092");
        assert_eq!(preview.extra_properties, "client.id=k1");
        assert_eq!(
            preview.skipped,
            vec![SkippedClientProperty {
                key: "acks".to_string(),
                reason: ClientPropertySkipReason::NotAllowed,
            }]
        );
    }
}
