# Tasks

## 1. Spikes and prerequisites

- [x] 1.1 Spike (throwaway `#[ignore]` test in `kafkalyzer-kafka`, docker-compose broker `localhost:9094`): call
  `describe_configs` for an existing topic, a non-existent topic and an empty resource list. Record which
  `RDKafkaErrorCode` or request error each returns, and whether `source`/`is_default` are populated on cp-kafka 7.6.
  Write the observed codes into design.md D2 (mapping table). Verify: the notes are in design.md, and the throwaway
  test is deleted or kept as `#[ignore]` with a reason.
- [x] 1.2 Check whether 5.33 `topic-list-scale-and-organisation` has already added `describe_topic_configs` and the
  `kafkalyzer_core::topic_config` types. If it has, adapt type names in the following tasks and skip 2.1/3.1 parts
  that already exist. Verify: a note in design.md D2 states "reused from 5.33" or "created here".

## 2. kafkalyzer-core: config types and diff

- [x] 2.1 Add `rust/kafkalyzer-core/src/topic_config.rs` (register in `lib.rs`) with `TopicConfigSource`,
  `TopicConfigEntry`, `TopicConfigUnavailable` (serde derives, no rdkafka/network) as in design D2. Verify:
  `cargo build -p kafkalyzer-core`.
- [x] 2.2 Implement `diff_topic_configs(left: Option<&[TopicConfigEntry]>, right: Option<&[TopicConfigEntry]>) ->
  TopicConfigDiff` with `ConfigDiffStatus`, `ConfigDiffRow { non_default }` and `difference_count: Option<u32>`
  per design D3. Verify: `cargo test -p kafkalyzer-core topic_config` passes unit tests for name-sorted union order,
  equal, different, only-left, only-right, same-value-different-source → equal with `non_default`, sensitive on one
  or both sides → not comparable and not counted, one side `None` → `Unknown` rows and `difference_count == None`,
  both `None` → empty, `Some(None)` vs `Some("")` values are different, and duplicate names are first-wins.

## 3. kafkalyzer-kafka: describe_topic_configs

- [x] 3.1 In `kafka_metadata.rs`, add pure helpers `map_config_entry(ConfigEntry) -> TopicConfigEntry` (sensitive →
  `value: None`, `is_read_only` dropped, `ConfigSource` → `TopicConfigSource`) and
  `classify_config_error(RDKafkaErrorCode) -> TopicConfigUnavailable` using the spike 1.1 codes. Verify: unit tests
  show a sensitive entry has no value, every `ConfigSource` maps 1:1, authorization codes → `NotAuthorized`,
  unknown-topic codes → `TopicNotFound`, and other codes → `Failed` with the code text.
- [x] 3.2 Implement `describe_topic_configs(profile: &ClusterProfile, topics: &[String]) -> Vec<TopicConfigs>`
  per design D2: `create_config`, chunks ≤ 100, `shared_runtime().block_on`, 10 s request/operation timeout, one
  result per requested topic in request order, request-level errors → `Failed(msg)` for each topic, missing topic in
  response → `Failed`, entries sorted by name, `log::warn!` without values. Verify: unit test for result assembly
  (order, missing topic, request error fan-out) via a pure assembly helper, plus an `#[ignore]` integration test
  against `localhost:9094` that reads an existing topic (has `cleanup.policy` with source) and a missing topic
  (`TopicNotFound`). Run `cargo test -p kafkalyzer-kafka`.
- [x] 3.3 Confirm no mutating admin call was introduced. Verify: `scripts/check_read_only.sh` passes unchanged.

## 4. Bridge API and code generation

- [x] 4.1 Add `rust/src/api/topic_config.rs` (register in `api/mod.rs`) with DTOs `TopicConfigSource`,
  `TopicConfigEntry`, `TopicConfigAvailability`, `TopicConfigSnapshot`, `TopicConfigDiffStatus`,
  `TopicConfigDiffRow`, `TopicConfigDiff` and domain↔DTO mappings. Add `fetch_topic_config(profile, topic) ->
  TopicConfigSnapshot` (no `Result`) and `#[frb(sync)] diff_topic_configs(left, right) -> TopicConfigDiff` per
  design D4. Existing bridge functions stay unchanged. Verify: bridge unit tests show a non-`Available` snapshot
  becomes an unreadable side, sensitive entries keep `value == None`, and `Failed` carries `error_message`.
  `cargo test` passes in `rust/`.
- [x] 4.2 Run `flutter_rust_bridge_codegen generate` and then `dart run build_runner build` to regenerate
  `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart`. Verify: `flutter analyze` reports no new errors,
  and the generated `lib/src/rust/api/topic_config.dart` exposes `fetchTopicConfig` and `diffTopicConfigs`.

