# Tasks

## 1. Rust core (`kafkalyzer-core`)

- [x] 1.1 Add `HourBucket`, `FieldValueFilter`, `TopicAnalysisOptions`, `ValueFilterResult` to `kafka_types.rs`; extend `TopicAnalysisReport` (`hourly_timeline`, `scan_reference_time_ms`, `complete_from_ms`, `timeline_outside_count`, `value_filter_result`), `FieldOccurrence.values_capped`, `FieldValueOccurrence.truncated`, all with `#[serde(default)]`; verify with a unit test that a JSON report without the new keys deserializes and `cargo test -p kafkalyzer-core` passes
- [x] 1.2 In `json_path.rs` add public `FieldPath` (parse once, `lookup(&Value) -> Option<&Value>`) and `render_for_statistics` (null → `"null"`, objects/arrays → `None`), leaving `resolve`/`resolve_value` unchanged; verify with unit tests for dot, bracket, `$.`, JSON Pointer, present-null vs. absent, and that existing `json_path` tests still pass
- [x] 1.3 Add a canonical path builder for nested segments (dot form for safe segments, JSON Pointer with `~0`/`~1` escaping otherwise); verify with unit tests that every built path resolves to the original value via `FieldPath::lookup`
- [x] 1.4 Confirm `report_compare` still compiles and its tests pass with the extended report (`cargo test -p kafkalyzer-core`), without functional changes

## 2. Rust analyzer (`kafkalyzer-kafka`)

- [x] 2.1 Add hourly timeline recording to `AnalyzerAccumulator` (epoch-hour map, range check against `scan_reference_time_ms` ±366 d/+1 d, `timeline_outside_count`), merge and `to_report` (sorted buckets); verify with unit tests for two days at the same hour-of-day, timestamp ≤ 0, out-of-range timestamps and merge of two accumulators
- [x] 2.2 Add coverage tracking (`sampled_partitions`, per-partition `earliest_timestamp_ms`, `complete_from_ms` = max over sampled partitions); verify with unit tests for full scan (`None`), one sampled partition and a sampled partition without messages
- [x] 2.3 Replace top-level field loop with the recursive visitor (depth 5, arrays not descended, canonical paths via 1.3), `capped_value_fields` → `values_capped`, char-boundary-safe truncation with `truncated` flag, report Top 100 fields; verify with unit tests for nested object/map, pointer-form key, depth limit, array field, capped field, multi-byte string > 80 chars, and that existing accumulator tests still pass
- [x] 2.4 Add `ValueFilterAccumulator` (messages with field, matches, matched timeline) evaluated on the already parsed `Value` with a pre-compiled `FieldPath`, merged and emitted as `value_filter_result`; verify with unit tests for string/number/bool/null matches, case mismatch, absent field, tombstone, non-JSON payload and merge
- [x] 2.5 Change internal `analyze_topic_content` to take `TopicAnalysisOptions`: capture `scan_reference_time_ms` at start, mark sampled partitions, parse the filter once before the poll loops (error progress for an invalid path), pass it by reference to workers and main loop; verify `cargo build` and `cargo test -p kafkalyzer-kafka` pass and `cargo clippy` reports no new warnings
- [ ] 2.6 Measure throughput on a topic with ≥100k JSON messages before/after (with and without filter) and record msgs/s in the PR description; verify regression is < 10 %

## 3. Bridge (`rust_lib_kafkalyzer`) and code generation

- [x] 3.1 Mirror the new/extended types in `rust/src/api/kafka_types.rs` with `From` conversions in both directions where needed; verify `cargo build` of the bridge crate succeeds
- [x] 3.2 Add `analyze_topic_content_with_options(profile, topic, options, sink)` in `rust/src/api/kafka_analyzer.rs` and make the existing `analyze_topic_content` delegate with `value_filter: None` (signature unchanged); verify `cargo test` for the workspace passes
- [x] 3.3 Run `flutter_rust_bridge_codegen generate`, then `cargo fmt` and `dart format`; update all Dart constructions of `TopicAnalysisReport`, `FieldOccurrence`, `FieldValueOccurrence` (lib + tests) for the new required fields; verify `flutter analyze` reports no errors and the existing analysis tests pass (`flutter test test/src/features/topic`)

## 4. Dart data layer: export file v2

