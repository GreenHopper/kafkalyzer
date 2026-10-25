# Tasks

## 1. Partition health (B1)

- [x] 1.1 Add `PartitionMetadata` and the two derived health counters to the domain types in `rust/kafkalyzer-core/src/kafka_types.rs`, and extend `TopicMetadata` with `under_replicated_partitions` / `leaderless_partitions`; verify with unit tests in `kafkalyzer-core` that `isr.len() < replicas.len()` classifies as under-replicated and `leader == None` as leaderless, both counted per topic.
- [x] 1.2 Read leader, replicas and ISR from the metadata response in `rust/kafkalyzer-kafka/src/kafka_metadata.rs::fetch_topics` and fill the counters from 1.1 without adding a second metadata round-trip; verify with a test that a three-replica topic with two ISR members yields one under-replicated partition, and that an errored topic yields no healthy partitions.
- [x] 1.3 Add bridge types and `fetch_topic_partitions(profile, topic)` in `rust/src/api/kafka_metadata.rs` returning one row per partition for a single topic; verify with `cargo test -p` on the bridge crate that the mapping produces one row per partition with leader, replicas and ISR, and regenerate the Dart bindings and mocks with `flutter_rust_bridge_codegen generate` plus `dart run build_runner build`.
- [x] 1.4 Show the health counters on the topic list item and the topic sidebar, warning only when a count is non-zero, using localized strings; verify with a widget test that a topic with one under-replicated partition shows the indicator with the count and a healthy topic shows none.
- [x] 1.5 Add the replication columns (leader, replicas, ISR) to the new `topic_partition_health_table.dart` shown in the topic detail view (the consumer lag table keeps its own columns) fed by `fetchTopicPartitions`, with a loading state and an unavailable state; verify with a widget test that three partitions render three rows with leader distinguished, and that an error result marks rows unavailable instead of empty.
- [x] 1.6 Refresh health on user-triggered metadata refresh and clear it on disconnect; verify with a widget test that the indicator disappears after a refresh returns healthy data and that no live indicator is shown after the cluster connection closes (asserted by `disconnect clears state`).

## 2. Consumer group member insights (B2)

- [x] 2.1 Extend `parse_member_subscription` / `parse_member_assignment` in `rust/kafkalyzer-kafka/src/kafka_metadata.rs` to return member id, client id, client host and assigned `(topic, partition)` pairs, including the cooperative-assignor user-data layout; verify with unit tests over captured subscription/assignment byte vectors for both eager and cooperative layouts, and a test that an undecodable assignment returns "not decodable" rather than an empty list.
- [x] 2.2 Add `ConsumerGroupMember` / `TopicPartition` bridge types in `rust/src/api/kafka_types.rs`, attach them to `ConsumerGroupLag`, and derive `unassigned_partitions` from member assignments against known partition counts; verify with a bridge test that a three-member group maps to three members with their partitions and that a partition owned by nobody is reported once, then regenerate Dart bindings and mocks.
- [x] 2.3 Add the members card (an expandable section — the view has no tab strip) to `group_details_view.dart` with member id, client id, host and assignment count, and an explicit empty state for a memberless group; verify with a widget test that three mocked members render three rows and that an empty group renders the empty state with no blank row.
- [x] 2.4 Add the assignment table (topic, partition, owning member) plus the unassigned-partition indicator; verify with a widget test that a rebalance between two refreshes moves a partition to the new member and that a topic with one ownerless partition shows the indicator listing that partition number.
- [x] 2.5 Assert the read-only guarantee for this view: verify with a Rust test that group metadata reads use the existing consumer metadata path only, and with `grep -n "subscribe(\|commit(\|produce" rust/kafkalyzer-kafka/src/kafka_metadata.rs` returning no matches.

## 3. Schema provenance per message (B3)

- [x] 3.1 Add `MessageSchema` and `key_schema` / `value_schema` to `KafkaMessage` in `rust/kafkalyzer-core/src/kafka_types.rs`; verify by compiling the workspace and by a unit test that both fields default to `None` for a plain payload.
- [x] 3.2 Fill the fields in the decode path of `rust/kafkalyzer-kafka/src/kafka_consumer.rs` from the schema id already read at the wire prefix and the existing schema cache, counting cache misses; verify with a test that repeated messages sharing one schema id cause exactly one registry resolution, and with a test that an unreachable registry still returns the same messages with `None` provenance.
- [x] 3.3 Update every `KafkaMessage` construction site in Rust, the bridge mapping, and Dart fixtures/mocks for the new optional fields; verify with `cargo test --manifest-path rust/Cargo.toml` and `flutter analyze` both clean.
- [x] 3.4 Show subject, version and schema id per key and value side in `message_metadata_card.dart`, with a "no registry schema" state; verify with a widget test that a message with value provenance renders all three values labeled per side, and a test that a plain JSON message shows the no-schema state and no error.
- [x] 3.5 Wire the provenance row to the integrated schema inspector so it opens at that subject and version, and make the inspector accept an explicit subject/version entry point; verify with a widget test that activating the row opens the inspector with the requested version selected, and a test that a schema that can no longer be loaded keeps the message-side values visible and shows the inspector error state.

## 4. Report statistics (B4, part 1)

