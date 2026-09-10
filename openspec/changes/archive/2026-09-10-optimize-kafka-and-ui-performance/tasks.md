## 1. Rust Hot Loop & Decoding Optimizations

- [x] 1.1 In `rust/kafkalyzer-core/src/avro_utils.rs`, replace per-invocation `Regex::new` in `Value::Duration` with a static `std::sync::LazyLock<Regex>`; verify with `cargo test -p kafkalyzer-core`
- [x] 1.2 In `rust/kafkalyzer-kafka/src/kafka_consumer.rs`, pre-compile filter terms into `Vec<Regex>` once before `run_poll_loop` and pass the pre-compiled regex slice into `process_and_send_message` and `matches_filter`; verify unit tests pass with `cargo test -p kafkalyzer-kafka`
- [x] 1.3 In `rust/kafkalyzer-kafka/src/kafka_consumer.rs`, implement an in-memory schema lookup cache for Schema Registry IDs and reuse a shared Tokio runtime handle to avoid `block_on` context switching on known schemas; verify tests pass with `cargo test -p kafkalyzer-kafka`
- [x] 1.4 In `rust/kafkalyzer-kafka/src/kafka_analyzer.rs`, decouple 250ms progress emission from deep accumulator clones by using atomic message and byte counters, and replace fixed 5ms worker sleep with cooperative yielding; verify tests pass with `cargo test -p kafkalyzer-kafka`
- [x] 1.5 In root `rust/Cargo.toml`, add release profile optimizations (`lto = "fat"`, `codegen-units = 1`, `panic = "abort"`, `opt-level = 3`); verify workspace builds with `cargo check --workspace --release`

## 2. Flutter Stream & UI Ingestion Optimizations

- [x] 2.1 In `lib/src/features/topic/presentation/controllers/message_stream_controller.dart`, throttle `notifyListeners()` using a periodic timer or frame scheduler (~60ms cadence) and replace $O(N)$ list prepending (`insert(0, ...)`) with amortized $O(1)$ operations; verify with `flutter test test/src/features/topic/`
- [x] 2.2 In `lib/src/features/search/presentation/controllers/multi_search_controller.dart`, replace blocking `writeAsStringSync` on the UI thread with asynchronous `IOSink` streaming; verify with `flutter test`
- [x] 2.3 In `lib/src/ui/messages/views/messages_table_view.dart`, defer date string formatting and payload preview slicing to `cellBuilder` so only visible rows are formatted; verify table rendering and sorting with `flutter test`
- [x] 2.4 In `lib/src/features/topic/presentation/controllers/message_stream_controller.dart` and `multi_search_controller.dart`, cache unmodifiable list views instead of reallocating `List.unmodifiable(...)` on every getter read; verify with `flutter test`

## 3. Verification & Regressions

- [x] 3.1 Run `cargo test --workspace` and verify all Rust unit and integration tests pass
- [x] 3.2 Run `flutter test` and confirm all existing unit, widget, and golden tests pass
- [x] 3.3 Format all touched files with `cargo fmt` and `dart format .`
