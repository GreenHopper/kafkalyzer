# Design

## Context

See `proposal.md` (Why) for the verified findings. Current state relevant to the approach:

- `rust/kafkalyzer-kafka/src/kafka_metadata.rs` has three near-identical lag paths: `fetch_consumer_lags` (all groups,
  one main consumer, shared watermark cache, not used by the Dart UI), `fetch_consumer_groups` (list only, no lag) and
  `fetch_consumer_group_lag` (one group, used per row). Each path derives the group's topics from member
  subscriptions/assignments, so a member-less group has no topics.
- Committed offsets are read with `BaseConsumer::committed_offsets` on a consumer created from `create_config` plus
  `group.id`. That consumer never subscribes or assigns; it does not set `enable.auto.commit=false`.
- rdkafka 0.36.2 (`AdminClient`) has no API to list a group's committed offsets: it offers create/delete topics,
  delete groups, create partitions, describe/alter configs. The newer 0.39.0 in the local registry adds none either.
  `rdkafka-sys` 4.7.0 bundles librdkafka 2.3.0, whose C API exposes `rd_kafka_ListConsumerGroupOffsets` (partitions
  `NULL` = all committed offsets of the group) and `rd_kafka_DescribeConsumerGroups`; neither is wrapped by rdkafka.
- Bridge DTOs `TopicPartitionLag` and `ConsumerGroupLag` live in `rust/src/api/kafka_types.rs` and map 1:1 from
  `kafkalyzer_core::kafka_types`. Dart reads `lag.lag.toInt()` and `currentOffset == -1` in several places, and the
  mocks in `test/src/rust/api/rust_mocks.mocks.dart` are generated from the bridge.
- `consumer_lag_view.dart` holds all lag state in the widget: per-row lazy loading triggered from `itemBuilder`, a
  queue limited by the `consumer_max_concurrent_queries` preference, and `Timer.periodic` refresh without an
  in-flight guard. Polling stays in the widget in this change.

## Goals / Non-Goals

**Goals:**

- One lag implementation in `kafkalyzer-kafka` that returns a per-group result (never drops a group, never drops a
  partition) for one or many groups, with shared metadata and watermark lookups per call.
- Pure classification and aggregation rules in `kafkalyzer-core`, unit-testable without a broker.
- Additive bridge change: no existing field changes type or meaning, existing bridge functions keep their signatures.
- Dart view: complete aggregates or explicit "n of m", single-flight refresh, retrievable per-group errors.

**Non-Goals:**

- Labelling offset-distance lag as an estimate for compacted/transactional topics, and detecting committed offsets
  below the log start offset (existing behaviour, unchanged; candidates for `consumer-lag-insights`).
- Batched watermark requests (one ListOffsets per partition stays; cache only avoids repeats).
- A view-independent polling controller (`lag-stall-detection-and-alerts`).
- Localising pre-existing hard-coded KPI texts (`accessibility-and-l10n-sweep`); only new and touched strings move to ARB.

## Decisions

### D1 Listing committed offsets of a member-less group (spike first)

Must be decided by a spike (task 1) because it depends on runtime behaviour of librdkafka against a real broker.
Candidates, in order of preference:

- **A. `rd_kafka_ListConsumerGroupOffsets` via `rdkafka-sys` FFI.** One admin handle, one request per group, returns
  every committed partition of the group, including topics nobody is subscribed to any more. Read-only (OffsetFetch).
  Cost: a small `unsafe` wrapper in `kafkalyzer-kafka` (event queue, result parsing, destroy calls); librdkafka 2.3.0
  accepts one group per request. Works on all three platforms because it is the same bundled librdkafka.
- **B. `committed_offsets` over a bounded candidate set.** The existing group consumer queries all partitions of all
  non-internal topics from cluster metadata; partitions returning `Offset::Invalid` are dropped *only for topics
  without any commit*. No `unsafe`, but one large OffsetFetch per group; capped (e.g. 10 000 partitions). Above the cap
  the group's lag is "unknown" with reason "too many partitions to scan".
- **C. Last-known topics.** Topics seen for the group earlier in the session. Incomplete on first view; only usable
  as a supplement, not as the source.

Rejected: upgrading rdkafka (no wrapper in 0.39 either); reading `__consumer_offsets` (needs Read on an internal topic,
binary format, full scan).

The spike also confirms that a consumer with `group.id` set that only calls `committed_offsets` does not appear as a
group member and does not change the group state (`kafka-consumer-groups --describe --members` before/after).
**Fallback** if neither A nor B is acceptable: member-less groups get group-level status "unknown" with reason
"committed offsets of groups without members cannot be listed", never lag 0. The spec holds in every outcome.

### D2 Additive DTO fields instead of nullable numbers

Add to `TopicPartitionLag`: `status: PartitionLagStatus` (`Known`, `NoCommit`, `Unknown`) and `error: Option<String>`.
For non-`Known` rows `current_offset` is `-1` (already rendered as "-") and `lag` is `0`; `log_end_offset` is `-1` when
unreadable. Add to `ConsumerGroupLag`: `lag_error: Option<String>` (group-level failure) and
`ownership_known: bool`.

Alternative: change `current_offset`/`lag` to `Option<i64>`. Rejected: frb turns them into nullable Dart types, which
breaks every `lag.lag.toInt()` call site and the generated mocks. Risk of the chosen variant: a caller that ignores
`status` sums placeholder zeros; mitigated by routing every Dart sum through one helper (D6) and by a test.

