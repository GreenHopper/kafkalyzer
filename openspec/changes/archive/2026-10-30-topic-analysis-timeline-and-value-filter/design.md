# Design

## Context

See proposal.md – Why. Current state relevant to the approach:

- `AnalyzerAccumulator` (`rust/kafkalyzer-kafka/src/kafka_analyzer.rs`) is filled per message by `record_message` on up to 64 worker threads plus the main thread, merged via `merge()` every 250 ms into a snapshot and converted by `to_report()` into `TopicAnalysisReport` (`kafkalyzer-core::kafka_types`). The bridge mirrors these structs in `rust/src/api/kafka_types.rs`; the stream entry point is `rust/src/api/kafka_analyzer.rs::analyze_topic_content(profile, topic, max_messages, sample_from_latest, sink)`.
- Timestamps are only folded into `hourly_counts: [i64; 24]` (hour-of-day, UTC). No absolute time information survives into the report.
- Field statistics walk only the top-level keys of a JSON/Avro object (`field_counts` capped at 500 fields, `field_value_counts` capped at 200 values per field, report keeps Top 50 fields × Top 10 values). Values longer than 80 bytes are cut with `&s[..77]`, which can panic on a multi-byte UTF-8 boundary.
- `kafkalyzer-core::json_path` is the canonical path grammar (dot, bracket, `$.`, JSON Pointer) shared by projected columns, scripts and the broker-side filter. It renders `null` as `None`, which cannot distinguish "field is null" from "field is absent".
- Flutter side: `TopicAnalysisController` (ChangeNotifier) owns the stream and the report; `TopicAnalysisView` composes `TopicAnalysisSummaryCards`, `HourlyProductionChart`, `PartitionBalanceView`, `KeyAndFieldDistributionView` (contains `FieldValueExplorer`). `TopicAnalysisReportFile` (format version 1) serializes the report for export/import.
- Sampling scopes read the last `N / partitions` messages per partition, so the covered time range differs per partition.

## Goals / Non-Goals

**Goals:**

- One compact time representation in the report (absolute hour buckets) from which recent-hours window, baseline and daily distribution are derived in Dart, so the window can be switched and imported reports can be re-rendered without rescanning.
- Filter evaluation and nested field flattening in the existing single pass, without extra JSON parsing and without per-message allocations beyond what the field statistics already do.
- Full backwards compatibility of the existing bridge function, existing report consumers (comparison) and v1 export files.

**Non-Goals:**

- Multiple filter conditions, boolean combinations, operators other than exact equality, filtering on message keys or headers.
- Descending into arrays (`items[*].sku`) for statistics or filtering by wildcard.
- Configurable anomaly thresholds or alerting.
- Extending the report comparison with timeline or filter deltas.
- Changing the existing 24h hour-of-day chart.

## Decisions

### D1 – Absolute hour buckets in the report, derived views in Dart

The accumulator gains `hourly_timeline: HashMap<i64, i64>` keyed by epoch hour (`timestamp_ms.div_euclid(3_600_000)`). `to_report()` emits it as `Vec<HourBucket { epoch_hour, count }>` sorted ascending. The recent window, the baseline and the per-day grouping are computed in Dart from this list.

- *Why:* the window must be switchable after the scan and imported reports must render the same way; local time zone handling is a presentation concern and Dart's `DateTime` already knows the local zone including DST.
- *Alternative:* compute fixed "last 72 h" and "per day" vectors in Rust → requires passing a time zone/offset into Rust, fixes the window at scan time and duplicates data. Rejected.
- *Alternative:* store per-minute or per-15-minute buckets → 4–60× more entries for marginal benefit. Rejected (see half-hour time zone trade-off below).

### D2 – Bounded timeline range relative to the scan moment

`scan_reference_time_ms` is captured once at scan start (before watermarks are fetched; messages beyond the start high-watermark are not read anyway). Only hours within `[ref − 366 days, ref + 1 day]` are recorded (≤ 8,808 buckets); other timestamps increase `timeline_outside_count`. The bound is decided per message by a range check, so the map size is deterministic regardless of merge order.

- *Alternative:* cap the number of map entries → which buckets survive would depend on worker merge order. Rejected.

### D3 – Coverage start computed from sampled partitions

Before the scan, partitions whose start offset is greater than their low watermark are marked as *sampled* (`sampled_partitions: HashSet<i32>` set on the base accumulator, carried into snapshots by clone). `PartitionStatsAccumulator` gains `earliest_timestamp_ms`. `to_report()` sets `complete_from_ms = max(earliest_timestamp_ms of sampled partitions that delivered messages)`; `None` when no partition was sampled (full scan).

In Dart the *effective coverage start* is `max(complete_from_ms, start of the first timeline bucket)`: hours before the first retained message are "not covered" rather than "zero". This value drives the partial-coverage marking and excludes uncovered days from the baseline.

