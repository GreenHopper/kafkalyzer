# Design: analysis-scope-and-history

## Context

See proposal.md (Why). Current code on disk, verified against the roadmap (§5.37, B11):

- **Scope**: `topic_analysis_view.dart` has `enum ScanScopeOption { full, sample10k, sample50k, sample100k }` and
  `_startScan` always passes `sampleFromLatest: true`. `TopicAnalysisOptions` (core, bridge) =
  `{max_messages, sample_from_latest, value_filter, duplicate_scope}`.
- **Analyzer setup** (`kafka_analyzer.rs::analyze_topic_content`): one sequential `fetch_watermarks(5 s)` per partition
  with `.unwrap_or((0, 0))` — an unreadable partition silently becomes an empty one (violates the "unknown is unknown"
  rule). Sample split is `max / partition_count` per partition, so small partitions waste their share and the total
  can fall short of N. With `sample_from_latest = false` the limit is ignored and the whole topic is scanned (no "oldest
  N" exists). `describe_configs` failure → "not compacted" (B9, owned by `topic-list-scale-and-organisation`, not
  changed here).
- **B11 confirmed**: `AnalyzerAccumulator.seen_fingerprints: HashSet<[u8;16]>` (line 83) is unbounded; insert at
  line 587 (roadmap said 568), merge at 373. Each worker clones its whole accumulator into a shared slot every
  100 ms **or every 2,000 messages** (lines ~1394, ~1529) — at 100k msg/s that is ~50 full clones per second per
  worker. The main thread clones the base accumulator and merges every worker's set every 250 ms and builds a full
  `partial_report`. Additionally `recent_previews` holds up to 1,000 previews of ≤ 4,000 chars per worker (≈ 4 MB per
  worker, up to 64 workers) and is cloned with it.
- **Caps** in code: 500 tracked field paths (silent), top 100 fields reported (silent), 200 values per field
  (surfaced: `values_capped`), top 10 values, depth 5 (silent), 80-char values (surfaced per value: `truncated`),
  10,000 keys (surfaced: `key_cardinality_capped`), top 20 keys, size sample 10,000 (surfaced:
  `size_percentiles_estimated`), 1,000 duplicate samples (silent), top 20 duplicates, 4,000-char preview, timeline
  window −366 d / +24 h (surfaced: `timeline_outside_count`).
- **Report file**: `TopicAnalysisReportFile` (Dart, hand-written snake_case map), `currentVersion = 3`,
  `supportedVersions = {1, 2, 3}`; lenient parsing with defaults. `TopicAnalysisExportService` does file dialogs.
- **Progress delivery**: Dart cancels by cancelling the stream subscription; the Rust side sees `sink.add` fail and
  stops. The final report after cancel is never delivered, so the "partial results at cancellation" are the last
  250 ms partial report. `topic-analysis-value-filter` requires partial results to update live.
- **Reusable pieces**: `partition-offset-distribution` (D2/D3 of its design) defines
  `kafkalyzer_core::offset_distribution::{WatermarkRead, PartitionWatermarks}` and
  `kafkalyzer_kafka::kafka_metadata::fetch_partition_offsets(&ClusterProfile, &str)` (parallel, deadline,
  NotReadable/Failed/TimedOut per partition). `IntSetting` + `_IntSettingField` in settings (precedent:
  `scripting_max_run_history`). `TimestampPickerField` + `DateFormatUtils.parseDateTime`. `writeStoreBackup` shows the
  `getApplicationSupportDirectory()` convention; `archive_safety.dart::isSafePathSegment`.
- l10n guard tests (`test/l10n/hardcoded_strings_guard_test.dart`, `arb_consistency_test.dart`) exist.

## Goals / Non-Goals

**Goals:**

- Scope planning as pure, unit-tested core logic; I/O only to obtain watermarks and timestamp offsets.
- One planning path used by both the estimate and the analysis, so the dialog and the scan agree.
- Duplicate tracking with a hard memory bound and no per-tick copying of the fingerprint set.
- Report and file format extended additively; every older file still imports.

**Non-Goals:**

- Reworking progress delivery to counter-only updates (would break the live dashboard; see Open Questions).
- Migrating the message-consumption helpers in `kafka_consumer.rs` (`initial_partition_quotas`, …) to core.
- Fixing B9 (compaction assumption on denied `describe_configs`).