### D3 One lag implementation, batched entry point

`kafkalyzer-kafka` gets one internal function computing `Vec<ConsumerGroupLag>` for a set of `GroupListing`s with one
main consumer, a per-call topic-metadata cache and the existing watermark cache. Each group is computed inside its own
`Result` boundary; a failure becomes `lag_error` on that group. Entry points:

- existing `fetch_consumer_lags(profile)` and `fetch_consumer_group_lag(profile, group_id)` delegate to it (signatures
  unchanged);
- new `fetch_consumer_group_lags(profile, group_ids: Vec<String>) -> Vec<ConsumerGroupLag>` (bridge + service) used by
  the view. Group ids unknown to the cluster come back with `lag_error = "group not found"`.

Alternative: keep per-group calls and only load all rows eagerly from Dart. Rejected: each call creates two clients and
refetches metadata/watermarks; with hundreds of groups that multiplies broker requests.

### D4 Pure rules in `kafkalyzer-core`

- `classify_partition(committed: Option<i64>, log_end: Result<i64, String>) -> (status, lag, error)`.
- `group_total(&[TopicPartitionLag], lag_error) -> GroupLagTotal { Known(i64), NoCommittedOffsets, Unknown(reason) }`:
  `Unknown` if a group error or any `Unknown` partition; `NoCommit` partitions are excluded from the sum and counted.
- `unassigned_partitions` moves from `kafkalyzer-kafka` to `kafkalyzer-core` (it is pure) and returns `None` when any
  member's assignment is undecodable or there are no members; callers set `ownership_known` from it.

The cross-group aggregate ("n of m", sort with unknown last) stays in Dart: it depends on view state (filter, loaded
set) and has no second caller yet.

### D5 Members and topics per state

Members are collected for every state the group listing reports them for (not only `Stable`). Topic set =
members' subscriptions and assignments ∪ topics with committed offsets (D1). Unassigned partitions are computed only
over subscribed topics of a `Stable` group with `ownership_known`; transient rebalance states and member-less groups
report ownership as unknown / not applicable instead of "all partitions unassigned".

### D6 Dart view state flow

- **Single-flight cycle:** `_fetchLags` returns early when a cycle is running (timer tick skipped; manual refresh
  button shows progress and is disabled). Each cycle carries a generation number; results whose generation or profile
  is outdated are discarded. Values of the previous cycle stay visible until replaced.
- **Eager loading:** after the group list arrives, the filtered group ids are split into chunks (fixed size, e.g. 20)
  and enqueued; the existing concurrency limit applies per bridge call. Visible rows no longer trigger loads from
  `itemBuilder`; filter changes enqueue newly listed, not-yet-loaded groups.
- **Aggregates:** one helper returns a group's known total or `null`; KPI sums only known totals and shows "n of m"
  while incomplete or when any group failed; sort by lag puts `null` last in both directions.
- **Errors:** `Map<String, String> _groupErrors`; the badge shows a localised "Error" with the reason as tooltip, and
  the group details show the reason with a retry action that enqueues only that group.

### D7 Read-only enforcement

The committed-offset consumer explicitly sets `enable.auto.commit=false` and `enable.auto.offset.store=false`, and
the code never calls `subscribe`, `assign`, `commit*`, `store_offset*`. If candidate A is chosen, the FFI wrapper only
binds `ListConsumerGroupOffsets` (no Alter/Delete offsets). `scripts/check_read_only.sh` is not changed here: `harden-read-only-gate`
(implemented earlier in Phase 0) already rejects mutating `rd_kafka_*` C calls, so the wrapper is covered.

## Risks / Trade-offs

- [FFI wrapper (A) leaks or crashes on error paths] → wrap all librdkafka objects in RAII guards, unit-test result
  parsing with fixtures where possible, cover success and error (group not found, authorization failed) in the manual
  broker check.
- [Candidate B is expensive on large clusters] → hard partition cap with "unknown" outcome; chunked batches keep each
  call bounded.
- [Eager loading raises broker load] → batched calls with shared caches, existing concurrency limit, single-flight
  refresh; no extra polling.
- [Batch latency: one slow coordinator blocks a chunk for the 5 s timeout] → small chunk size, parallel chunks within
  the concurrency limit; per-group timeout becomes a group error, not a batch error.
- [Missing ACLs] → group describe denied → group `lag_error`; topic describe denied → topic rows "unknown/not
  readable"; never 0.
- [Deleted topic still has commits] → rows "unknown" with reason "topic not found".
- [Empty topic] → log end 0 and no commit → "no commit"; committed offset above log end (recreated topic) keeps
  lag 0 as today.
- [Callers ignore `status` and sum placeholder zeros] → single Dart helper + widget test with a `NoCommit`/`Unknown`
  partition.

## Migration Plan

No persisted data changes. Bridge change is additive; regenerate bindings and mocks. Rollback = revert the change; no
stored state to migrate.

## Open Questions

- Spike outcome A vs. B vs. fallback (D1). Does not change specs or task order; only the body of task 2.x/3.x.
- Exact chunk size and candidate-B partition cap; set from spike measurements against the local broker.
- `consumer-lag-dashboard` describes the Total Lag KPI as covering "all consumer groups", while the view sums the
  filtered list. This change keeps the filtered set and only adds completeness; reconciling the wording is left to
  `consumer-lag-insights`, which modifies that capability.
