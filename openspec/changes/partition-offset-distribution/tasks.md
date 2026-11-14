# Tasks

## 1. Spike

- [ ] 1.1 Spike: against the local `docker-compose.yaml` broker (topic with ≥ 50 partitions created with the
  container's own `kafka-topics` CLI, never from app code), call `fetch_watermarks` from 8 scoped threads sharing one
  `&BaseConsumer` and compare results and wall time with a sequential loop; also check which `KafkaError` /
  `RDKafkaErrorCode` a leaderless partition and a topic without Describe ACL produce. Verify: findings (parallel OK or
  fallback D3 (b), error codes, timings) recorded in design.md D3 before task 3.1 starts.

## 2. kafkalyzer-core: distribution maths

- [ ] 2.1 Add `rust/kafkalyzer-core/src/offset_distribution.rs` (+ `pub mod` in `lib.rs`) with `WatermarkRead`,
  `PartitionWatermarks`, `PartitionShare`, `SkewStatus`/`SkewSkipReason`, `OffsetDistribution` and
  `summarize_offsets(&[PartitionWatermarks], Option<u8>)` per design D2 (serde derives like `partition_health.rs`).
  Verify: `cargo build -p kafkalyzer-core` succeeds.
- [ ] 2.2 Unit tests in the same module: 60/40 shares (spec example), empty topic (`Empty`, no shares), one
  `Failed`/`NotReadable`/`TimedOut` row (no total, no shares, `Incomplete`, other spans kept), `low > high` and negative
  offsets become `Failed`, single partition (`SinglePartition`), 700/200/100 at 50 % → partition 0 skewed, 500/500 at
  50 % not skewed, 700/200/100 at 80 % `Balanced`, threshold `None` → `NotRequested`, `i64::MAX` spans saturate,
  unsorted input sorted by partition. Verify: `cargo test -p kafkalyzer-core offset_distribution` passes.

## 3. kafkalyzer-kafka: on-demand watermark read

- [ ] 3.1 Add `TopicPartitionOffsets` and `fetch_partition_offsets(&ClusterProfile, &str)` to
  `rust/kafkalyzer-kafka/src/kafka_metadata.rs` per design D3: `create_config` + `enable.auto.commit=false`, one
  `fetch_metadata(Some(topic), 10 s)` (missing topic / topic error → `Err` with the error code kept), `min(8, P)` scoped
  workers over an `AtomicUsize` index, per-read timeout `min(5 s, remaining)`, 30 s overall deadline, unclaimed
  partitions `TimedOut`, results sorted, `read_at_ms` set. Constants as named `const`s. Verify: `cargo build -p
  kafkalyzer-kafka` succeeds and no `assign`/`subscribe`/Admin client appears in the function.
- [ ] 3.2 Extract the error mapping into a pure helper (`classify_watermark_error(&KafkaError) -> WatermarkRead`:
  authorization codes → `NotReadable`, rest → `Failed`) and the deadline/claiming loop into a function that takes a
  read closure, so both are unit-testable without a broker. Verify: tests in `kafka_metadata.rs` cover authorization →
  not readable, other error → failed, a closure that sleeps past a short test deadline leaves later partitions
  `TimedOut`, and worker count never exceeds 8 or `P`; `cargo test -p kafkalyzer-kafka` passes.

## 4. Bridge crate and code generation

- [ ] 4.1 In `rust/src/api/kafka_metadata.rs` add `PartitionOffsetState`, `OffsetSkewStatus`, `PartitionOffsetRow`,
  `PartitionOffsetDistribution` and `fetch_partition_offsets(profile, topic, skew_threshold_percent: Option<u32>)`
  per design D4 (threshold outside 1..=100 → `Err`; mapping domain → DTO via `From`). Existing functions and
  `PartitionRow` unchanged. Verify: mapping tests in the module's `tests` (known row with share, not-readable row with
  error and `None` values, skewed flag, invalid threshold error) pass with `cargo test -p rust_lib_kafkalyzer`.
- [ ] 4.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify: `lib/src/rust/api/
  kafka_metadata.dart` exposes `fetchPartitionOffsets` and the new types, `test/src/rust/api/rust_mocks.mocks.dart` is
  regenerated, and `git diff` shows no change to existing generated signatures.

## 5. Dart: service and setting

- [ ] 5.1 Add `fetchPartitionOffsets({profile, topic, skewThresholdPercent})` to
  `lib/src/services/kafka_metadata_service.dart`. Verify: `flutter analyze lib/src/services` clean; existing fakes that
  `implements KafkaMetadataService` with `noSuchMethod` still compile (`flutter analyze test`).
- [ ] 5.2 Add `SettingsService.partitionSkewThresholdSetting = IntSetting('topic_partition_skew_threshold_percent', 50,
  1, 100)`, include it in `resetGeneralSettings`, and add an `_IntSettingField` (key
  `partition_skew_threshold_field`) in the General section of `settings_view.dart`. Verify: settings tests for 0/150
  rejected with range error, stored 0 read as 50 via `readInt`, and General reset writes 50.

## 6. Dart: offset distribution view

- [ ] 6.1 Add `lib/src/features/topic/presentation/widgets/partition_offset_distribution_view.dart` per design D5
  (loading, inline error + retry, lazily built rows with low/high/span/share bar, unknown values as localized
  "unknown", per-row state text and permission hint, read time, refresh single-flight, estimate title, compaction /
  unknown-policy / incomplete / empty notes, skew badge with icon + text in `tertiary` roles, exact-values action,
  stale note when `ActiveConnectionController.activeProfile` changes). Verify: widget tests with a fake service cover
  each spec scenario of "Estimated Partition Offset Distribution", "Offset Spans Are Not Message Counts" and "Offset
  Distribution Skew Hint", plus refresh rereading once and a 1,000-row result building only visible rows.
- [ ] 6.2 Wire the view into `TopicPartitionHealthDialog` (optional `cleanupPolicy`, `onOpenAnalysis`; scrollable
  body, larger max height) and pass `widget.topic.cleanupPolicy` plus a callback that pops the dialog and sets
  `_viewMode = TopicViewMode.analysis` from `topic_detail_view.dart`. Verify: widget test in
  `test/src/features/topic/topic_detail_view_test.dart` opens the dialog from the partitions tag, sees offsets loaded
  once, taps the exact-values action and lands on the analysis view without a scan starting; a test asserts the
  analysis tab card and the topic list never call `fetchPartitionOffsets`.
- [ ] 6.3 Add every new string to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` (feature prefix `partitionOffset…`,
  ICU plurals for counts, reuse existing keys such as `retry` and `estimatedIndicator` where the meaning matches) and
  run `flutter gen-l10n`. Verify: `flutter test test/l10n` (hard-coded-string guard and ARB consistency) passes
  without new allowlist entries.

## 7. Final verification

- [ ] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no new warnings), `cargo test
  --workspace` — all pass.
- [ ] 7.2 `dart format lib test`, `flutter analyze` (no issues), `flutter test` (all pass).
- [ ] 7.3 `scripts/check_read_only.sh` passes unchanged (no new exception).
- [ ] 7.4 Manual check against the local docker broker: open a topic's partition health dialog, see offsets, shares,
  read time and the skew badge for a deliberately skewed topic; confirm the topic list refresh issues no ListOffsets
  (librdkafka `debug=protocol` log or broker request metrics).
