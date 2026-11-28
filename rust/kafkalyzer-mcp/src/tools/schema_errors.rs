//! Map Schema Registry error kinds to distinct tool errors.

use kafkalyzer_core::kafka_types::ClusterProfile;
use kafkalyzer_kafka::schema_registry::{SchemaRegistryError, SchemaRegistryErrorKind};

use super::ToolError;
use crate::shape::redact;

pub fn map_registry_error(err: SchemaRegistryError, profile: &ClusterProfile) -> ToolError {
    let detail = redact(&err.detail, profile);
    let message = match err.kind {
        SchemaRegistryErrorKind::NotConfigured => {
            "no Schema Registry is configured for this cluster".to_string()
        }
        SchemaRegistryErrorKind::InvalidUrl => {
            format!("Schema Registry URL is invalid: {detail}")
        }
        SchemaRegistryErrorKind::Unauthorized => {
            format!("Schema Registry rejected credentials (unauthorized): {detail}")
        }
        SchemaRegistryErrorKind::Forbidden => {
            format!("Schema Registry access denied (forbidden): {detail}")
        }
        SchemaRegistryErrorKind::NotFound => {
            format!("Schema Registry subject or version not found: {detail}")
        }
        SchemaRegistryErrorKind::Timeout => {
            format!("Schema Registry request timed out: {detail}")
        }
        SchemaRegistryErrorKind::Unreachable => {
            format!("Schema Registry is unreachable: {detail}")
        }
        SchemaRegistryErrorKind::CertificateRejected => {
            format!("Schema Registry TLS certificate was rejected: {detail}")
        }
        SchemaRegistryErrorKind::HttpStatus => match err.status {
            Some(code) => format!("Schema Registry HTTP {code}: {detail}"),
            None => format!("Schema Registry HTTP error: {detail}"),
        },
        SchemaRegistryErrorKind::InvalidResponse => {
            format!("Schema Registry returned an invalid response: {detail}")
        }
    };
    ToolError::Message(message)
}

#[cfg(test)]
mod tests {
    use super::*;
    use kafkalyzer_core::kafka_types::ClusterProfile;

    fn err(kind: SchemaRegistryErrorKind) -> SchemaRegistryError {
        SchemaRegistryError {
            kind,
            status: if kind == SchemaRegistryErrorKind::HttpStatus {
                Some(500)
            } else {
                None
            },
            registry_error_code: None,
            detail: "x".into(),
        }
    }

    #[test]
    fn each_kind_has_distinct_message() {
        let profile = ClusterProfile::default();
        let kinds = [
            SchemaRegistryErrorKind::NotConfigured,
            SchemaRegistryErrorKind::InvalidUrl,
            SchemaRegistryErrorKind::Unauthorized,
            SchemaRegistryErrorKind::Forbidden,
            SchemaRegistryErrorKind::NotFound,
            SchemaRegistryErrorKind::Timeout,
            SchemaRegistryErrorKind::Unreachable,
            SchemaRegistryErrorKind::CertificateRejected,
            SchemaRegistryErrorKind::HttpStatus,
            SchemaRegistryErrorKind::InvalidResponse,
        ];
        let mut messages = Vec::new();
        for kind in kinds {
            let msg = map_registry_error(err(kind), &profile).message();
            assert!(
                !messages.iter().any(|m: &String| m == &msg),
                "duplicate message for {kind:?}: {msg}"
            );
            messages.push(msg);
        }
    }
}
