# Design: partition-offset-distribution

## Context

See proposal.md for motivation. Current code on disk (verified, roadmap claims checked):

- `rust/kafkalyzer-kafka/src/kafka_metadata.rs::fetch_topic_partitions` reads one `fetch_metadata(Some(topic), 10 s)`
  and returns leader/replicas/ISR per partition (`kafkalyzer_core::partition_health::PartitionMetadata`). The bridge
  maps it to `PartitionRow` (`rust/src/api/kafka_metadata.rs`) with `under_replicated`/`leaderless` flags. No
  watermarks anywhere in this path (confirms roadmap §2.4: "Topic-Liste und `PartitionRow` enthalten keine
  Watermarks").
- Watermarks are read in three other places, all sequentially, one `BaseConsumer::fetch_watermarks` per partition:
  `kafka_consumer.rs::fetch_partition_watermarks` (5 s, errors only logged to the stream sink),
  `kafka_analyzer.rs` setup (5 s), and `kafka_metadata.rs::fetch_watermark_cached` (lag path, high only, error text
  `Log end offset unreadable: …`). None is reusable as-is: the first is tied to a `StreamSink`, the last drops `low`.
- `kafka_analyzer.rs` already shares an `Arc<BaseConsumer>` across `std::thread::scope` workers, so concurrent use of
  one `BaseConsumer` is an established pattern in this crate.
- Dart: `TopicPartitionHealthTable` (stateful, loads `fetchTopicPartitions` in `initState`) is used in
  `TopicPartitionHealthDialog` (opened from the "n Partitions", "RF" and health tags in `topic_detail_view.dart`) and
  in the analysis tab card next to `PartitionBalanceView` (exact, scan-based skew with a hard-coded 1.5× rule).
- The cleanup policy is `TopicMetadata.cleanupPolicy: String?` from the topic list's bulk `describe_configs`; `null`
  when the read failed (and, after 5.33, possibly before configs are loaded).
- Numeric settings use `IntSetting` + `_IntSettingField` (`settings_service.dart`, `settings_view.dart`), with
  `readInt` falling back to the default for out-of-range values and `resetGeneralSettings` writing defaults.
- `test/l10n/hardcoded_strings_guard_test.dart` and `arb_consistency_test.dart` exist in the tree (from the in-progress
  `accessibility-and-l10n-sweep`); new widgets must pass them without allowlist entries.

## Goals / Non-Goals

**Goals:**

- One reusable Rust read `fetch_partition_offsets(profile, topic)` with per-partition results, bounded parallelism and
  an overall deadline, for this change, 5.34 and 5.37.
- Pure, unit-tested distribution and skew rules in `kafkalyzer-core`.
- A dialog block that never shows a guessed value: unknown stays unknown, shares only when complete.

**Non-Goals:**

- Replacing the three existing sequential watermark loops (consumer, analyzer, lag). They work and have their own
  error paths; migrating them is not needed for this feature.
- Changing `PartitionBalanceView`'s exact skew rule or the analysis tab card.
- Timestamps of first/last message (5.34), configs (5.33/5.10).

## Decisions

### D1 Separate call and DTO instead of extending `PartitionRow`

The roadmap says "`PartitionRow` additiv erweitern". `fetch_topic_partitions` is also used by the analysis tab card,
which must not read offsets (spec: on demand from the detail view only), and offsets have per-partition failure modes
that replication metadata does not have. A separate bridge function `fetch_partition_offsets` with its own DTO keeps the
existing call cheap, keeps its signature unchanged (L3) and gives 5.34/5.37 a call without replication data.
*Alternative:* `Option` watermark fields on `PartitionRow` plus a flag parameter on `fetch_topic_partitions` — changes
an existing signature and mixes two failure domains in one row.

### D2 Layering

| Layer | New code | Why here |
|---|---|---|
| `kafkalyzer-core` | `offset_distribution.rs`: `WatermarkRead`, `PartitionWatermarks`, `OffsetDistribution`, `SkewStatus`, `summarize_offsets(&[PartitionWatermarks], Option<u8>)` | Pure maths, unit-testable, reused by 5.34 (total span as count estimate) and 5.37 (scan size estimate). |
| `kafkalyzer-kafka` | `kafka_metadata::fetch_partition_offsets(&ClusterProfile, &str) -> Result<TopicPartitionOffsets>` | rdkafka I/O. |
| bridge crate | `api::kafka_metadata::fetch_partition_offsets(profile, topic, skew_threshold_percent: Option<u32>) -> Result<PartitionOffsetDistribution>` + DTOs | frb boundary; maps domain → DTO (orphan rule). |
| Dart | `KafkaMetadataService.fetchPartitionOffsets`, `PartitionOffsetDistributionView`, dialog wiring, setting | View state and presentation only. |

Core types (sketch):

```rust
pub enum WatermarkRead {
    Known { low: i64, high: i64 },
    NotReadable(String), // authorization failure
    Failed(String),      // any other broker/client error, incl. leader not available
    TimedOut,            // not finished before the overall deadline
}
pub struct PartitionWatermarks { pub partition: i32, pub read: WatermarkRead }

pub enum SkewStatus {
    NotRequested,                 // threshold None (5.34/5.37 callers)
    NotEvaluated(SkewSkipReason), // SinglePartition | Incomplete | Empty
    Balanced,
    Skewed(Vec<i32>),
}
pub struct PartitionShare { pub partition: i32, pub span: Option<i64>, pub share_percent: Option<f64>, pub skewed: bool }
pub struct OffsetDistribution {
    pub rows: Vec<PartitionShare>, // sorted by partition
    pub total_span: Option<i64>,   // None unless every partition is Known
    pub known_span: i64,           // sum over Known rows (for "at least n" texts in 5.37)
    pub complete: bool,
    pub skew: SkewStatus,
}
```

Rules (all unit-tested):

- `span = high − low` for `Known` with `0 ≤ low ≤ high`; `low > high` or a negative offset becomes `Failed("invalid
  watermarks")` (no negative spans, no 0 fallback).
- Sums use `i128` and saturate to `i64::MAX`.
- `total_span` and every `share_percent` are `Some` only when all partitions are `Known` and the total is > 0.
- Skew is evaluated only when `threshold = Some(t)`, `1 ≤ t ≤ 100`, `rows.len() ≥ 2`, complete and total > 0.
  A partition is skewed when `span × 100 > t × total` (integer comparison, so "equal to threshold" is not skewed and
  no float rounding decides the badge).
- An empty partition list → `complete = false`, `NotEvaluated(Incomplete)` (the kafka layer reports a topic without
  partitions as an error anyway).

### D3 Bounded parallel watermark reads with a deadline

`fetch_partition_offsets`:

1. Build a `BaseConsumer` from `create_config(profile)` with `enable.auto.commit=false` (same as the lag path); no
   `assign`, no `subscribe`.
2. `fetch_metadata(Some(topic), 10 s)`; topic missing or topic-level error → `Err` (whole call fails, Dart shows the
   inline error with retry). Authorization errors keep their error code in the message so Dart can say "not readable".
3. Workers: `min(8, partition_count)` scoped threads share `&BaseConsumer` and pull partition ids from an
   `AtomicUsize` index. Each read is `fetch_watermarks(topic, p, min(5 s, remaining))`. A worker stops pulling when
   the overall deadline (30 s) has passed; unclaimed partitions become `TimedOut`.
4. Error mapping: `KafkaError::*(RDKafkaErrorCode::TopicAuthorizationFailed | ClusterAuthorizationFailed)` →
   `NotReadable`; everything else → `Failed(e.to_string())`.
5. Result: `TopicPartitionOffsets { topic, read_at_ms, partitions: Vec<PartitionWatermarks> }` sorted by partition.

Worst case wall time ≈ `ceil(P / 8) × 5 s`, capped at ~30 s + 5 s for the last in-flight reads. 8 workers keep a
1,000-partition topic at ~125 round trips per worker while staying well under librdkafka's request pipelining limits.
Constants live in the kafka crate as named `const`s; they are not user settings (YAGNI).

*Spike 1.1 findings (2026-11-15, `sift_kafka` `localhost:9094`, 60-partition topic `spike-offset-dist-60p`):*
- 8 scoped threads sharing one `&BaseConsumer` produced identical `(low, high)` tuples to the sequential loop (`seq_ms=6`, `par_ms=4`). Parallel `fetch_watermarks` is safe and fast; fallback D3 (b) is not needed.
- `KafkaError::rdkafka_error_code()` surfaces `RDKafkaErrorCode::TopicAuthorizationFailed` / `ClusterAuthorizationFailed` for ACL denials (`-> NotReadable`), while leaderless/broker errors (`LeaderNotAvailable`, `NotLeaderForPartition`, `UnknownTopicOrPart`, etc.) map to `Failed`.

*Alternatives:* (a) sequential loop like the existing code — a 500-partition topic with one slow leader would block
for minutes; (b) librdkafka 2.3 `rd_kafka_ListOffsets` via raw FFI (one request per leader) — fastest, but new unsafe
FFI surface; kept as fallback if the spike (task 1.1) shows parallel `fetch_watermarks` is unsafe or does not scale;
(c) tokio `spawn_blocking` per partition — unbounded unless a semaphore is added; scoped threads are simpler and
already used in `kafka_analyzer.rs`.

### D4 Bridge DTOs

Not persisted, so no serde attributes. Additive; nothing existing changes.

```rust
pub enum PartitionOffsetState { Known, NotReadable, Failed, TimedOut }
pub enum OffsetSkewStatus { NotRequested, SinglePartition, Incomplete, Empty, Balanced, Skewed }
pub struct PartitionOffsetRow {
    pub partition: i32, pub state: PartitionOffsetState, pub error: Option<String>,
    pub low: Option<i64>, pub high: Option<i64>, pub span: Option<i64>,
    pub share_percent: Option<f64>, pub skewed: bool,
}
pub struct PartitionOffsetDistribution {
    pub topic: String, pub read_at_ms: i64, pub partitions: Vec<PartitionOffsetRow>,
    pub total_span: Option<i64>, pub known_span: i64, pub complete: bool,
    pub skew_status: OffsetSkewStatus, pub skew_threshold_percent: Option<u32>,
}
```

`skew_threshold_percent` outside `1..=100` → `Err` (Dart only passes values that passed `IntSetting` validation).
The bridge runs as a normal (non-sync) frb function, so it executes off the UI isolate like `fetch_topic_partitions`.

### D5 Dart view and state flow

- `KafkaMetadataService.fetchPartitionOffsets({profile, topic, skewThresholdPercent})` forwards to the bridge.
- New stateful `PartitionOffsetDistributionView({profile, topicName, cleanupPolicy, onOpenAnalysis})` in
  `lib/src/features/topic/presentation/widgets/`. On `initState` it reads `SettingsService.partitionSkewThresholdSetting`
  via `readInt` and calls the service once; refresh calls it again (single-flight: ignored while loading). States:
  loading (progress indicator), error (inline error with retry; uses `ErrorBanner` if the l10n sweep has added it),
  loaded.
- Rows: `ListView.builder` with fixed `itemExtent` inside a bounded height, so 1,000+ partitions render lazily; numbers
  formatted per visible row with `NumberFormat.decimalPattern(locale)`. Share bar = `LinearProgressIndicator(value:
  share/100)` with the percentage as text. Unknown values render the localized "unknown"; non-`Known` rows show the
  state text (not readable + permission hint / error / timed out) with the error as tooltip.
- Header line: "Offset distribution (estimate)", read time ("read at HH:mm:ss", local time format of the app), refresh
  `IconButton` with tooltip, and an "Exact values in topic analysis" `TextButton`.
- Notes: compaction note when `cleanupPolicy` split by `,` contains `compact` (trimmed, case-insensitive); "cleanup
  policy unknown" note when `cleanupPolicy == null`; "shares need all partitions" when not complete; "topic retains no
  offsets" when status `Empty`.
- Skew badge: `Icons.warning_amber` + text listing skewed partitions and shares, colours from `tertiary` /
  `tertiaryContainer` (status mapping of `accessibility-and-l10n-sweep` D8); skewed rows get the same icon. Nothing is
  shown for `Balanced`, `NotRequested` or `NotEvaluated`.
- Staleness: the view watches `ActiveConnectionController`; when `activeProfile` is no longer `profile` (disconnect or
  switch), it shows a "not current" note and disables refresh, keeping the old values greyed out.
- `TopicPartitionHealthDialog` gets optional `cleanupPolicy` and `onOpenAnalysis` and places the new view under the
  existing table inside a scrollable column (dialog max height raised from 500 to ~680). `topic_detail_view.dart`
  passes `widget.topic.cleanupPolicy` and `() => setState(() => _viewMode = TopicViewMode.analysis)`; the dialog pops
  first. The analysis tab card is untouched, so it never reads offsets.
- Setting: `SettingsService.partitionSkewThresholdSetting = IntSetting('topic_partition_skew_threshold_percent', 50,
  1, 100)`, an `_IntSettingField` in the General section next to the lag warning threshold, included in
  `resetGeneralSettings`.

### D6 Read-only

Only `fetch_metadata` and `fetch_watermarks` (Metadata + ListOffsets). Both are already used by the consumer, analyzer
and lag paths, so `scripts/check_read_only.sh` needs no new exception. No Admin client is created.

## Risks / Trade-offs

- [Parallel `fetch_watermarks` on one `BaseConsumer` misbehaves] → spike 1.1 checks it against the local test broker
  with ≥ 50 partitions; fallback D3 (b).
- [Leaderless partition makes its read wait the full 5 s] → it becomes a `Failed` row; other workers continue; the
  overall deadline bounds the total.
- [Very large topics (thousands of partitions) hit the 30 s deadline] → partial result with `TimedOut` rows, no shares,
  no skew; the user can refresh. Shown honestly instead of blocking.
- [Compacted/transactional topics: span ≠ count] → estimate label always shown, compaction note, exact-values action.
  Transactional markers are not detectable from metadata; the generic estimate label covers them.
- [`cleanupPolicy` is `null` more often after 5.33] → explicit "unknown" note; no extra `describe_configs` here.
- [Settings delta overlaps with siblings adding numeric settings (e.g. 5.37's scan-size threshold, E20)] → both
  MODIFY the same two requirements; whichever archives second must rebase its MODIFIED blocks on the merged text.
- [Hard-coded 1.5× rule in `PartitionBalanceView` differs from the new threshold] → intentional: different data
  (exact counts vs offset spans); unifying is out of scope and noted for the l10n/a11y sweep owner.

## Migration Plan

Additive only: new bridge function and DTOs, new setting key with a default. No stored data changes. Rollback = revert
the change; the unknown preference key is ignored by older builds.

## Open Questions

- Exact worker count (8) and deadline (30 s) may be tuned after the spike; they are constants and do not change specs.