## Decisions

### D1 Layering

| Layer | New / changed code | Why here |
|---|---|---|
| `kafkalyzer-core` | `analysis_scope.rs`: `AnalysisScope`, `ScopeLimitFrom`, `TimeBound`, `PlannedRange`, `ScanPlan`, `plan_scan(...)`; `analysis_limits.rs`: limit constants, `AnalysisLimitKind`, `AnalysisLimit`; `duplicate_fingerprint.rs`: `BoundedFingerprintSet`; `kafka_types.rs`: additive fields | Pure maths/data structures, testable without a broker; reused by estimate and analysis. |
| `kafkalyzer-kafka` | `kafka_analyzer.rs`: `resolve_scan_plan(profile, consumer, topic, scope)`, `estimate_analysis_scope(profile, topic, scope)`, analyzer uses the plan, time filter, shared fingerprint set, limit flags, 250 ms sync | rdkafka I/O (`fetch_partition_offsets`, `offsets_for_times`). |
| bridge | `api/kafka_types.rs`: DTOs `AnalysisScope`, `ScopeLimitFrom`, `AnalysisScopeSummary`, `PlannedPartitionRange`, `UnreadablePartition`, `AnalysisLimit(Kind)`, `AnalysisScopeEstimate`, `PartitionScopeEstimate`; additive fields on `TopicAnalysisOptions`, `TopicAnalysisReport`, `DuplicateAnalysisResult`; `api/kafka_analyzer.rs`: `estimate_analysis_scope` | frb boundary; orphan rule mapping. |
| Dart | scope dialog, confirmation, controller state, `TopicAnalysisReportFile` v4, `TopicAnalysisHistoryService`, limits section, comparison scope labels, timeline coverage end, two settings | View state, persistence of report files (the format already lives in Dart). |

Scope-difference detection for the comparison stays in Dart (one caller; rule: move to core only with a second caller).

### D2 Scope model and backward compatibility

```rust
pub enum ScopeLimitFrom { Newest, Oldest }
pub struct AnalysisScope {
    pub partitions: Option<Vec<i32>>,      // None = all
    pub start_timestamp_ms: Option<i64>,   // inclusive
    pub end_timestamp_ms: Option<i64>,     // exclusive
    pub message_limit: Option<i64>,        // offsets, split across partitions
    pub limit_from: ScopeLimitFrom,
}
// TopicAnalysisOptions gains: #[serde(default)] pub scope: Option<AnalysisScope>
```

- `scope = Some` → `max_messages`/`sample_from_latest` are ignored.
- `scope = None` → legacy mapping: `max_messages = Some(n)` → `message_limit = n`, `limit_from = Newest` if
  `sample_from_latest` else `Oldest` (fixes the "false scans everything" defect); `None` → full scan. The legacy
  bridge function `analyze_topic_content(profile, topic, max_messages, sample_from_latest)` keeps its signature.
- Validation in core (`AnalysisScope::validate`) and mirrored in Dart for inline messages: `start < end` when both set,
  `message_limit > 0`, non-empty partition list, timestamps ≥ 0. Unknown partition ids are rejected in the kafka layer
  against metadata (`"partition 7 does not exist"`). Validation errors end the stream with `error_message`, like the
  existing invalid-filter-path path.

*Alternative:* a mode enum `Full | Newest(n) | Oldest(n) | TimeRange(..)` — cannot express "newest 1,000 in the last
24 h", which the roadmap wording ("Zeitraum, Partitionsauswahl und freie Nachrichtenanzahl") allows combining.

### D3 Range planning in core

`plan_scan(watermarks: &[PartitionWatermarks], time_bounds: &HashMap<i32, TimeBounds>, scope: &AnalysisScope)
-> ScanPlan` where `TimeBounds { start: Option<TimeBound>, end: Option<TimeBound> }` and
`TimeBound = Offset(i64) | AfterEnd | Failed(String)`.

Per selected partition with `WatermarkRead::Known { low, high }`:

1. `start = low`, `end = high`.
2. Time start: `Offset(o)` → `start = max(o, low)`; `AfterEnd` → `start = high` (empty in range, *not*
   unreadable). Time end: `Offset(o)` → `end = min(o, high)`; `AfterEnd` → `end = high`. `Failed` on either →
   partition unreadable with the reason.
