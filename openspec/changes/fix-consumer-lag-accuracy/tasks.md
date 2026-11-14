# Tasks

## 1. Spike: committed offsets of a member-less group (design D1)

- [x] 1.1 Prepare a reproducible broker fixture with `docker compose up -d kafka` (`localhost:9094`): create topic `lag-spike` (3 partitions) and produce 150 messages with the container's `kafka-console-producer`, run `kafka-console-consumer --group lag-spike-g --max-messages 100` and stop it so the group is `Empty` with commits on some partitions only; document the exact commands in `openspec/changes/fix-consumer-lag-accuracy/spike.md` and verify with `kafka-consumer-groups --describe --group lag-spike-g` (no members, committed offsets shown, at least one partition without commit)
- [x] 1.2 Throw-away prototype (not committed) of candidate A: call `rd_kafka_ListConsumerGroupOffsets` through `rdkafka-sys` 4.7.0 with partitions `NULL` for `lag-spike-g`; record in `spike.md` whether it returns all committed partitions, how "group not found" and authorization errors are reported, and the required `unsafe` surface
- [x] 1.3 Throw-away prototype of candidate B: `committed_offsets` on a `BaseConsumer` with `group.id=lag-spike-g`, `enable.auto.commit=false`, no subscribe/assign, over all partitions of all non-internal topics; record result shape (`Offset::Invalid` for no commit) and request time for the fixture and an estimate for 10 000 partitions in `spike.md`
- [x] 1.4 Verify read-only behaviour for the chosen path: run the prototype 5 times and confirm with `kafka-consumer-groups --describe --members --group lag-spike-g` that the group stays `Empty` with no members and unchanged committed offsets; also run it against a running console consumer group and confirm no rebalance (generation unchanged); record evidence in `spike.md`
- [x] 1.5 Record the decision (A, B or fallback "unknown"), chunk size and candidate-B partition cap in `spike.md` and update design.md D1 "Open Questions"; verify `openspec validate fix-consumer-lag-accuracy --strict` still passes

## 2. kafkalyzer-core: pure lag rules (design D2, D4)

- [x] 2.1 Add `PartitionLagStatus { Known, NoCommit, Unknown }` and the additive fields `status`, `error` on `TopicPartitionLag` and `lag_error`, `ownership_known` on `ConsumerGroupLag` in `rust/kafkalyzer-core/src/kafka_types.rs` (serde defaults so old JSON still deserialises); fix all constructors in the workspace and verify `cargo build --workspace` in `rust/`
- [x] 2.2 Implement `classify_partition` (committed offset option + log-end result → status, lag, error; lag 0/current -1 placeholders for non-`Known`) with unit tests for known lag, no commit, unreadable log end, committed above log end; verify `cargo test -p kafkalyzer-core`
- [x] 2.3 Implement `group_total` returning `Known(sum)`, `NoCommittedOffsets` or `Unknown(reason)` (any `Unknown` partition or group error → `Unknown`; `NoCommit` excluded and counted) with unit tests incl. empty list and mixed statuses; verify `cargo test -p kafkalyzer-core`
- [x] 2.4 Move `unassigned_partitions` into `kafkalyzer-core` returning `None` when any member assignment is undecodable or there are no members; port the two existing tests and change `member_without_a_decodable_assignment_is_marked` to expect `None`; add a no-members test; verify `cargo test -p kafkalyzer-core`

## 3. kafkalyzer-kafka: one lag implementation (design D1, D3, D5, D7)

- [x] 3.1 Add the committed-offset reader chosen in 1.5 (A: minimal RAII FFI wrapper binding only `ListConsumerGroupOffsets`; B: bounded `committed_offsets` with partition cap; fallback: return "cannot list" error) behind one function returning committed offsets per topic-partition or an error; the reading consumer sets `enable.auto.commit=false` and `enable.auto.offset.store=false`; verify unit tests for result mapping and `cargo clippy -p kafkalyzer-kafka --all-targets`
- [x] 3.2 Implement the shared per-call lag function in `kafka_metadata.rs`: members for every state, topic set = subscriptions ∪ assignments ∪ committed topics, per-call metadata cache, shared watermark cache, unreadable topic metadata / watermarks → `Unknown` rows with reason, per-group `Result` boundary → `lag_error`, `ownership_known` and unassigned only for `Stable` groups via 2.4; verify with unit tests on the pure assembly step (no broker) and `cargo test -p kafkalyzer-kafka`
- [x] 3.3 Re-implement `fetch_consumer_lags`, `fetch_consumer_groups` (members in all states, no lag) and `fetch_consumer_group_lag` on top of 3.2 with unchanged signatures, and add `fetch_consumer_group_lags(profile, group_ids)` returning one entry per requested id (unknown id → `lag_error` "group not found"); a failing group must no longer be skipped via `continue`; verify `cargo test -p kafkalyzer-kafka` and `grep -n "continue" rust/kafkalyzer-kafka/src/kafka_metadata.rs` shows no group-dropping path
- [x] 3.4 Run the shared function against the 1.1 fixture via a temporary `#[ignore]` test or the spike notes and confirm: `lag-spike-g` lists all 3 partitions, committed ones with lag = 150 − committed, the uncommitted one as `NoCommit`; record in `spike.md`