- [x] 4.1 Raise `TopicAnalysisReportFile.currentVersion` to 2, `supportedVersions = {1, 2}`, serialize/deserialize the new keys (timeline, scan reference, coverage, outside count, filter result, `values_capped`, `truncated`) as optional; verify with tests in `topic_analysis_report_file_test.dart` for v2 round-trip (filtered report with timeline), v1 import (`scanReferenceTimeMs == null`, empty timeline, no filter result) and rejection of version 3

## 5. Dart domain: production timeline

- [x] 5.1 Create `lib/src/features/topic/domain/production_timeline.dart` with `ProductionTimeline` (injectable `toLocal`), recent window points (count, match count, covered, current hour), baseline (same local clock hour, previous 1–7 covered days) and unusual rule (≥ 2× and ≥ +10) as named constants; verify with unit tests for the spec scenarios: 900 vs. 300 highlighted, 380 vs. 300 not, 6 vs. 2 not, no baseline, window switch 24 → 72, imported report ends at its scan moment
- [x] 5.2 Add daily grouping (local date, gap days with 0, newest first, partial coverage, match count/share) and effective coverage start; verify with unit tests using a fixed UTC+01:00 mapping (23:30Z counted for the next day), a gap day and a sampled report with partial coverage
- [x] 5.3 Add a DST test (local day with 23/25 hours) and a "timeline not available" test (`scanReferenceTimeMs == null`); verify all domain tests pass

## 6. Flutter controller

- [x] 6.1 Extend `TopicAnalysisController` with `valueFilter`, `setValueFilter`/`clearValueFilter`, last-used scope, `startAnalysis(..., valueFilter)` via `analyzeTopicContentWithOptions`, and `rescanWithFilter`; validation rejects an empty field path; verify with tests in `topic_analysis_controller_test.dart` (filter forwarded, cleared filter → no filter, rescan uses last scope, invalid path not started)

## 7. Flutter UI and localization

- [x] 7.1 Add all new user-facing strings to `app_en.arb` and `app_de.arb` (section titles, window labels, baseline/unusual/no-comparison/incomplete-hour/coverage hints, time-zone label, "not available for this report", filter dialog, validation, match card labels, drill-down, approximate, truncated, re-scan unavailable) and run `flutter gen-l10n`; verify generation succeeds and no hardcoded strings are used in the new widgets
- [x] 7.2 Implement `RecentProductionChart` (window `SegmentedButton`, bars, baseline tick, unusual highlight with glow, uncovered hours dimmed, tooltip with count/baseline/Δ %/matches, coverage hint, time-zone label, not-available notice); verify with a widget test for default 24 bars, switching to 72, highlighted unusual hour, coverage hint and not-available notice
- [x] 7.3 Implement `DailyProductionView` (weekday, date, proportional bar, count, matches/share, partial marker, constrained `ListView.builder`); verify with a widget test for row order, localized weekday, zero-count gap day and partial marker
- [x] 7.4 Implement `ValueFilterControl` (button, active chip, dialog with `Autocomplete` over report field paths and value field, validation, disabled while scanning) and `ValueFilterMatchCard`; verify with widget tests for entering a nested path, validation message, chip display, and card values for 100,000 / 40,000 / 2,500 (2.5 %, 6.25 %, remainder 97,500) and the zero-match case
- [x] 7.5 Extend `FieldValueExplorer` with `totalMessages` and `onRescanWithFilter`, per-value drill-down action and `FieldValueDrillDownDialog` (count, % of all, % with field, approximate badge, re-scan button disabled for truncated values and for imported reports of another topic); verify by extending `field_value_explorer_test.dart` and confirming existing explorer tests still pass
- [x] 7.6 Wire everything into `TopicAnalysisView` (filter control in the controls bar, match card below summary cards, timeline sections after `HourlyProductionChart`, drill-down re-scan via controller, memoized `ProductionTimeline` per report); verify with `topic_analysis_view_test.dart` cases for an unfiltered report, a filtered report and an imported v1 report, plus `flutter analyze` and `dart format --set-exit-if-changed`

## 8. Integration check

- [x] 8.1 Run `cargo fmt --check`, `cargo clippy`, `cargo test` (workspace), `flutter analyze` and `flutter test`; all green
- [ ] 8.2 Manual check against a real cluster: full scan and "last 10,000" scan of a busy topic show recent hours, baseline highlight, daily rows and coverage hint; a filtered scan on a nested map field (e.g. `attributes.region`) shows match count, shares and timeline; export → import reproduces the view; importing an old v1 file shows the not-available notices
