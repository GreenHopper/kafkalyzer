# Proposal: analysis-scope-and-history

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.37 (Phase 2a), finding B11 (§2.4), decision E20
(§3). Effort class M (roadmap estimate).

## Why

The scope of a topic analysis is limited to four fixed presets (full scan, newest 10k/50k/100k), so a user cannot
analyse "yesterday 14:00–16:00", "only partition 3" or "the oldest 5,000 messages". A full scan of a large topic
starts without warning. Duplicate detection keeps every fingerprint in an unbounded set that is copied every 100 ms
and merged every 250 ms, which breaks the existing `topic-duplicate-detection` requirement "Bounded Memory Tracking"
(B11). Finished reports are lost unless the user exports them by hand, and several internal caps (500 fields,
200 values per field, depth 5, 10,000 keys, 1,000 duplicate samples) silently shape a report without being shown.

## What Changes

- **Free analysis scope**: time range (start and/or end timestamp, resolved to offsets with the broker's timestamp
  index before `assign`), partition subset, and a free message count taken from the newest or the oldest end. The
  options can be combined (for example newest 10,000 within the last 24 hours). Full scan stays the default (E20).
- **Confirmation before large scans**: when the estimated scope (from the offset span, labelled as an estimate)
  exceeds a threshold, or when the size cannot be estimated, a dialog shows the estimate and asks before starting.
  The threshold is a setting (default 1,000,000 offsets).
- **Scope recorded in the report**: requested scope, planned offset range per partition, partitions that could not be
  read, and messages excluded by the time range. Partitions whose watermarks cannot be read are reported as not
  readable instead of being scanned as empty (today `unwrap_or((0, 0))`).
- **Bounded duplicate tracking**: the fingerprint set gets a fixed cap and is shared by all scan workers, so it is
  never copied in periodic snapshots. When the cap is reached, duplicate figures are marked as estimated (lower
  bound). Restores the existing spec.
- **All internal caps disclosed** in the report and on the dashboard, with whether each one was reached.
- **Local report history**: every completed live scan is saved automatically in the application support directory,
  per cluster and topic; only the newest N are kept (setting, default 10, 0 = off). Saved reports are offered in
  Import and Compare. A settings action deletes all saved reports.
- **Timeline coverage end**: a scan that stops before the log end (oldest N, time range with an end) marks the hours
  after its coverage end as not covered instead of showing them as zero.
- **Comparison shows both scopes** and warns when they differ.
- **Report file format version 4**; versions 1–3 stay importable (new sections shown as not available).
- Fix (no delta, existing behaviour intent): `sample_from_latest = false` with a message limit currently scans the
  whole topic; it now means "oldest N".

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `topic-content-analysis`: adds configurable scope, confirmation above a threshold, scope recorded in the report,
  disclosure of internal analysis limits.
- `topic-duplicate-detection`: "Bounded Memory Tracking" gets a fixed fingerprint cap and an "estimated" marker.
- `topic-analysis-export-import`: file content gains scope and limits; previous versions stay importable; automatic
  local history with count-based cleanup, offered in Import.
- `topic-report-comparison`: second report can come from the history; scopes of both sides shown, difference warned.
  (Not listed in the roadmap; needed because the roadmap requires history in "Compare" and comparing a 10k sample
  with a full scan is otherwise misleading.)
- `topic-production-timeline`: coverage indication also covers a coverage end and partition subsets. (Not listed in
  the roadmap; needed because "oldest N" and time ranges would otherwise show uncovered hours as zero volume.)

`topic-analysis-value-filter` is unchanged: its "Re-Scan With Selected Value" already demands the current scope; the
re-scan now passes the full new scope.

## Read-only impact

No new kind of Kafka or Schema Registry call; no gate exception. Added read-only calls:

- `BaseConsumer::fetch_watermarks` per partition through `fetch_partition_offsets` (owned by
  `partition-offset-distribution`) — once for the pre-scan estimate and once at analysis start (replaces the
  analyzer's own sequential loop).
- `BaseConsumer::offsets_for_times` (ListOffsets) for start/end timestamps — in the estimate and at analysis start,
  only when a time range is set. Already used by message consumption.
- `fetch_metadata(Some(topic))` in the estimate call.

Consumers keep manual `assign()`, `enable.auto.commit=false`; no Schema Registry calls are added.
`scripts/check_read_only.sh` must pass unchanged.

## Prerequisites

- `partition-offset-distribution` (5.11) provides `kafkalyzer_kafka::kafka_metadata::fetch_partition_offsets` and the
  core types `WatermarkRead` / `PartitionWatermarks`. If it is not implemented first, this change implements exactly
  those two pieces as specified in its design (D2/D3), without its UI.
- `accessibility-and-l10n-sweep` (in progress): new strings must pass `test/l10n/hardcoded_strings_guard_test.dart`
  and `arb_consistency_test.dart`, which already exist in the tree.

## Non-goals

- Resuming a cancelled or failed scan (roadmap §5.37, §7).
- Message-exact scope counts before the scan (offset spans are estimates on compacted/transactional topics).
- Time-ordered "newest N across partitions" (the count is split across partitions by offset span, not by timestamp).
- Syncing or sharing the history between machines; history for deleted or renamed profiles is not migrated.
- Saving cancelled (partial) scans to the history automatically.
- Changing the presentation of caps that already exist (per-field "approximate", distinct keys "lower bound",
  percentiles "estimated") beyond listing them in the new limits section.
- Replacing the live partial-report stream with counter-only progress (see design, open question on
  "Decoupled Progress Reporting").

## Impact

- Rust: `kafkalyzer-core` (`analysis_scope.rs` new: scope types and range planning; `duplicate_fingerprint.rs`:
  bounded shared set; `kafka_types.rs`: additive fields), `kafkalyzer-kafka` (`kafka_analyzer.rs`: plan before
  `assign`, time-range filter, shared fingerprint set, limit tracking; new `estimate_analysis_scope`), bridge
  (`rust/src/api/kafka_types.rs`, `rust/src/api/kafka_analyzer.rs`: additive DTOs and one new function). Existing
  bridge signatures stay unchanged.
- Dart: `topic_analysis_view.dart` (scope panel, confirmation dialog, history menus, limits section),
  `topic_analysis_controller.dart`, `topic_analysis_report_file.dart` (v4), new `TopicAnalysisHistoryService`,
  `topic_report_comparison_view.dart`, `duplicate_analysis_view.dart`, `production_timeline.dart`,
  `settings_service.dart` / `settings_view.dart` (two `IntSetting`s, clear-history action), en + de ARB.
- Regenerated: bridge code and `test/src/rust/api/rust_mocks.mocks.dart`.
