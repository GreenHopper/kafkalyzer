## Why

Benchmarking and profiling revealed significant performance bottlenecks in both Rust message consumption and Flutter UI stream ingestion. High-volume Kafka consumption triggers regex recompilation on every message, blocking Schema Registry lookups inside tight loops, unthrottled UI notifications (thousands of widget rebuilds per second), and blocking main-thread file I/O, causing severe frame drops and sluggish UI responsiveness. Addressing these bottlenecks ensures fluid 60fps interaction and orders-of-magnitude faster message throughput across Kafkalyzer.

## What Changes

- **Pre-compile Filter Expressions**: Pre-compile regex filters and Duration parsing patterns once prior to the consumption loop rather than evaluating per message.
- **In-Memory Schema Registry & Static Runtimes**: Introduce in-memory caching for decoded schemas and reuse Tokio runtime instances to avoid blocking thread pools per message.
- **Zero-Copy & Direct Value Filtering**: Eliminate redundant string serializations and string-to-JSON re-parsing during message filtering in the consumer hot path.
- **Throttled Stream Ingestion**: Buffer incoming stream events and throttle Flutter UI state notifications (`notifyListeners`) to a consistent ~60ms frame cadence in `MessageStreamController`.
- **Amortized Message Buffering**: Replace $O(N)$ list prepending (`insert(0, ...)`) with amortized $O(1)$ operations and cache unmodifiable list views.
- **Non-Blocking File Logging**: Replace synchronous disk writes (`writeAsStringSync`) on the main UI isolate with asynchronous file sinks.
- **Lazy Table Formatting**: Defer date string formatting and payload previews to viewport item builders in message table and timeline views rather than pre-computing all rows on every update.
- **Release Profile Tuning**: Enable Link-Time Optimization (LTO), single codegen-unit, and abort panics in `rust/Cargo.toml`.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities

- `topic-consumption`: Message consumption must execute with pre-compiled filters, cached schema lookups, and throttled UI dispatch without blocking the main event loops.
- `topic-content-analysis`: Topic analysis must decouple atomic scan progress reporting from heavy full-state accumulator clones and avoid unnecessary worker sleep stalls.

## Impact

- **Rust Backend**: `rust/kafkalyzer-kafka` (`kafka_consumer.rs`, `kafka_analyzer.rs`), `rust/kafkalyzer-core` (`avro_utils.rs`), `rust/Cargo.toml`.
- **Flutter Layer**: `lib/src/features/topic` (`message_stream_controller.dart`), `lib/src/features/search` (`multi_search_controller.dart`), `lib/src/ui/messages` (`messages_view.dart`, `messages_table_view.dart`).
- **APIs & Data Contracts**: No breaking changes to public FFI contracts or Flutter-Rust bridge types.
