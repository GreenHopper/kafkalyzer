# Tasks

## 1. Spikes and prerequisites

- [ ] 1.1 Spike brokers-only metadata (design D1) against `docker-compose.yaml`: a throwaway test in
      `kafkalyzer-kafka` calls `rd_kafka_metadata(rk, 0, NULL, …)` on a fresh `BaseConsumer`, then
      `rd_kafka_clusterid(rk, 0)` / `rd_kafka_controllerid(rk, 0)`. Record in design.md (Spike results): broker count,
      topic count (expected 0), cluster id/controller non-null, behaviour for a user without topic DESCRIBE, and KRaft
      controller value. If the topic list is not empty or brokers are missing, switch D1 to the `fetch_metadata(None)`
      fallback. Verify: findings written, throwaway test removed.
- [ ] 1.2 Spike the probe (design D3) on a transactional and a compacted test topic: confirm `PartitionEOF` arrives
      after the tail window, `pause()` stops further deliveries in the head phase, and a tail of 16 offsets contains a
      data record for a normal transactional producer. Record results in design.md. Verify: findings written.
- [ ] 1.3 Confirm prerequisites on disk: 5.11 `kafka_metadata::fetch_partition_offsets`, `kafkalyzer_core::
      offset_distribution` and bridge `fetch_partition_offsets` exist; check whether 5.33's `describe_topic_configs`
      exists. Verify: `grep -rn "fn fetch_partition_offsets\|fn describe_topic_configs" rust/` lists the functions or the
      gap is noted for task 3.3.

## 2. kafkalyzer-core

- [ ] 2.1 Add `rust/kafkalyzer-core/src/topic_time_range.rs` (export in `lib.rs`): outcome types, `tail_start_offset(low,
      high, window)`, `aggregate(&[PartitionProbe]) -> TopicTimeRange` (design D3). Unit tests: empty topic, all
      partitions empty, one `NotFoundInWindow`, one `TimedOut`, `NoTimestamp`, min/max across partitions with
      non-monotonic timestamps, `high - window < low`, all unknown ≠ empty. Verify: `cargo test -p kafkalyzer-core
      topic_time_range` passes.

## 3. kafkalyzer-kafka

- [ ] 3.1 Add `kafka_metadata::fetch_cluster_overview(profile)` with RAII guard for `rd_kafka_metadata_destroy`,
      `rd_kafka_mem_free` for the cluster id, brokers sorted by id, `-1` controller → `None`, authorization errors mapped
      to a "not readable" error (design D1). Unit-test the pure mapping (raw broker list → sorted endpoints, controller
      `-1`). Verify: `cargo test -p kafkalyzer-kafka` passes; `scripts/check_read_only.sh` passes.
- [ ] 3.2 Add `rust/kafkalyzer-kafka/src/topic_time_range.rs` with `fetch_topic_time_range(profile, topic, deadline)`:
      watermarks via `fetch_partition_offsets`, consumer config exactly as design D3 step 2 (manual `assign()`, no
      `subscribe()`, auto commit and offset store off, `enable.partition.eof=true`, capped
      `queued.max.messages.kbytes`), head/tail phases with in-memory progress only and a shared deadline; payloads are
      dropped after reading the timestamp. Add a broker-free test for the per-partition state machine (EOF, deadline,
      message after pause) by factoring the event handling into a function over a fake event list. Verify: `cargo test
      -p kafkalyzer-kafka` passes; `scripts/check_read_only.sh` passes.
- [ ] 3.3 Only if task 1.3 found no `describe_topic_configs`: create `describe_topic_configs(profile, topics) ->
      per-topic Result` exactly as 5.33 specifies (all entries with value, source/default and sensitive flags,
      DescribeConfigs only, chunked) and note it in 5.33's tasks hand-off. Verify: unit test of the entry mapping passes.
- [ ] 3.4 Optional live check (if the docker-compose broker runs): `#[ignore]` integration tests for
      `fetch_cluster_overview` and `fetch_topic_time_range` on a seeded topic. Verify: `cargo test -- --ignored` passes
      locally, or skip noted.

## 4. Bridge

- [ ] 4.1 In `rust/src/api/kafka_metadata.rs` add DTOs `ClusterOverview`, `TopicTimeRange`, `PartitionTimeProbe`
      (outcome enum + optional offset/timestamp/type/reason) with `From` mappings, and functions
      `fetch_cluster_overview(profile)` and `fetch_topic_time_range(profile, topic)` (15 s deadline). Existing
      signatures unchanged. Verify: `cargo build` in `rust/` succeeds.
- [ ] 4.2 Regenerate: `flutter_rust_bridge_codegen generate`, then `dart run build_runner build` (bridge mocks). Verify:
      `lib/src/rust/api/kafka_metadata.dart` contains the new functions; `flutter analyze` has no new errors.

## 5. Dart: services, controllers, formatting