3. Message limit: water-filling over the remaining spans — repeatedly give every unsatisfied partition
   `floor(remaining / unsatisfied)` capped at its span, remainder to the lowest partition ids, until the budget or all
   spans are exhausted. `Newest` → `start = end − quota`; `Oldest` → `end = start + quota`. Sum of quotas =
   `min(limit, Σ span)`; arithmetic in `i128`, saturating.
4. Non-`Known` watermarks (`NotReadable`, `Failed`, `TimedOut`) → `UnreadablePartition { partition, reason }`.

`ScanPlan { ranges: Vec<PlannedRange { partition, start, end }>, unreadable: Vec<UnreadablePartition>,
planned_total: i64, complete: bool }`. `complete = unreadable.is_empty()`. Unit tests cover each scenario of the
"Configurable Analysis Scope" requirement plus: empty topic, `low == high`, limit > total, one partition, time start
inside a compaction gap, `AfterEnd` for both bounds.

*Alternative:* keep the even split (`N / P`) — under-reads whenever partitions are uneven, which is the common skewed
case; water-filling is ~20 lines and deterministic.

### D4 Plan before `assign`, time filter during the scan (kafka)

`resolve_scan_plan`:

1. `fetch_partition_offsets(profile, topic)` (5.11) → per-partition `WatermarkRead`; topic missing → `Err`.
2. If a time bound is set: one `offsets_for_times` call per bound with all selected `Known` partitions (timeout 10 s).
   Element `Offset::Offset(o)` → `Offset(o)`; `Offset::End` / `-1` → `AfterEnd`; element error → `Failed(err)`. A
   failed *call* (timeout, broker down, authorization) → `Err` naming the time range — never a fallback to offset 0
   or a full scan.
3. `plan_scan(...)`.

