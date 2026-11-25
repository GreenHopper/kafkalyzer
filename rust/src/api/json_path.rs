use anyhow::Result;

use crate::api::kafka_types::ClusterProfile;

/// Resolve one field path inside a JSON payload.
///
/// The grammar is defined by `kafkalyzer_core::json_path` and shared with the
/// broker-side message filter, so a path behaves identically in a projected
/// table column, a script extraction step and a filter.
pub fn resolve_json_path(payload: String, path: String) -> Option<String> {
    kafkalyzer_core::json_path::resolve(&payload, &path)
}

/// Resolve every `paths` entry for every `payloads` entry in one call.
///
/// Results are payload-major and flattened: entry `i * paths.len() + j`
/// belongs to `payloads[i]` and `paths[j]`. Callers pass a whole batch so the
/// bridge is crossed once per batch rather than once per table cell.
pub fn resolve_json_path_batch(payloads: Vec<String>, paths: Vec<String>) -> Vec<Option<String>> {
    kafkalyzer_core::json_path::resolve_batch(&payloads, &paths)
}

#[flutter_rust_bridge::frb(sync)]
pub fn collect_field_paths(payload: String, limit: u32) -> Vec<String> {
    let Ok(val) = serde_json::from_str::<serde_json::Value>(&payload) else {
        return Vec::new();
    };
    kafkalyzer_core::json_path::collect_paths(&val, limit as usize)
}

/// Filter terms that the regex engine used by a scan cannot compile.
///
/// Returned in input order; an empty list means every term is usable.
pub fn validate_filter_patterns(terms: Vec<String>) -> Vec<String> {
    kafkalyzer_kafka::kafka_consumer::invalid_filter_patterns(&terms)
}

/// Serialize a cluster profile for local storage.
///
/// Serde on the bridge struct is the single authority, so a newly added
/// profile field is persisted without touching Dart.
pub fn serialize_cluster_profile(profile: ClusterProfile) -> Result<String> {
    Ok(serde_json::to_string(&profile)?)
}