- [ ] 5.1 `KafkaMetadataService`: add `fetchClusterOverview` and `fetchTopicTimeRange` (and `describeTopicConfigs` /
      `fetchPartitionOffsets` wrappers if 5.33/5.11 did not add them). Verify: service unit test with the regenerated
      mocks passes.
- [ ] 5.2 Pure `summarizeCluster(List<TopicMetadata>)` in `lib/src/features/explorer/domain/` (topic/partition totals,
      unhealthy count, under-replicated/leaderless partition totals, unknown-health count, internal topics included).
      Verify: unit tests for healthy, mixed, unknown and empty lists pass.
- [ ] 5.3 `ClusterOverviewController` (`ChangeNotifier`, registered in `dependency_injection.dart`): broker read state per
      cluster name (`loading | value | error(notReadable)`), `load(profile)`, `refresh(profile)` (also forces the topic
      list reload), cleared on disconnect. Verify: controller unit tests for success, error, not-readable, refresh.
- [ ] 5.4 `TopicFactsController` per tab via `activeController.getTopicFactsController(key)` with the three states and
      `loadFacts()` / `refresh()` / `loadTimeRange()` (design D6), disposed with the tab. Verify: unit tests for
      estimate unknown on one failed partition, configs not readable, time range partial/empty/error.
- [ ] 5.5 `ActiveConnectionController` drill-down hook (design D5): `unhealthyTopicsOnly`, `showUnhealthyTopicsOnly()`,
      `clearUnhealthyTopicsOnly()`, applied first in `topics`, bypassing internal/stream toggles, reset on
      connect/disconnect, not persisted. Verify: unit tests for internal unhealthy topic shown, clear restores regular
      filters, reset on cluster switch, refresh drops a healed topic.
- [ ] 5.6 `topic_utils.dart`: `formatRetentionDuration(raw, l10n)` and `formatRetentionBytes(raw, l10n)` (design D8);
      replace `formatRetention` in `topic_detail_view.dart` and `topic_list_item.dart` and delete it. Update
      `test/src/features/topic/topic_utils_test.dart`: `129600000` → "1 day 12 hours"/"1 Tag 12 Stunden", `5400000` →
      "1 hour 30 minutes", `-1` → unlimited, `0`, seconds, non-numeric raw value, `1073741824` bytes → "1.00 GB".
      Verify: tests pass.

## 6. Dart: UI

- [ ] 6.1 Rework `ClusterOverviewView`: broker section (id/host/port list, count, cluster id row only when present,
      controller row or "unknown", loading, error with cause + Retry, "not readable"), totals card (topics, partitions;
      loading/unknown instead of 0 when the topic list is loading or failed), health summary (icon + text, unhealthy
      count as drill-down action only when > 0, unknown-health count), refresh `IconButton` with tooltip and semantic
      label. Wire it in `explorer_view.dart` (pass topic list state/error, `onShowUnhealthyTopics`). Extend
      `test/src/features/explorer/presentation/widgets/cluster_overview_view_test.dart`: brokers ordered by id, totals,
      no "0 Topics" on failed load, missing cluster id hidden, controller unknown, broker error + retry, drill-down tap
      calls the hook, no drill-down at 0, German rendering. Verify: tests pass.
- [ ] 6.2 Sidebar chip for the drill-down filter (label with count, delete action) in the explorer sidebar. Verify:
      widget test shows the chip after `showUnhealthyTopicsOnly()` and removes the filter on delete.
- [ ] 6.3 Topic header: localized partitions/RF tags, estimate tag with "estimate" label and compaction note tooltip,
      retention duration and bytes ("per partition"), "Load time range" button (tooltip shows partition count) with
      progress, result (oldest/newest with zone per `TimeDisplaySettings`, partial marker with contributing count, hover
      reasons), empty-topic text, error + Retry, header refresh icon button; facts load only when the tab becomes
      active (design D6). Extend `test/src/features/topic/topic_detail_view_test.dart`: estimate shown/unknown,
      compaction note, background tab does not load, time range only on tap, partial and empty results, retention
      unlimited/not readable, German tags. Verify: tests pass.
- [ ] 6.4 Add every new key to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` (ICU plurals for durations, partitions,
      counts); regenerate localizations. If "Available Topics" was replaced in 6.1, remove its entry from
      `test/l10n/hardcoded_strings_allowlist.txt`. Verify: `flutter test test/l10n/` passes (ARB consistency and
      hard-coded-string guard).

## 7. Final verification

- [ ] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`; then
      `dart format lib test`, `flutter analyze`, `flutter test`, `scripts/check_read_only.sh`. Verify: all exit 0 and the
      read-only gate passes without new exceptions.
- [ ] 7.2 Manual check against the docker-compose cluster (if available): overview lists brokers and cluster id,
      unhealthy drill-down after stopping one broker, time range on a seeded topic, German locale. Verify: observations
      noted in the PR, or skip noted.
