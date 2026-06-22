## Why

Kafkalyzer is currently limited to basic Kafka connectivity (standard PLAINTEXT/SCRAM-based SASL, unsecured Schema Registry, and only Avro or UTF-8 decoding). To serve as a robust read-only data analysis tool in enterprise environments, it must support advanced security configurations (TLS with PEM files, full Kerberos/GSSAPI, OAuthBearer, AWS MSK IAM, secured Schema Registry) and additional serializations (JSON Schema, Protobuf) as well as message headers inspection.

## What Changes

- Add Basic Auth and TLS truststore/keystore configurations to `ClusterProfile` for Schema Registry integration.
- Add support for decoding Confluent JSON Schema and Protobuf payloads retrieved via the Schema Registry in the consumer backend.
- Extend `ClusterProfile` and the UI to support advanced Kerberos/GSSAPI configuration properties (service name, keytab, principal, krb5.conf), SASL OAuthBearer, and AWS MSK IAM.
- Add configuration fields to support separate client certificate and private key PEM files for mTLS connections.
- Extend the `KafkaMessage` boundary struct to retrieve and display message headers (key-value metadata pairs) in the UI.
- Focus strictly on read-only diagnostics and analysis: exclude all write operations (producing messages, resetting offsets) and local schema file upload/loading.

## Capabilities

### New Capabilities

- `schema-registry-auth`: Support Basic Auth and TLS certificates for secure Confluent Schema Registry connections.
- `extended-serialization-formats`: Support decoding Confluent JSON Schema and Protobuf payloads retrieved via the Schema Registry.
- `enterprise-sasl-auth`: Support advanced SASL mechanisms including fully configurable GSSAPI (Kerberos), SASL OAuthBearer, and AWS MSK IAM.
- `pem-mtls-config`: Support configuring client-side mTLS using separate Client Certificate and Private Key PEM files in the UI and backend.
- `message-headers-inspection`: Retrieve and display Kafka message headers alongside the key and payload in the viewer.

### Modified Capabilities

<!-- None -->

## Impact

- **Rust Crate (`kafkalyzer-kafka`)**: Updates `create_config` in `kafka_utils.rs` to support new SASL configurations, PEM files, and Schema Registry settings. Updates `decode_message_component` in `kafka_consumer.rs` for JSON Schema/Protobuf, and extracts message headers during polling.
- **Rust/Dart Bridge (`rust_lib_kafkalyzer`)**: Updates boundary structs `ClusterProfile` and `KafkaMessage` in `rust/src/api/kafka_types.rs` and `rust/src/api/kafka_consumer.rs`.
- **Flutter Frontend**: Modifies `ClusterConfigDialog` to handle new connection fields. Updates message details UI in `ExplorerView` to show headers and properly render new formats.