/// Read back a stored cluster profile, including files written before the
/// advanced authentication fields existed.
pub fn deserialize_cluster_profile(json: String) -> Result<ClusterProfile> {
    Ok(serde_json::from_str(&json)?)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn reports_only_uncompilable_patterns() {
        let invalid = validate_filter_patterns(vec![
            "orders[".to_string(),
            "^ok$".to_string(),
            "(".to_string(),
        ]);
        assert_eq!(invalid, vec!["orders[".to_string(), "(".to_string()]);
    }

    #[test]
    fn resolves_paths_through_the_bridge() {
        let payload = r#"{"a":{"b":[1,2]}}"#.to_string();
        assert_eq!(
            resolve_json_path(payload.clone(), "a.b[1]".to_string()).as_deref(),
            Some("2")
        );
        assert_eq!(
            resolve_json_path(payload, "$.a.b.0".to_string()).as_deref(),
            Some("1")
        );
    }

    #[test]
    fn batch_resolves_one_entry_per_payload_and_path() {
        let values = resolve_json_path_batch(
            vec![r#"{"a":1}"#.to_string(), r#"{"a":2}"#.to_string()],
            vec!["a".to_string(), "missing".to_string()],
        );
        assert_eq!(
            values,
            vec![Some("1".to_string()), None, Some("2".to_string()), None,]
        );
    }

    fn full_profile() -> ClusterProfile {
        ClusterProfile {
            name: "prod".to_string(),
            bootstrap_servers: "broker:9092".to_string(),
            sasl_username: Some("user".to_string()),
            sasl_password: Some("pass".to_string()),
            mechanism: Some("SCRAM-SHA-512".to_string()),
            security_protocol: Some("SASL_SSL".to_string()),
            schema_registry_url: Some("https://sr:8081".to_string()),
            ssl_keystore_location: Some("/ks".to_string()),
            ssl_keystore_password: Some("ksp".to_string()),
            ssl_truststore_location: Some("/ts".to_string()),
            ssl_truststore_password: Some("tsp".to_string()),
            schema_registry_username: Some("sruser".to_string()),
            schema_registry_password: Some("srpass".to_string()),
            sasl_kerberos_service_name: Some("kafka".to_string()),
            sasl_kerberos_keytab: Some("/keytab".to_string()),
            sasl_kerberos_principal: Some("kafka/host@REALM".to_string()),
            sasl_kerberos_conf: Some("/krb5.conf".to_string()),
            sasl_oauthbearer_token: Some("token".to_string()),
            ssl_pem_certificate_location: Some("/cert.pem".to_string()),
            ssl_pem_key_location: Some("/key.pem".to_string()),
            ssl_pem_key_password: Some("pempw".to_string()),
            tls_verification: crate::api::kafka_types::TlsVerification::Disabled,
            environment_label: Some("PROD".to_string()),
            environment_color: Some("red".to_string()),
            extra_properties: Some("client.id=kafkalyzer\nsocket.timeout.ms=30000".to_string()),
            headless_shared: Some(true),
        }
    }

    #[test]
    fn profile_round_trip_keeps_every_field() {
        let json = serialize_cluster_profile(full_profile()).unwrap();
        assert!(json.contains("\"headlessShared\":true"));
        let loaded = deserialize_cluster_profile(json).unwrap();
        assert_eq!(loaded, full_profile());
    }

    #[test]
    fn legacy_stored_profile_still_loads() {
        // Shape written by the old Dart toJson: 11 camelCase keys only.
        let legacy = r#"{"name":"old","bootstrapServers":"b:9092","saslUsername":null,"saslPassword":null,"mechanism":null,"securityProtocol":null,"schemaRegistryUrl":null,"sslKeystoreLocation":null,"sslKeystorePassword":null,"sslTruststoreLocation":null,"sslTruststorePassword":null}"#
            .to_string();

        let loaded = deserialize_cluster_profile(legacy).unwrap();

        assert_eq!(loaded.name, "old");
        assert_eq!(loaded.bootstrap_servers, "b:9092");
        assert_eq!(loaded.sasl_kerberos_keytab, None);
        assert_eq!(loaded.ssl_pem_key_location, None);
        assert_eq!(loaded.environment_label, None);
        assert_eq!(loaded.environment_color, None);
        assert_eq!(loaded.extra_properties, None);
        assert_eq!(loaded.headless_shared, None);
    }

    #[test]
    fn headless_shared_does_not_change_to_domain() {
        let mut dto = full_profile();
        let domain_shared = dto.to_domain();
        dto.headless_shared = None;
        let domain_unset = dto.to_domain();
        assert_eq!(domain_shared.name, domain_unset.name);
        assert_eq!(
            domain_shared.bootstrap_servers,
            domain_unset.bootstrap_servers
        );
        assert_eq!(domain_shared.sasl_password, domain_unset.sasl_password);
        assert_eq!(
            domain_shared.ssl_verification_disabled,
            domain_unset.ssl_verification_disabled
        );
        assert_eq!(
            domain_shared.extra_properties,
            domain_unset.extra_properties
        );
    }

    #[test]
    fn to_domain_parses_extra_properties_and_drops_syntax_errors() {
        let mut dto = full_profile();
        dto.extra_properties = Some("client.id=k1\nbad_line\nsocket.timeout.ms=30000".to_string());
        let domain = dto.to_domain();
        assert_eq!(
            domain.extra_properties,
            vec![
                ("client.id".to_string(), "k1".to_string()),
                ("socket.timeout.ms".to_string(), "30000".to_string()),
            ]
        );
    }

    #[test]
    fn stored_keys_stay_camel_case() {
        let json = serialize_cluster_profile(full_profile()).unwrap();
        assert!(json.contains("\"bootstrapServers\""));
        assert!(json.contains("\"sslPemKeyPassword\""));
        assert!(json.contains("\"tlsVerification\":\"disabled\""));
    }

    #[test]
    fn legacy_json_without_tls_verification_defaults_to_unreviewed() {
        let legacy = r#"{"name":"legacy","bootstrapServers":"localhost:9092"}"#;
        let profile = deserialize_cluster_profile(legacy.to_string()).unwrap();
        assert_eq!(
            profile.tls_verification,
            crate::api::kafka_types::TlsVerification::Unreviewed
        );
        assert!(!profile.to_domain().ssl_verification_disabled);
    }

    #[test]
    fn tls_verification_round_trip_and_domain_mapping() {
        let mut profile = full_profile();
        assert!(profile.to_domain().ssl_verification_disabled);

        profile.tls_verification = crate::api::kafka_types::TlsVerification::Enabled;
        assert!(!profile.to_domain().ssl_verification_disabled);
        let round_tripped =
            deserialize_cluster_profile(serialize_cluster_profile(profile).unwrap()).unwrap();
        assert_eq!(
            round_tripped.tls_verification,
            crate::api::kafka_types::TlsVerification::Enabled
        );
    }
}
