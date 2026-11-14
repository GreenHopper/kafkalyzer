# Tasks

## 1. Spikes

- [ ] 1.1 Spike: against the local `docker-compose.yaml` broker (topics created with the container's own
  `kafka-topics` CLI, data produced with the container's console producer, never from app code), call
  `offsets_for_times` with rdkafka 0.36.2 for: a timestamp before the first message, inside the range, after the last
  message, on an empty partition and on a compacted topic; record the returned `Offset` variant (`Offset(o)` / `End` /
  raw `-1`) and the per-element error for a partition without Describe ACL or leader. Verify: findings recorded in
  design.md D4; the `TimeBound` mapping in D3/D4 is confirmed or corrected before task 3.2 starts.
- [ ] 1.2 Spike: micro-benchmark (`cargo test --release -- --ignored` or a `benches/` example) of 8 threads inserting
  10 M random 16-byte fingerprints into (a) 16 mutex shards with the 8-byte pass-through hasher and (b) one
  per-thread `HashSet` (today). Verify: throughput of (a) within 10 % of (b), result recorded in design.md D6;
  otherwise switch to the D6 fallback before task 2.3.

## 2. kafkalyzer-core: scope planning, limits, bounded fingerprints

- [ ] 2.1 If `partition-offset-distribution` is not implemented yet: add `kafkalyzer_core::offset_distribution::
  {WatermarkRead, PartitionWatermarks}` exactly as its design D2 specifies (types only; `summarize_offsets` stays with
  that change). Verify: `cargo build -p kafkalyzer-core` succeeds; skip with a note in this file if the types exist.
- [ ] 2.2 Add `rust/kafkalyzer-core/src/analysis_scope.rs` (+ `pub mod`): `ScopeLimitFrom`, `AnalysisScope`
  (`validate()`), `TimeBound`, `TimeBounds`, `PlannedRange`, `UnreadablePartition`, `ScanPlan`, `plan_scan(...)` with
  water-filling per design D2/D3; add `#[serde(default)] scope: Option<AnalysisScope>` to `TopicAnalysisOptions` and a
  `TopicAnalysisOptions::effective_scope()` with the legacy mapping. Verify: unit tests cover every scenario of
  "Configurable Analysis Scope" (full, time range, open-ended, start after newest → empty not unreadable, subset,
  newest 4 × 2,500, 1,000/50,000 → 1,000 + 9,000, oldest 5,000, count inside time range, invalid scopes), plus empty
  topic, `low == high`, limit > total, non-`Known` watermarks → unreadable, `Failed` time bound → unreadable,
  `i64::MAX` saturation, legacy mapping (`sample_from_latest = false` → oldest); `cargo test -p kafkalyzer-core
  analysis_scope` passes.
- [ ] 2.3 Add `BoundedFingerprintSet`, `FingerprintOutcome` and the pass-through hasher to `duplicate_fingerprint.rs`
  per design D6 (16 shards, per-shard cap 114,688, atomic tracked/untracked counters). Verify: tests show `New` →
  `Seen` for a repeated fingerprint, `tracked()` never exceeds `limit()` when inserting `limit + 10,000` distinct
  values (use a test-only constructor with a small cap), overflow returns `Untracked` and counts it, concurrent inserts
  from 8 threads of the same fingerprint yield exactly one `New`; `cargo test -p kafkalyzer-core duplicate_fingerprint`
  passes.
- [ ] 2.4 Add `rust/kafkalyzer-core/src/analysis_limits.rs` with the constants, `AnalysisLimitKind` and
  `AnalysisLimit` per design D8; add to `kafka_types.rs` the additive report fields of D6/D9
  (`AnalysisScopeSummary`, `scan_scope`, `analysis_limits`, `tracked_field_count`, `complete_until_ms`, duplicate
  `estimated`/`untracked_messages`/`fingerprint_limit`/`samples_capped`), all `#[serde(default)]`. Update the report
  literals in `report_compare.rs` tests. Verify: the existing `test_report_deserialization_without_new_fields` still
  passes and a new test deserializes a report JSON without the new keys to `None`/`false`; `cargo test -p
  kafkalyzer-core` passes.

## 3. kafkalyzer-kafka: plan before assign, bounded duplicates, limits

- [ ] 3.1 If `partition-offset-distribution` is not implemented yet: add `fetch_partition_offsets(&ClusterProfile,
  &str)` to `kafka_metadata.rs` exactly as its design D3 specifies (parallel reads, deadline, error classification,
  pure helpers with tests). Verify: `cargo test -p kafkalyzer-kafka` passes; skip with a note if it exists.
- [ ] 3.2 Add `resolve_scan_plan` (design D4: `fetch_partition_offsets`, `offsets_for_times` per bound with element
  mapping from spike 1.1, unknown partition ids rejected, call failure → `Err` naming the time range) and replace the
  sequential watermark loop in `analyze_topic_content`: assign only planned ranges, pre-populate stats for planned
  partitions only, `total_messages_to_scan = planned_total`, all-unreadable → error progress, no ranges → empty report.
  Extract the `offsets_for_times` element mapping into a pure helper. Verify: helper tests for `Offset`, `End`,
  element error; `cargo test -p kafkalyzer-kafka` passes; grep shows no `unwrap_or((0, 0))` left in the analyzer.
- [ ] 3.3 Time filter and coverage: accumulator `time_window` + `excluded_by_time_range` (early return before any
  statistic, design D4), `PartitionStatsAccumulator.latest_timestamp_ms`, `complete_from_ms`/`complete_until_ms` per
  design D9 (replacing `sampled_partitions`), `scan_scope` summary in `to_report`. Verify: accumulator tests for a
  message outside the window (not counted anywhere except `excluded_by_time_range`), timestamp ≤ 0 with a window,
  `complete_until_ms` for an oldest-N plan and a time-range end, `None` for full/newest; existing
  `test_coverage_tracking` adapted and passing.
- [ ] 3.4 Switch duplicate tracking to one shared `Arc<BoundedFingerprintSet>` per scan (workers and `main_acc`),
  remove `seen_fingerprints` and `recent_previews`, count extra occurrences per sample, sum on merge, set
  `samples_capped`, fill the new `DuplicateAnalysisResult` fields (design D6). Verify: tests — 10,000 messages / 8,500
  unique / 15.0 % (spec example) still exact; identical message recorded by two accumulators sharing one set and merged
  counts as one duplicate with sample count 2; small-cap set → `estimated = true`, `untracked_messages > 0`, duplicates
  never negative; sample table overflow sets `samples_capped`; `cargo test -p kafkalyzer-kafka` passes.
- [ ] 3.5 Limits (design D8): use the core constants in `record_object_fields`/`to_report`, add `field_cap_reached`,
  `depth_limit_reached`, `tracked_field_count`, preview-truncated flag, merge with OR, emit `analysis_limits` in fixed
  order. Verify: tests — 501 distinct fields → field limit reached and `tracked_field_count = 500`; 6-level payload →
  depth limit reached; 10-level-free payload → not reached; every `AnalysisLimitKind` appears exactly once.
- [ ] 3.6 Worker sync only every 250 ms (remove the 2,000-message trigger, design D7). Verify: code review shows no
  clone of the fingerprint set or of `recent_previews` in any periodic path; existing analyzer tests pass.
- [ ] 3.7 Add `estimate_analysis_scope(profile, topic, scope)` (design D5; consumer only when a time bound is set, no
  assign/subscribe). Verify: `cargo build -p kafkalyzer-kafka` succeeds; `scripts/check_read_only.sh` passes
  unchanged.

## 4. Bridge crate and code generation

- [ ] 4.1 In `rust/src/api/kafka_types.rs` add the DTOs of design D1/D5 with `From`/`to_domain` mappings and extend
  `TopicAnalysisOptions` (`scope`), `TopicAnalysisReport` and `DuplicateAnalysisResult` additively (`#[serde(default)]`);
  keep `analyze_topic_content` and `analyze_topic_content_with_options` signatures unchanged. Update test literals in
  `rust/src/api/report_compare.rs`. Verify: `OLD_FORMAT_REPORT` tests still pass; a round-trip test maps a report with
  scope and limits to domain and back unchanged; `cargo test --workspace` passes.
- [ ] 4.2 Add `estimate_analysis_scope(profile, topic, scope) -> Result<AnalysisScopeEstimate>` to
  `rust/src/api/kafka_analyzer.rs` (async, off the UI isolate). Verify: `cargo clippy --workspace --all-targets` is
  clean.
- [ ] 4.3 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build`. Verify: `lib/src/rust/**`
  and `test/src/rust/api/rust_mocks.mocks.dart` contain `estimateAnalysisScope`, `AnalysisScope` and the new report
  fields; `flutter analyze` shows no new errors from generated code.

## 5. Dart: report file v4 and history service

- [ ] 5.1 `topic_analysis_report_file.dart`: `currentVersion = 4`, `supportedVersions = {1, 2, 3, 4}`, (de)serialize
  the new keys of design D10, skip unknown limit kinds. Verify: `test/src/features/topic/data/
  topic_analysis_report_file_test.dart` — v4 round trip with scope, limits, duplicate estimate, `complete_until_ms`;
  existing v1–v3 fixtures import with `scanScope == null`, `analysisLimits == null`, `estimated == false`; version 5 is
  rejected as unsupported.
- [ ] 5.2 Add `lib/src/services/topic_analysis_history_service.dart` per design D11 (FNV-1a directory, temp file +
  rename, name pattern filter, count cleanup, `Isolate.run` parsing, unreadable count, typed listing error,
  `clearAll`), injectable support-directory provider, registered in `dependency_injection.dart`. Verify: new
  `test/src/services/topic_analysis_history_service_test.dart` with a temp directory — save/list newest first, 11th
  save with N = 10 deletes only the oldest of that topic, other topic untouched, N = 0 saves nothing and deletes
  nothing, names `../x`, `a/b`, `a_b` stay inside the root and in different directories, foreign files and corrupt
  JSON are not deleted and counted as unreadable, envelope mismatch skipped, write failure reported, `clearAll`.
- [ ] 5.3 Settings: `IntSetting('analysis_confirm_threshold', 1000000, 1000, 1000000000000)` and
  `IntSetting('analysis_history_per_topic', 10, 0, 100)` in `settings_service.dart` (reset with the general settings),
  fields in `settings_view.dart` next to the run-history setting, and a "Delete saved analysis reports" action with
  confirmation and success/error SnackBar. Verify: `test/src/services/settings_service_test.dart` covers defaults and
  out-of-range fallback; a widget test taps the delete action and sees the confirmation and the result message.

## 6. Dart: controller, scope dialog, confirmation

- [ ] 6.1 `topic_analysis_controller.dart`: hold the bridge `AnalysisScope` (default full), `setScope`,
  `estimateScope()` with `isEstimating` and typed result/error, `startAnalysis(..., scope:)` (replacing
  `maxMessages`/`sampleFromLatest`), `rescanWithFilter` keeps the scope, save to history on `isComplete &&
  errorMessage == null` for live scans (errors exposed for a SnackBar), `listHistory()` and `openSavedReport(...)`
  behaving like import. Verify: `test/src/features/topic/presentation/controllers/` tests with mocked bridge and
  history service — scope passed to `analyzeTopicContentWithOptions`, completed scan saved once, cancelled/failed
  scan not saved, save failure surfaces an error without changing the report, opened saved report is marked imported.
- [ ] 6.2 Add `AnalysisScopeDialog` (design D12: All/Newest/Oldest, count, start/end `TimestampPickerField` parsed with
  `DateFormatUtils.parseDateTime`, partition chips, inline validation) and the "Scope: <summary>" button replacing the
  `ScanScopeOption` dropdown; remove `ScanScopeOption` and the unused `sampleLast*` ARB keys. Verify: widget tests —
  invalid range/count/no partition shows the inline message and disables apply; applying newest 10,000 on partitions
  0, 3 updates the summary button.
- [ ] 6.3 Start flow with confirmation (design D5) in `topic_analysis_view.dart`, also used by the re-scan callback of
  `KeyAndFieldDistributionView`. Verify: widget tests with a mocked estimate — below threshold starts directly; limit
  ≤ threshold skips the estimate; above threshold shows the estimate and starts only after confirm; incomplete shows
  "at least" plus unreadable partitions; error shows "size unknown"; compact topic shows the hint; cancel keeps the
  previous report; start is disabled while estimating.

## 7. Dart: report presentation, history menus, comparison, timeline

- [ ] 7.1 Scope summary card and "Analysis limits" card on the dashboard (text + icon for reached state, "not
  available for this report" when absent), "100 of 437 fields" / "further fields not tracked" in the field section,
  duplicate estimate label + untracked count and "list possibly incomplete" in `duplicate_analysis_view.dart` and the
  summary card, unreadable partitions and excluded-by-time count in the scope card. Verify: widget tests for a report
  with limits reached, a report without limits (v3), an estimated duplicate result and an exact one.
- [ ] 7.2 Import and Compare as `MenuAnchor`s listing saved reports of the current cluster+topic, "From file…", empty
  state, unreadable count and listing error (design D12). Verify: widget tests with a fake history service — selecting
  a saved report imports it (imported chip shown) or compares without a file dialog; empty and error states render
  and still offer "From file…".
- [ ] 7.3 Comparison scope labels and difference warning in `topic_report_comparison_view.dart` (design D12). Verify:
  widget tests — newest 10k vs full → warning; full vs full → no warning; side without scope → "scope not recorded"
  and "cannot be compared" warning.
- [ ] 7.4 `production_timeline.dart`: hours at/after `completeUntilMs` treated as not covered, crossing days partial,
  partition-subset note in `recent_production_chart.dart` and `daily_production_view.dart`. Verify:
  `test/src/features/topic/domain/production_timeline_test.dart` — oldest-N ending 3 days before the scan moment marks
  the whole 24 h window uncovered; 14:00–16:00 range marks before/after uncovered and the day partial; `null` keeps
  today's behaviour.
- [ ] 7.5 Add every new string to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` (with placeholders metadata) and run
  `flutter gen-l10n` if not automatic. Verify: `flutter test test/l10n/` (hardcoded-strings guard and ARB consistency)
  passes without new allowlist entries.

## 8. Final verification

- [ ] 8.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace`. Verify:
  all succeed without new warnings.
- [ ] 8.2 `dart format lib test`, `flutter analyze`, `flutter test`. Verify: no analyzer issues, all tests pass.
- [ ] 8.3 `scripts/check_read_only.sh`. Verify: passes unchanged (no new exception).
- [ ] 8.4 Manual check against the local `docker-compose.yaml` broker: full scan of a > 1 M-offset topic asks first;
  newest 1,000 of partitions 0, 2 within the last hour completes and shows the scope card; report appears in the import
  and compare menus; a topic with > 1.8 M distinct messages shows the duplicate estimate label; memory stays bounded
  (observe RSS). Verify: observations noted in the change's PR description.