## 4. Bridge: DTOs and generated code (design D2, D3)

- [x] 4.1 Extend `rust/src/api/kafka_types.rs` additively (`PartitionLagStatus` DTO enum, `status`, `error`, `lag_error`, `ownership_known`) with `From` mappings and extend the existing mapping test in that file; verify `cargo test -p rust_lib_kafkalyzer`
- [x] 4.2 Add bridge function `fetch_consumer_group_lags(profile, group_ids)` in `rust/src/api/kafka_metadata.rs` delegating to 3.3; verify `cargo build --workspace`
- [x] 4.3 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build` (regenerates `lib/src/rust/` and `test/src/rust/api/rust_mocks.mocks.dart`); add `fetchConsumerGroupLags` to `lib/src/services/kafka_metadata_service.dart` with tests in `test/src/rust/api/kafka_metadata_test.dart` and `test/src/services/kafka_metadata_service_test.dart`; verify `flutter analyze` and those tests pass with existing callers unchanged

## 5. Dart UI: consumer lag view and details (design D6)

- [x] 5.1 Add one helper (e.g. in `lib/src/features/consumer/domain/`) returning a group's known total lag or `null` from partition `status` and `lagError`, plus "no commit" count; route `_calculateGroupLag`, lag deltas/history and `group_details_view.dart` topic totals through it so `NoCommit`/`Unknown` rows never add placeholder zeros; verify a unit test with mixed statuses
- [x] 5.2 Make the refresh single-flight with a generation counter in `consumer_lag_view.dart` (timer tick skipped while running, refresh button shows progress and is disabled, stale/outdated-profile results discarded, previous values kept until replaced); verify widget tests: overlapping timer tick starts no second `fetchConsumerGroups`, cluster switch discards late results
- [x] 5.3 Replace row-triggered loading from `itemBuilder` with eager chunked loading of all filtered groups via `fetchConsumerGroupLags` within the existing concurrency limit; filter changes enqueue newly listed, unloaded groups; verify widget test: 40 groups, only 10 visible, all 40 get loaded and the existing concurrency-limit test still passes
- [x] 5.4 Total Lag KPI sums only known totals and shows "n of m loaded" while incomplete or "incomplete" when a group failed; sort by lag places unknown groups last in both directions; verify widget tests for both scenarios from the `consumer-lag-monitoring` spec
- [x] 5.5 Keep per-group error text (`_groupErrors`): `GroupLagBadge` shows localised error label with the reason as tooltip and semantic label; group details show the reason and a retry action that re-queries only that group; group lag "unknown" and "no committed offsets" states rendered with text, not colour alone; verify widget tests for failed-group badge tooltip and retry
- [x] 5.6 `topic_partition_table.dart`: render `NoCommit` as "no commit" and `Unknown` as "unknown" with reason tooltip instead of lag/committed values, disable "view message at offset" for them; verify widget test with one row of each status
- [x] 5.7 `group_details_view.dart`: hide the unassigned chip and show "partition ownership unknown" when `ownershipKnown` is false; keep the member empty state for member-less groups; verify widget tests for undecodable-assignment and empty-group scenarios of `consumer-group-member-insights`

## 6. Localization

- [x] 6.1 Add en (`lib/l10n/app_en.arb`, template) and de (`lib/l10n/app_de.arb`) keys for: lag unknown, no commit, no committed offsets, n of m loaded, total incomplete, lag error label and tooltip, retry, refresh in progress, partition ownership unknown, topic not readable; use them in 5.x with no hard-coded strings in new code; verify `flutter gen-l10n` (or build) succeeds and `grep` finds every new key in both files

## 7. Verification

- [x] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no new warnings), `cargo test --workspace` — all pass
- [ ] 7.2 `flutter_rust_bridge_codegen generate` and `dart run build_runner build` produce no further diff; `flutter analyze` clean; `flutter test` passes
- [x] 7.3 `scripts/check_read_only.sh` passes unchanged (script not modified; it includes the native-call row from `harden-read-only-gate`)
- [ ] 7.4 Manual check against the 1.1 fixture in the running app: `lag-spike-g` (Empty) shows correct per-partition lag, the uncommitted partition as "no commit", no "partitions without owner"; with the group's committed-offset read made to fail (e.g. broker stopped mid-cycle) the group shows "unknown" with reason, never 0; `kafka-consumer-groups --describe --members` still shows no members afterwards; record results in `spike.md`

## Workflow follow-up

- Delete throw-away spike prototypes; keep only `spike.md` as evidence.
- Archive the change after review; `consumer-lag-insights` (§5.38) can start afterwards.
