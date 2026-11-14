# Tasks

## 1. kafkalyzer-core: partitioner (single source of truth)

- [ ] 1.1 Write failing tests first in new `rust/kafkalyzer-core/src/partitioner.rs` (`#[cfg(test)]`): `murmur2`
      against Kafka's reference vectors from `UtilsTest.testMurmur2` (check the upstream file; as `i32`: `"21"` →
      -973932308, `"foobar"` → -790332482, `"a-little-bit-long-string"` → -985981536,
      `"a-little-bit-longer-string"` → -1486304829, `"lkjh234lh9fiuh90y23oiuhsafujhadof229phr9h19h89h8"` → -58897971,
      `b"abc"` → 479470107); `default_partition` returns `None` for counts `0` and `-1`, `Some(p)` with
      `0 <= p < n` otherwise, equals `(murmur2 & 0x7fffffff) % n`, and hashes a non-ASCII key (`"ü-key"`) over its
      UTF-8 bytes. Register `pub mod partitioner;` in `lib.rs`. Verify: `cargo test -p kafkalyzer-core partitioner`
      fails to compile/fails (RED).
- [ ] 1.2 Move `murmur2` and `to_positive` verbatim from `rust/kafkalyzer-kafka/src/kafka_utils.rs` into
      `partitioner.rs` and add `default_partition(key: &[u8], partition_count: i32) -> Option<i32>`. Verify:
      `cargo test -p kafkalyzer-core partitioner` passes (GREEN). If a reference vector fails, fix `murmur2` in core —
      that is a scan bug, not a test problem.

## 2. kafkalyzer-kafka: scan uses the core function

- [ ] 2.1 In `kafka_utils.rs` replace the moved bodies with `pub use kafkalyzer_core::partitioner::{murmur2, to_positive};`.
      In `kafka_consumer.rs::resolve_target_partitions` compute the target with `default_partition(key.as_bytes(),
      partition_count)`; behaviour for 0 partitions (scan all) stays. Do not log the key (keep the keyless log line
      from `app-diagnostics-and-error-reporting` 2.2 if it has landed; otherwise use `log::debug!` with topic, count and
      partition only). Verify: `cargo test -p kafkalyzer-kafka` passes and
      `rg -n "fn murmur2" rust/kafkalyzer-kafka` is empty.

## 3. Bridge crate and regeneration

- [ ] 3.1 Add `pub fn predict_default_partition(key: String, partition_count: i32) -> Option<i32>` to
      `rust/src/api/kafka_utils.rs` delegating to `kafkalyzer_core::partitioner::default_partition(key.as_bytes(), …)`,
      with a unit test that it equals the core result for one key and returns `None` for 0. Keep the `murmur2` /
      `to_positive` bridge wrappers unchanged. Verify: `cargo test --workspace` passes.
- [ ] 3.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify:
      `lib/src/rust/api/kafka_utils.dart` exposes `predictDefaultPartition`, the mock
      `crateApiKafkaUtilsPredictDefaultPartition` exists in `test/src/rust/api/rust_mocks.mocks.dart`, and
      `test/src/rust/api/kafka_utils_test.dart` gets a case calling `predictDefaultPartition` through the mock and passes.

## 4. Dart: shared key derivation

- [ ] 4.1 Add a top-level `splitFilterTerms(String text)` (split on `,`, trim, drop empties) under
      `lib/src/features/search/domain/` with a unit test (`" a , ,b "` → `["a","b"]`, `""` → `[]`). Use it in
      `topic_detail_view.dart` `startStreaming` instead of the inline split. Verify: new test and existing
      `test/src/features/topic/**` tests pass.

## 5. Dart: preview in the topic search bar

- [ ] 5.1 Add en + de ARB keys (then `flutter gen-l10n` if not automatic): partition line (`P` of `N`, placeholders),
      "partition count unknown", "enter a key", "only the first term selects the partition", one-line assumption
      ("Assumes Java default partitioner, UTF-8 text key"), full caveat (librdkafka `consistent`/CRC32 default, custom
      partitioners, binary/serialized keys such as Avro keys with Confluent wire prefix, partitions added later), info
      icon semantic label, chip label with partition. Verify: both ARB files contain every key; `flutter analyze` clean.
- [ ] 5.2 Write failing widget tests in `test/src/features/search/presentation/widgets/topic_search_bar_test.dart`
      (stub `crateApiKafkaUtilsPredictDefaultPartition`): partition + count shown with Fast Trace on, key entered and
      `partitionCount: 12`; "unknown" for `partitionCount` `0` and `null` with **no** bridge call; hint and no number for
      empty key; first-term note for `"a,b"` and the bridge called with `"a"`; stale answer for an old key text does
      not overwrite the current one; chip shows the partition when collapsed; assumption text and caveat tooltip
      present; bridge error shows "unknown". Verify: tests fail (RED).
- [ ] 5.3 Implement per design.md Decision 4 in `topic_search_bar.dart` (new optional `int? partitionCount`,
      debounced bridge call with request counter, states, chip label, `l10n.fastTrace` replacing the hardcoded switch
      label, tooltip + semantic label on the info icon, status not by colour alone) and pass
      `widget.topic.partitionCount` from `topic_detail_view.dart`. Verify: 5.2 tests pass (GREEN) and existing
      `topic_search_bar_test.dart` cases still pass.

## 6. Dart: script step editor disclosure

- [ ] 6.1 Add the caveat tooltip (same ARB keys) to the Fast Trace switch in `search_stream_configuration.dart`; no
      computed partition. Add a widget test in `test/src/features/search/search_stream_configuration_preset_test.dart`
      (or a new file next to it) that the tooltip text is present. Verify: test passes.

## 7. Final verification

- [ ] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace` — all clean.
- [ ] 7.2 `dart format lib test`, `flutter analyze`, `flutter test` — all clean.
- [ ] 7.3 `scripts/check_read_only.sh` passes unchanged (no new Kafka/Schema Registry calls).
- [ ] 7.4 Manual check against a test cluster: produce-free — pick an existing message with a known string key
      produced by a Java client, enable Fast Trace with that key, confirm the previewed partition equals the message's
      partition and the scan finds it.