The analyzer replaces its watermark loop with `resolve_scan_plan`, assigns only planned partitions with
`start < end`, pre-populates partition stats only for planned partitions, and sets `total_messages_to_scan =
planned_total`. No ranges and unreadable partitions present → stream ends with an error (spec: "No partition
readable"); no ranges and nothing unreadable → empty report as today.

Time filter: the accumulator gets `time_window: Option<(Option<i64>, Option<i64>)>`; `record_message_*` returns early
(before any statistic) when the window is set and the timestamp is ≤ 0 or outside `[start, end)`, incrementing
`excluded_by_time_range`. The offset bookkeeping for completion still advances. The comparison is two integer checks —
no allocation in the hot path.

Worker termination is unchanged: `off >= end` / `last_off + 1 >= end` / `PartitionEOF`; an end offset inside a
compaction gap is handled by the existing `off >= end_off → break`.

*Spike 1.1 findings (rdkafka 0.36.2 vs cp-kafka 7.6.0):* `offsets_for_times` returned `Offset::Offset(0)` (`err=Ok(())`)
for timestamps before the first message (both normal and compacted topics), `Offset::Offset(1)` for an in-range
timestamp, `Offset::End` (`to_raw() == Some(-1)`, `err=Ok(())`) for timestamps after the last message and on an empty
partition, and `KafkaError (Metadata fetch error: UnknownPartition)` on an invalid partition id. This confirms the
`TimeBound` mapping above (`Offset(o)` → `Offset(o)`, `End`/`-1` → `AfterEnd`, element `error()` → `Failed`, call
`Err` → `Err`).

### D5 Estimate call

Bridge: `pub async fn estimate_analysis_scope(profile, topic, scope: AnalysisScope) -> Result<AnalysisScopeEstimate>`
→ kafka `estimate_analysis_scope` = create a `BaseConsumer` (only if a time bound is set, for `offsets_for_times`;
`enable.auto.commit=false`, no assign) + `resolve_scan_plan`. DTO:

```rust
pub struct AnalysisScopeEstimate {
    pub planned_total: Option<i64>,   // None unless complete
    pub known_total: i64,             // "at least" value
    pub complete: bool,
    pub unreadable: Vec<UnreadablePartition>,
}
```

Dart flow (view `_requestStart` → controller):

```text
validate scope (inline error, stop)
if scope.message_limit != null && limit <= threshold → start
else controller.estimateScope() [isEstimating = true, start disabled, progress shown]
   ok & complete & planned_total <= threshold → start
   ok otherwise (above threshold or incomplete) → confirmation dialog (estimate / "at least" + unreadable list
                                                   + compact hint from TopicMetadata.cleanupPolicy)
   error → dialog "size unknown" + error text
dialog confirm → start ; cancel → nothing changes
```

The threshold is `IntSetting('analysis_confirm_threshold', 1000000, 1000, 1000000000000)`. The estimate and the scan
resolve the plan independently; the dialog text calls the value an estimate, so drift between the two is acceptable.
`rescanWithFilter` goes through the same `_requestStart` (the view passes its own callback to
`KeyAndFieldDistributionView`).

*Alternative:* Dart calls `fetch_partition_offsets` directly and computes the estimate — impossible for time ranges
without duplicating the planning logic in Dart.

### D6 Bounded, shared fingerprint set

`kafkalyzer_core::duplicate_fingerprint::BoundedFingerprintSet`: 16 shards selected by `fp[0] & 0x0f` (uniform,
SHA-256 based), each `Mutex<HashSet<MessageFingerprint, FingerprintHasher>>` with a per-shard cap of 114,688
(= 2^17 × 7/8, the largest size that fits a 2^17-bucket hashbrown table). Total cap 1,835,008 fingerprints, worst
case ≈ 16 × 2^17 × 17 B ≈ 36 MB, independent of worker count. `FingerprintHasher` takes the first 8 bytes of the
already uniform fingerprint (no SipHash on the hot path). API:

```rust
pub enum FingerprintOutcome { New, Seen, Untracked }
impl BoundedFingerprintSet {
    pub fn insert(&self, fp: MessageFingerprint) -> FingerprintOutcome;
    pub fn tracked(&self) -> i64;        // atomic counter
    pub fn untracked(&self) -> i64;      // atomic counter
    pub fn limit(&self) -> i64;
}
```

One `Arc<BoundedFingerprintSet>` per scan is shared by all workers and the main-thread accumulator; the accumulator
holds only the `Arc` (cloning a snapshot copies a pointer). Counting:

- `New` → nothing else; `Untracked` (shard full, fp unknown) → counted as unique; `Seen` → duplicate occurrence.
- `unique = tracked + untracked`, `duplicates = total − unique`, `estimated = untracked > 0`.
- `duplicate_samples` (per worker, cap 1,000) count **extra** occurrences; merge sums them; the report shows
  `extra + 1`. The sample (preview, partition, offset, timestamp) is taken from the first *duplicate* occurrence —
  duplicates have identical content by definition, so the first-occurrence preview map `recent_previews` is removed.
  A `Seen` fingerprint that cannot get a sample slot (or is dropped on merge) sets `duplicate_samples_capped`.

Mutex contention: one short lock per message on 1 of 16 shards; benchmarked in a spike (task 1.2) against the current
per-worker set. If contention costs > 10 % throughput, fall back to per-worker bounded sets with exact merge at the end
and "not available during the scan" for live duplicate figures.

*Spike 1.2 findings (release, 8 threads × 1.25 M = 10 M random 16-byte fingerprints):* shared 16-shard
`BoundedFingerprintSet` took `1.042 s` (~9.6 M inserts/s, ~104 ns/op) vs `122.4 ms` for uncontended per-thread
`HashSet`s (without periodic clones or final 8-way merge). Because the pure in-memory tight loop differs by > 10 %,
awaiting confirmation on whether to keep the 16-shard `BoundedFingerprintSet` (negligible relative to Kafka/JSON work,
preserves live duplicate counts and 36 MB global cap) or switch to the per-worker fallback.

`DuplicateAnalysisResult` gains `#[serde(default)] estimated: bool, untracked_messages: i64, fingerprint_limit:
Option<i64>, samples_capped: bool`.

*Alternatives:* HyperLogLog for unique counts — gives no duplicate ranking and no exact small-topic result; a Bloom
filter — false positives would invent duplicates, which is worse than an under-count.

### D7 Snapshot cadence

Workers sync their local accumulator into the shared slot only when ≥ 250 ms have passed (the 2,000-message trigger is
removed); the main thread still emits every 250 ms. With the fingerprints behind an `Arc` and `recent_previews` gone,
what is cloned is bounded by the existing caps (keys 10k, fields 500 × 200, samples 1,000). This restores the
fingerprint part of "Decoupled Progress Reporting" without a spec change.

### D8 Limits

Constants move to `kafkalyzer_core::analysis_limits` (no value changes): `MAX_TRACKED_FIELDS = 500`,
`MAX_REPORTED_FIELDS = 100`, `MAX_VALUES_PER_FIELD = 200`, `MAX_LISTED_VALUES = 10`, `MAX_FIELD_DEPTH = 5`,
`MAX_VALUE_CHARS = 80`, `MAX_TRACKED_KEYS = 10_000`, `MAX_LISTED_KEYS = 20`, `SizeSample::LIMIT`,
`MAX_TRACKED_FINGERPRINTS`, `MAX_DUPLICATE_SAMPLES = 1_000`, `MAX_LISTED_DUPLICATES = 20`. New accumulator flags:
`field_cap_reached` (a new path was dropped), `depth_limit_reached` (an object at max depth had an object child),
`duplicate_samples_capped`; `tracked_field_count` for "100 of 437". `to_report` emits
`analysis_limits: Vec<AnalysisLimit { kind, limit: i64, reached: bool }>` (one entry per kind, fixed order) and
`tracked_field_count: Option<i64>`. The preview length (4,000) and timeline window are listed too (`reached` from
"any preview truncated" / `timeline_outside_count > 0`). Merge ORs the flags.

### D9 Report additions and timeline coverage end

`TopicAnalysisReport` gains (all `#[serde(default)]`, `Option` where old reports must read as "unknown"):
`scan_scope: Option<AnalysisScopeSummary { scope, ranges, unreadable, excluded_by_time_range }>`,
`analysis_limits: Option<Vec<AnalysisLimit>>`, `tracked_field_count: Option<i64>`, `complete_until_ms: Option<i64>`.

- `complete_from_ms` (existing): computed over partitions whose plan starts after `low` (replaces
  `sampled_partitions`), or the time-range start when set (whichever is later).
- `complete_until_ms` (new): over partitions whose plan ends before the high watermark at scan start, the minimum of
  their latest observed timestamp (`PartitionStatsAccumulator.latest_timestamp_ms`, new), or the time-range end when
  set (whichever is earlier). `None` for full and newest scans.
- `ProductionTimeline` (Dart) treats hours ≥ `complete_until_ms` like hours before `complete_from_ms`; days crossing
  it are partial. Partition subset: the timeline views show "covers partitions 0, 3" from `scan_scope.scope.partitions`.

### D10 Report file format v4

`currentVersion = 4`, `supportedVersions = {1, 2, 3, 4}`. New snake_case keys inside `report`: `scan_scope`,
`analysis_limits`, `tracked_field_count`, `complete_until_ms`, and in `duplicate_analysis_result`: `estimated`,
`untracked_messages`, `fingerprint_limit`, `samples_capped`. Missing keys → `null`/`false` (old reports were computed
with an unbounded set, so "not estimated" is correct for them). Unknown `AnalysisLimitKind` strings in a newer file are
skipped, not fatal. Old v1–v3 fixture files stay in the tests.

### D11 Local history

`TopicAnalysisHistoryService` (`lib/src/services/`):

- Root: `<getApplicationSupportDirectory()>/analysis_history/`. Per cluster+topic directory named by the 16-hex-digit
  FNV-1a-64 hash of UTF-8 `cluster + "\u0000" + topic` (always a safe single segment; no collision between `a/b` and
  `a_b`; checked with `isSafePathSegment`). The envelope's `clusterName` and `report.topic` are compared on read, so a
  hash collision cannot show a foreign report. FNV is ~10 lines; no `crypto` dependency.
- File name `<scanReferenceTimeMs or now>-<counter>.json`, written via `File.writeAsString` to a `.tmp` and renamed
  (no torn files). Only names matching `^\d{13}-\d+\.json$` are listed or cleaned up; anything else in the directory is
  ignored and never deleted.
- After a save: list, sort by name descending, delete beyond N (`IntSetting('analysis_history_per_topic', 10, 0,
  100)`; 0 = no save, no cleanup). Delete failures are logged and reported as a non-blocking SnackBar.
- `list(cluster, topic)` reads and parses all files in `Isolate.run` → `HistoryListing { entries (newest first),
  unreadableCount }`; listing errors throw a typed error that the menu shows inline.
- `clearAll()` deletes the root directory; partial failure → error result for the settings SnackBar.
- Trigger: the controller saves when it receives `isComplete && errorMessage == null` for a live scan (cluster name
  from the `ClusterProfile` passed to `startAnalysis`); fire-and-forget with error capture, never blocking the UI.

Privacy: reports contain key and value excerpts (top values, duplicate previews). They are stored in the per-user app
data directory, the same trust level as saved searches and script outputs; the settings offer deletion and N = 0.

### D12 Dart UI

- The scope dropdown is replaced by a "Scope: <summary>" button opening an `AnalysisScopeDialog`: segmented button
  All / Newest / Oldest, count field (default 10,000), optional start and end `TimestampPickerField`, partition
  `FilterChip`s (ids `0..partitionCount-1` from `TopicMetadata`, "All" toggle). Inline validation per D2. The
  controller stores the bridge `AnalysisScope` directly (no Dart mirror type). `ScanScopeOption` and the unused
  `sampleLast10k/50k/100k` ARB keys are removed.
- Confirmation dialog per D5; estimate progress in the controls bar.
- Import and Compare buttons become `MenuAnchor`s: saved reports of the current cluster+topic (scan moment, scope
  summary, message count), "From file…", unreadable count, error row.
- Dashboard: scope summary card under the summary cards; "Analysis limits" card (list of kind / value / reached,
  state as text + icon, not colour alone); duplicate card and section show "estimated (at least)" and untracked
  count; field section shows "100 of 437 fields" and "further fields not tracked".
- Comparison: each `_SideLabel` shows the scope summary; a warning banner when `scopeKey(a) != scopeKey(b)` or a side
  has no scope (mode, limit, start, end, sorted partitions).
- All strings via `AppLocalizations` (en + de); icon-only controls get tooltip + semantics label.

## Risks / Trade-offs

- [Shard mutex contention slows high-throughput scans] → spike 1.2 measures; fallback described in D6.
- [`offsets_for_times` semantics on CreateTime topics with out-of-order timestamps] → messages with in-range
  timestamps before the resolved start offset are missed; the scope summary text says the range is resolved via the
  broker's timestamp index. Spike 1.1 confirms `-1`/End handling and per-element errors with rdkafka 0.36.2.
- [Estimate and scan disagree because the log moved] → both labelled; the scan's own `total_messages_to_scan` drives
  progress.
- [Newest/oldest N on compacted or transactional topics reads fewer messages than N] → count is defined in offsets;
  the scope dialog and summary say "up to N offsets".
- [History disk usage] → bounded by N × topics analysed; files are typically < 1 MB (bounded report sections).
- [Untracked messages counted as unique bias the duplicate rate down] → labelled as lower bound with the untracked
  count; exact below 1.8 M distinct messages.
- [`partition-offset-distribution` not merged first] → this change implements its `fetch_partition_offsets` and core
  watermark types exactly as its design specifies (task 2.1), so the later change only adds its UI.
- [Partition ids from a stale `partitionCount`] → Rust rejects unknown ids with an error; the dialog reloads ids from
  the current `TopicMetadata`.

## Migration Plan

Additive only: new `Option`/`#[serde(default)]` fields, one new bridge function, file version 4 with 1–3 still
importable, two new settings with defaults. No stored data is rewritten. Rollback = revert; v4 files written in the
meantime are rejected by older builds with the existing "unsupported version" message (no data loss).

## Open Questions

- Spec conflict (pre-existing, not changed here): `topic-content-analysis` "Decoupled Progress Reporting" says full
  reports are synthesized only on completion or cancellation, while `topic-analysis-value-filter` ("Live update during
  the scan") and the cancel mechanism rely on periodic partial reports. This change keeps partial reports and removes
  the unbounded clone; aligning the two specs is left to a separate change.
- Pre-existing deviation: "Export a partial (cancelled) report — the imported result SHALL reflect that it is a partial
  report" has no field in the report today. Not addressed here.