## 5. Dart: service and controller

- [x] 5.1 Add `lib/src/services/topic_config_service.dart` (wraps `fetchTopicConfig`/`diffTopicConfigs`) and register
  it as a lazy singleton in `lib/src/dependency_injection.dart`. Verify: `flutter analyze`. Existing
  `KafkaMetadataService` fakes still compile (`flutter test test/src/features/topic`).
- [x] 5.2 Add `lib/src/features/topic/presentation/controllers/topic_config_controller.dart` per design D5: per-side
  loading/loaded state, request tokens, dispose guard, parallel loading, diff recompute only when both sides are
  loaded, single-side retry, `nonDefaultOnly` toggle, `startComparison(profile, topic)` / `closeComparison()`. Verify:
  controller tests with a fake service cover: stale result ignored after refresh, result after dispose ignored, one
  side `NotAuthorized` gives `difference_count == null`, retrying the failed side does not re-read the other side,
  and toggling does not call the service.

## 6. Dart: UI, copy text, localization

- [x] 6.1 Add en+de ARB keys (mode label, toolbar labels/tooltips, both toggle labels, column headers, six source
  labels, status labels, placeholders "no value"/"hidden (sensitive)"/"unknown", the three unreadable texts incl.
  "Not readable — missing DescribeConfigs permission?", empty-filter messages, "no configuration entries reported",
  compare dialog texts, copy confirmation) to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, then regenerate
  localizations. Verify: `flutter test test/l10n` (ARB consistency) passes.
- [x] 6.2 Add `lib/src/features/topic/domain/topic_config_text.dart` with `formatTopicConfigText` per design D7.
  Verify: unit tests for single view, filtered comparison (only visible rows, header with both profile/topic names),
  sensitive placeholder, and an unreadable side reason with unknown values.
- [x] 6.3 Add `lib/src/features/topic/presentation/widgets/config/topic_config_view.dart` (toolbar, side headers with
  `EnvironmentTagChip`/`InsecureTlsBadge`, virtualized table, status icon+text, placeholders, unreadable states with
  retry, empty-filter messages, copy via `Clipboard` + SnackBar) using `package:material_ui/material_ui.dart`.
  Verify: widget tests cover loading indicator, rows in name order, sensitive placeholder shown and value absent,
  unknown source label, the non-default toggle, the "not readable — missing DescribeConfigs permission?" state with
  retry, a comparison with one unreadable side showing unknown and no difference count, the differences filter
  hiding equal-default rows and keeping equal-override rows, and the insecure badge on a disabled-TLS side.
- [x] 6.4 Add `lib/src/features/topic/presentation/widgets/config/topic_config_compare_dialog.dart` (profile
  `DropdownMenu` from `ClusterListController.clusters` with environment tag and insecure badge, topic `Autocomplete`
  prefilled with the open topic and fed only from already cached `TopicController.getTopics`). Verify: widget test
  shows the same-name default, the cached-only suggestions (no `fetchTopics` call on the fake), and the insecure
  badge for a disabled-TLS profile.
- [x] 6.5 Extend `TopicViewMode` with `config` in `lib/src/features/topic/topic_detail_view.dart`, add the third
  `_TopicModeButton`, create the controller lazily on first selection and dispose it with the view. Verify:
  `test/src/features/topic/topic_detail_view_test.dart` gains a case where switching to Configuration calls the fake
  service once with the tab's profile and topic, and switching back and forth does not re-read. Existing topic detail
  tests still pass.
- [x] 6.6 Verify the new widgets pass the hard-coded string guard without new allowlist entries: run
  `flutter test test/l10n/hardcoded_strings_guard_test.dart`.

## 7. Final verification

- [x] 7.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` (no new warnings),
  `cargo test --workspace`. All pass.
- [x] 7.2 `dart format lib test`, `flutter analyze` (no new issues), `flutter test`. All pass (topic/explorer/l10n/a11y suites pass; pre-existing Flutter 3.47+ `material_ui` vs `flutter/material.dart` errors exist in unrelated `theme.dart` / `app_localizations.dart`).
- [x] 7.3 `scripts/check_read_only.sh` passes unchanged (no new exception).
- [x] 7.4 Manual check against docker-compose: open a topic → Configuration lists entries with sources. Compare the
  same topic with the second docker cluster profile (or the same profile and another topic). The differences toggle
  and copy as text work. A non-existent topic name shows "Topic not found" on that side, and the active connection
  and its tabs are unchanged.
