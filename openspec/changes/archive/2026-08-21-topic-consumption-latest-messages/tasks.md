## 1. Rust Kafka Consumer Implementation (`kafkalyzer-kafka`)

- [x] 1.1 Implement tail start offset resolution logic in `resolve_start_offsets` using partition watermarks and result limits.
- [x] 1.2 Update consumer seek logic and `calculate_total_to_scan` to properly seek and calculate bounds for tail consumption.
- [x] 1.3 Add Rust unit tests in `kafkalyzer-kafka` verifying tail offset calculations and boundary edge cases.

## 2. Rust Bridge Layer & Code Generation (`rust_lib_kafkalyzer`)

- [x] 2.1 Expose `start_from_tail` (or start strategy) in `rust/src/api/kafka_consumer.rs` and forward to `kafkalyzer-kafka`.
- [x] 2.2 Run flutter_rust_bridge code generation and ensure Rust and Dart bindings compile without errors.

## 3. Flutter Frontend Integration

- [x] 3.1 Update `MessageStreamController` to support tail offset mode and fix missing `endOffset` argument forwarding.
- [x] 3.2 Update `TopicDetailView` to pass `startFromTail` when `_startStrategy` is `latest`.
- [x] 3.3 Update `MultiSearchController` and `SearchTarget` to support tail message streaming.
- [x] 3.4 Update `StartConditionConfiguration` and `EndConditionConfiguration` UI with helpful tooltips and updated localization in `app_en.arb` and `app_de.arb`.

## 4. Verification & Testing

- [x] 4.1 Run Rust crate unit tests (`cargo test --workspace`).
- [x] 4.2 Run Flutter analysis and test suites (`flutter test`).
- [x] 4.3 Verify bounded tail consumption and live streaming workflows across single and multi-partition topics.