- *Alternative:* use the global earliest timestamp only → hides that a sparse partition reaches back days while a busy one only covers minutes. Rejected.

### D4 – Local time mapping, baseline and anomaly rule (Dart domain)

A new pure file `lib/src/features/topic/domain/production_timeline.dart` provides `ProductionTimeline` built from a report with an injectable `DateTime Function(int epochMs) toLocal` (default `DateTime.fromMillisecondsSinceEpoch`), so tests can run with a fixed offset.

- **Recent window:** the last `windowHours` epoch hours ending with the hour containing `scan_reference_time_ms`; each point carries local start time, count, optional match count, `isCovered`, `isCurrentHour`.
- **Baseline:** for each point, look up the same *local clock hour* on the previous 1…7 local days (via `DateTime(y, m, d − k, hour)` → epoch hour), use only candidates that are fully covered, and average them. No candidate → `baseline = null`.
- **Unusual:** `count >= 2 × baseline && count − baseline >= 10` (constants in the domain file). The current, still running hour is evaluated with the same rule (an already doubled partial hour is a real signal) and labelled as incomplete.
- **Days:** group buckets by the local date of the bucket start, fill gaps between first and last covered day with 0, newest first; a day is *partially covered* when the effective coverage start lies after its local midnight.

### D5 – Pre-compiled filter path and "present vs. null" lookup

`kafkalyzer-core::json_path` gets a public `FieldPath` (tokenized once via the existing `tokenize`) with `lookup(&Value) -> Option<&Value>` and a shared `render_for_statistics(&Value) -> Option<String>` used by both the field statistics and the filter (null → `"null"`, string unquoted, number/bool literal, objects/arrays → `None`, i.e. not matchable). `resolve_value` keeps its current behaviour.

The filter is passed as `Option<FieldValueFilter { field_path, value }>`; `analyze_topic_content` parses it into a `FieldPath` **once before the poll loops** (project rule: no per-message compilation) and hands a reference to each worker. `record_message` evaluates it on the already decoded/parsed `Value` (no second parse). A `ValueFilterAccumulator { messages_with_field, matched_messages, matched_timeline: HashMap<i64, i64> }` lives as `Option` inside `AnalyzerAccumulator` and is merged like the other counters.

An empty or untokenizable path is rejected in Dart before the scan; Rust additionally returns an error progress (`error_message`) instead of scanning without filter.

### D6 – Nested field flattening

`record_message` replaces the top-level loop with a recursive visitor (max depth 5, arrays counted for presence but not descended). Paths are built in canonical syntax: dot-joined when every segment is "safe" (non-empty, none of `.`, `/`, `[`, `]`, `~`), otherwise JSON Pointer (`/a/b~1c`) so the reported path resolves identically in the filter and in projected columns. Top-level safe names stay unchanged, keeping existing reports and comparisons stable.

Caps stay as they are (500 fields, 200 values per field) to bound memory and clone cost; the report keeps the Top 100 fields (was 50) because nesting yields more paths. When a new value is dropped because of the 200-value cap, the field is added to `capped_value_fields: HashSet<String>` → `FieldOccurrence.values_capped`. String values are shortened at a char boundary (`chars().take(77)` + `...`) and flagged via `FieldValueOccurrence.truncated`.

- *Alternative:* raise the field cap to 2,000 → map-heavy payloads (UUID keys) would multiply memory and the existing 100 ms worker snapshot clone. Rejected for now.

### D7 – Bridge API: additive function and structs

New bridge function `analyze_topic_content_with_options(profile, topic, options: TopicAnalysisOptions, sink)` with `TopicAnalysisOptions { max_messages, sample_from_latest, value_filter: Option<FieldValueFilter> }`. The existing `analyze_topic_content` keeps its signature and delegates with `value_filter: None`. The internal `kafkalyzer_kafka::kafka_analyzer::analyze_topic_content` takes the core `TopicAnalysisOptions` (internal API, not bridge-facing).

New/extended types in core **and** mirrored in `rust/src/api/kafka_types.rs` with `From` mappings (orphan rule):

| Type | Change |
|---|---|
| `HourBucket { epoch_hour: i64, count: i64 }` | new |
| `FieldValueFilter { field_path: String, value: String }` | new |
| `TopicAnalysisOptions` | new |
| `ValueFilterResult { field_path, value, messages_with_field, matched_messages, matched_timeline: Vec<HourBucket> }` | new |
| `TopicAnalysisReport` | `+ hourly_timeline`, `+ scan_reference_time_ms: Option<i64>`, `+ complete_from_ms: Option<i64>`, `+ timeline_outside_count`, `+ value_filter_result: Option<ValueFilterResult>` (all `#[serde(default)]`) |
| `FieldOccurrence` | `+ values_capped: bool` |
| `FieldValueOccurrence` | `+ truncated: bool` |

