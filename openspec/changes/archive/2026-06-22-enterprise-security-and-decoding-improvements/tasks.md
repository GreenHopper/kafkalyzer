## 1. Rust Domain & Core Backend Updates

- [x] 1.1 Update `ClusterProfile` and `KafkaMessage` structures in `kafkalyzer-core` to hold new security and header properties
- [x] 1.2 Implement Confluent JSON Schema decoding using `schema_registry_converter` inside `kafkalyzer-kafka`
- [x] 1.3 Implement Confluent Protobuf decoding inside `kafkalyzer-kafka`
- [x] 1.4 Update client config builder in `kafka_utils.rs` to support separate PEM Client Certificate and Private Key options
- [x] 1.5 Update client config builder in `kafka_utils.rs` to map advanced SASL (GSSAPI custom parameters, OAuthBearer, AWS MSK IAM)
- [x] 1.6 Update Schema Registry REST calls in `schema_registry.rs` and `kafka_consumer.rs` to configure HTTP Basic Auth and TLS options
- [x] 1.7 Extract message headers during consumer poll in `kafka_consumer.rs` and parse them into UTF-8/Hex strings

## 2. API Bridge Layer Updates

- [x] 2.1 Update bridge boundary structs (adding new properties and mapping logic) in `rust/src/api/kafka_types.rs`
- [x] 2.2 Run `flutter_rust_bridge_codegen` to regenerate Dart/Rust binding code

## 3. Flutter Presentation & UI Updates

- [x] 3.1 Update `ClusterSslForm` in `ClusterConfigDialog` to support selecting separate Client Certificate and Private Key PEM files
- [x] 3.2 Update `ClusterSaslForm` to expose input fields for custom GSSAPI fields, SASL OAuthBearer token, and AWS MSK IAM
- [x] 3.3 Add username and password input fields for the Schema Registry connection in the config forms
- [x] 3.4 Update message details view in `ExplorerView` to display message headers in a structured key-value tab
- [x] 3.5 Verify the visual rendering of pretty-printed JSON Schema and Protobuf decoded payloads
