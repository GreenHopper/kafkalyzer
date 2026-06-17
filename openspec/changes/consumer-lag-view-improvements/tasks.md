## 1. Backend API (Rust)

- [x] 1.1 Add `members_count` and `topics_count` fields to `ConsumerGroupLag` struct in `rust/kafkalyzer-core/src/kafka_types.rs` and `rust/src/api/kafka_types.rs`.
- [x] 1.2 Update conversion logic (`From` implementations) in the main api crate.
- [x] 1.3 Update `fetch_consumer_groups` and `fetch_consumer_group_lag` in `rust/kafkalyzer-kafka/src/kafka_metadata.rs` to calculate and populate the counts.
- [x] 1.4 Update Rust unit tests to match modified structures and verify correctness.


## 2. Bridge & Service Layer

- [x] 2.1 Run `flutter_rust_bridge_codegen generate` to regenerate Dart/Rust interface types.
- [x] 2.2 Update `FakeKafkaMetadataService` mock implementations in `consumer_lag_view_test.dart` to support new fields.


## 3. Frontend UI (Dart/Flutter)

- [x] 3.1 Replace list-of-cards builder in `consumer_lag_view.dart` with a tabular layout (e.g. `DataTable` or scrollable list of row tables) representing Group ID, State, Protocol, Consumers, Topics, and Lag.
- [x] 3.2 Implement column headers clicking callback to toggle sorting index and direction.
- [x] 3.3 Display match count label (e.g. "Found X of Y groups") next to search bar.
- [x] 3.4 Add dropdown filter widget for group status (All, Stable, Empty, Dead) next to search bar and update filtering logic to support it.
- [x] 3.5 Replace refresh Switch with a Dropdown interval selector enabling customizable polling frequencies (Off, 5s, 15s, 30s, 60s).
- [x] 3.6 Group `TopicPartitionLag` elements in details by Topic name, computing total lag per topic.
- [x] 3.7 Implement `TopicPartitionTable` widget displaying partition offsets and lags, enabling column-based sorting on partition index, log end offset, committed offset, and lag.
- [x] 3.8 Render a sortable list/table of Topics under the group details. Implement sorting on Topic Name and Topic Lag (ascending/descending). Clicking a topic expands to render the `TopicPartitionTable` for that topic.
- [x] 3.9 Add/update Flutter widget tests verifying sorting, custom polling intervals, search stats, and nested topic grouping.