`scan_reference_time_ms == None` is the single "timeline not available" signal (v1 files, reports from older code paths).

### D8 – Export file format version 2

`TopicAnalysisReportFile.currentVersion = 2`, `supportedVersions = {1, 2}`. New snake_case keys mirror D7. The reader treats every new key as optional, so v1 files map to `scanReferenceTimeMs = null`, empty timeline, no filter result, `valuesCapped/truncated = false`. Files written by v2 are rejected by older app versions with the existing "unsupported version" message – acceptable and already specified behaviour.

### D9 – Flutter state and widgets

- `TopicAnalysisController`: `FieldValueFilter? valueFilter`, `setValueFilter()/clearValueFilter()`, `startAnalysis(..., valueFilter)` now calls `analyzeTopicContentWithOptions`; `rescanWithFilter(FieldValueFilter)` sets the filter and restarts with the last scope. Partial reports keep flowing through the existing 250 ms throttle, no extra notifications.
- The recent-window size is ephemeral view state → `ValueNotifier<int>` in the timeline widget, not in the controller.
- New widgets under `presentation/widgets/analysis/` (all `package:material_ui/material_ui.dart`, all strings via `AppLocalizations`):
  - `RecentProductionChart` – `SegmentedButton` for 6/12/24/48/72 h, bars with baseline tick, highlight colour for unusual hours, hatched/dimmed uncovered hours, tooltip with count/baseline/Δ%/matches, coverage hint, time-zone label.
  - `DailyProductionView` – rows "weekday, date, bar, count (+ matches, share)" in a height-constrained `ListView.builder` (up to 367 rows), partial-coverage marker.
  - `ValueFilterControl` – button + active-filter chip in the controls bar; dialog with `Autocomplete` over discovered field paths and a value field; disabled while scanning.
  - `ValueFilterMatchCard` – path = value, matches, % of all, % of messages with field, remainder; placed directly below the summary cards.
  - `FieldValueExplorer` – adds a drill-down action per value opening `FieldValueDrillDownDialog` (count, % of all scanned = `count / totalMessages`, % with field = existing percentage, approximate badge, "re-scan with this filter" button; disabled for truncated values and for imported reports of another topic). The explorer receives `totalMessages` and an optional `onRescanWithFilter` callback – both additive constructor parameters.
- `TopicAnalysisView` inserts the new sections after `HourlyProductionChart`; existing sections are untouched.
- Timeline computations run in `ProductionTimeline` (≤ 8.8k buckets, O(n) map lookup) and are memoized per report instance in the widget state, never in `build()` per frame.

## Risks / Trade-offs

- [Throughput regression from recursive flattening and filter evaluation in the hot loop] → depth limit 5, pre-compiled path, no extra parse, reuse of the parsed `Value`; measure msgs/s on a ≥100k-message topic before/after, target < 10 % regression.
- [Larger accumulator clones (worker snapshot every 100 ms, merge every 250 ms)] → timeline ≤ 8.8k entries, unchanged field/value caps; matched timeline only exists when a filter is set.
- [Half-hour/45-minute time zones (e.g. UTC+05:30)] → hour buckets are UTC-aligned, so local hour labels and day boundaries are shifted by the fractional offset; documented limitation, labels show the real local start time of each bucket.
- [DST transitions] → window built from absolute epoch hours (a DST day shows 23/25 bars with correct labels); baseline uses the same local clock hour, so a DST switch inside the 7-day baseline skips a missing hour instead of comparing wrong hours.
- [Producer-set CreateTime timestamps can be wrong or skewed] → outside-range messages are counted and shown; the timeline reflects message timestamps, not broker arrival, which is stated in the tooltip/hint.
- [Values longer than 80 characters cannot be drilled down exactly] → re-scan disabled with explanation; user can type the full value in the filter dialog.
- [Adding fields to FRB structs changes generated Dart constructors] → all Dart constructions of `TopicAnalysisReport`, `FieldOccurrence`, `FieldValueOccurrence` (report file reader, tests, comparison tests) must be updated in the same step as the bridge regeneration.
- [Top-level keys containing `.` change from plain name to JSON Pointer form] → only affects such unusual keys; comparison with older reports lists them as removed/added once. Accepted.

## Migration Plan

- No persisted state besides export files. v1 files stay importable (D8). Rollback = revert; v2 files would then be rejected by the old version with the existing unsupported-version message.
- Order: core types + json_path → accumulator + analyzer → bridge types/function → `flutter_rust_bridge_codegen generate` → Dart report file v2 → domain timeline → controller → widgets → l10n.

## Open Questions

- Whether the anomaly thresholds (2×, +10 messages) should later become user-configurable; the constants are isolated in the domain file so this can be added without changing the approach.