- [x] 4.1 Add a bounded deterministic size sampler (limit 10 000, hash-based priority over `(partition, offset)`) and p50/p95/p99 output to `kafkalyzer-core`; verify with unit tests that a set below the limit yields exact percentiles, that the percentiles of one message equal that size, that percentiles stay between min and max, and that the same input yields the same sample on a repeated run.
- [x] 4.2 Merge sampler state across partition worker accumulators with union-then-trim; verify with a test that a two-worker merge over the same message set equals the single-worker result and that the merged sample never exceeds the limit.
- [x] 4.3 Add `message_size_percentiles`, `size_percentiles_estimated`, `estimated_distinct_keys` and `key_cardinality_capped` to `TopicAnalysisReport`, wire them in `rust/kafkalyzer-kafka/src/kafka_analyzer.rs`, and keep `format_version` unchanged; verify with a test that a scan of 100 000 messages sets the estimated flag, that a scan of 100 messages sets it false, and that a capped key map sets `key_cardinality_capped`.
- [x] 4.4 Render the percentile row and the distinct-key row in the analysis summary cards with exact-versus-estimated labeling, and add the localized strings to `app_en.arb` / `app_de.arb` with matching key counts; verify with a widget test that the estimated label appears only when the flag is set, and `flutter gen-l10n` plus `flutter analyze` stay clean.

## 5. Report comparison (B4, part 2)

- [x] 5.1 Implement `compare_reports(a, b)` in `kafkalyzer-core` producing per-metric absolute and relative deltas, field-frequency additions/removals, and a not-comparable marker for metrics missing on one side; verify with unit tests for a +20 % volume delta, a metric present on one side only, added/removed field names, and reports from different clusters staying comparable.
- [x] 5.2 Expose the comparison through the bridge and keep report file import tolerant of the new optional fields; verify with a Rust test that a report file written without the new fields imports and compares with the new fields marked unavailable, and regenerate bindings/mocks.
- [x] 5.3 Add the comparison picker and side-by-side delta view to the analysis toolbar, rejecting a pair whose topics differ with a message naming both topics; verify with widget tests for live-versus-imported comparison, two imported reports compared with no cluster connection, mismatched-topic rejection, and the missing-second-report prompt.

## 6. Lag trend and threshold (B5)

- [x] 6.1 Keep the last 20 lag readings per group in the lag view state, appended on each successful refresh and cleared on disconnect or cluster switch; verify with a widget test that five refreshes retain five readings, that the retained count never exceeds 20, and that reconnecting to another cluster starts with an empty history.
- [x] 6.2 Draw the trend with a `CustomPainter` widget in the group row and in the partition table rows, with a tooltip listing the retained readings and their extremes; verify with a widget test that a rising series renders a rising trend next to the current value, that a single reading renders no trend line, and that hovering exposes highest and lowest retained values.
- [x] 6.3 Add the integer lag warning threshold to `SettingsService` as helper methods on key `consumer_lag_warn_threshold` (default 0 = disabled) and apply it in the lag view; verify with a unit test that the value round-trips through `shared_preferences` and with a widget test that a group at 8000 is marked at threshold 5000 while a group at 1200 is not, and that a disabled threshold marks nothing.

## 7. Cross-cutting verification

- [x] 7.1 Run `cargo test --manifest-path rust/Cargo.toml`, `cargo clippy --manifest-path rust/Cargo.toml --all-targets`, `flutter analyze` and `flutter test --reporter json`; verify all suites pass and record the suite and test counts.
  - Rust: 111 tests pass (kafkalyzer-core 46, kafkalyzer-kafka 53, bridge 12). Clippy reports only the pre-existing style warnings (argument count, `to_*` by value, one redundant `if let`).
  - Dart: `flutter analyze lib test` clean. `flutter test --reporter json`: 98 suites, 808 tests, 0 failed.
- [x] 7.2 Re-assert the read-only invariant after all groups: verify with a grep over the Rust crates that no producer type, offset commit, group `subscribe()`, topic/config/ACL write call was introduced, and that the only new cluster calls are metadata reads.
  - Grep for `BaseProducer|TopicProducer|ProducerContext|.produce(|delivery_handle|create_topic|delete_records|alter_configs|incremental_alter|create_part|delete_group|.commit(|subscribe(` over `rust/kafkalyzer-kafka/src`, `rust/src/api`, `rust/kafkalyzer-core/src`: no matches.
  - Only cluster calls remain the reads: `describe_configs` (pre-existing) plus the new `fetch_topic_partitions` and the group member/lag reads.
- [ ] 7.3 Verify against the local `docker-compose.yaml` cluster: kill a broker and confirm the under-replicated and leaderless counters and the topic list indicator change on refresh; open a group with two clients and confirm the member rows and assignments; confirm a message shows subject/version/schema id and jumps to that version; run a second analysis, compare it with the first, and confirm the deltas; refresh lag five times and confirm the trend and the threshold marking.

## Workflow follow-up

- Sync delta specs into `openspec/specs/` and archive with `openspec archive --change "improve-metadata-diagnostics"`, then commit and push.
- Update `design/feature-gap-analysis.md` §4 (B1–B5) with the implemented state and this change's name.
