## Context

Kafkalyzer's architecture separates connection configuration (`ClusterProfile`) and backend retrieval (`kafkalyzer-kafka`) from frontend display (Flutter). Currently, only standard configuration parameters are bridged via `flutter_rust_bridge` to `librdkafka`. Supporting enterprise scenarios requires broadening the bridge boundary structs, extending configuration mapping to `rdkafka::config::ClientConfig` (in Rust), and updating the Flutter configuration forms.

## Goals / Non-Goals

**Goals:**
- Extend connection profiles to support secured Schema Registries (Basic Auth & HTTPS TLS).
- Support decoding JSON Schema and Protobuf payloads in the consumer thread.
- Provide full support for GSSAPI (Kerberos), SASL OAuthBearer, and AWS MSK IAM SASL mechanisms.
- Support configuring mTLS using separate Client Certificate and Private Key PEM files.
- Inspect and display message headers (metadata key-value pairs) in the message explorer UI.

**Non-Goals:**
- Adding write operations (no editing offsets, producing messages, creating or deleting topics, or editing schemas).
- Supporting upload/management of local schema files (`.proto`, `.avsc`).
- Redesigning the entire UI layout.

## Decisions

### 1. Extended `ClusterProfile` Schema & Bridge Updates
We will add new properties to `ClusterProfile` in `rust/src/api/kafka_types.rs` (mapped to `kafkalyzer-core` and Dart boundary):
- **Schema Registry Auth**: `schema_registry_username`, `schema_registry_password`
- **Advanced SASL**: `sasl_kerberos_service_name`, `sasl_kerberos_keytab`, `sasl_kerberos_principal`, `sasl_kerberos_conf`, `sasl_oauthbearer_token`
- **PEM mTLS**: `ssl_pem_certificate_location`, `ssl_pem_key_location`, `ssl_pem_key_password`

*Rationale*: Extending the core struct ensures all connection parameters are persisted via `shared_preferences` using existing mechanisms, maintaining a single source of truth.

### 2. Message Headers representation in `KafkaMessage`
We will add `headers: Option<Vec<KafkaHeader>>` to `KafkaMessage` where `KafkaHeader` is defined as:
```rust
pub struct KafkaHeader {
    pub key: String,
    pub value: String, // String-decoded (UTF-8) or Hex fallback
}
```
*Rationale*: Using a key-value list of string-decoded values allows Dart to easily render headers in a list view without requiring custom Dart-side binary decoding.

### 3. Native Schema Registry Authentication Configuration
- In `rust/kafkalyzer-kafka/src/schema_registry.rs`, update `fetch_subjects` and `fetch_schema` to construct `reqwest::Client` with Basic Credentials when configured.
- In `kafka_consumer.rs`, update `create_sr_settings` to invoke `SrSettings::set_credentials` when username and password are provided.

*Rationale*: This matches how `schema_registry_converter` is designed to handle credentials and resolves the outstanding TODO comment in the schema registry fetch methods.

### 4. Advanced SASL & PEM mTLS Mapping in `kafka_utils.rs`
- If `sasl_pem_certificate_location` and `sasl_pem_key_location` are provided, set `ssl.certificate.location`, `ssl.key.location`, and `ssl.key.password` directly on `ClientConfig`.
- Map Kerberos parameters directly to `sasl.kerberos.service.name`, `sasl.kerberos.keytab`, and `sasl.kerberos.principal`. Point the environment variable `KRB5_CONFIG` to `sasl_kerberos_conf` if provided.
- Map SASL OAuthBearer static token to `sasl.oauthbearer.config`.
- Set mechanism to `AWS_MSK_IAM` if configured, letting `librdkafka` load the MSK credentials provider.

*Alternative considered*: Auto-detecting file types from the existing single keystore location.
*Decision*: Rejected. Using explicit separate fields is cleaner and matches standard user expectations.

### 5. Header extraction during polling loop
In `kafka_consumer.rs`, inside the main message processing callback, check if `message.headers()` is `Some`. Iterate over headers, decode the value bytes as UTF-8 (falling back to hex encoding with prefix `0x` if not valid UTF-8), and append them to the `KafkaMessage` struct.

## Risks / Trade-offs

- **[Risk]** Kerberos GSSAPI authentication requires the target platform to have `kinit` or Kerberos libraries installed.
  - *Mitigation*: Ensure connections fail gracefully with a clear error message in the UI when Kerberos libraries are missing on the target host.
- **[Risk]** Large headers could impact performance of message ingestion.
  - *Mitigation*: The headers are small metadata chunks (typically <1KB). We already process the payload on background worker threads, preventing UI freezes.
