# Design: cluster-overview-and-topic-facts

## Context

See proposal.md (Why). State of the code on disk (working tree incl. uncommitted Phase 1 edits), checked for this design:

- `ClusterOverviewView` (`lib/src/features/explorer/presentation/widgets/cluster_overview_view.dart`) is stateless and
  gets `profile`, `topicCount`, `isLoading` from `explorer_view.dart` (≈ line 927). `topicCount` is
  `topicController.getTopics(profile)?.length ?? 0`, so a failed topic load shows "0 Topics" — this contradicts the
  existing requirement *Load Failure Error States in Explorer* ("SHALL NOT be shown as … zero topics"). Fixed here as
  part of the modified overview requirement.
- `kafkalyzer_kafka::kafka_metadata::fetch_topics` does `fetch_metadata(None)` and one `describe_configs` for all
  topics; it returns per topic `under_replicated_partitions` / `leaderless_partitions` as `Option<i32>` (`None` = no
  partition list), computed by `kafkalyzer_core::partition_health::summarize_topic_health`. Brokers are read but
  dropped. Topics with a metadata error are skipped (B9, owned by 5.33).
- `fetch_topic_partitions` already maps `metadata.brokers()` into `BrokerEndpoint {id, host, port}` (bridge DTO exists in
  `rust/src/api/kafka_metadata.rs`).
- rdkafka 0.36.2 / rdkafka-sys 4.7.0 (librdkafka 2.3.0): `Metadata` exposes `brokers()`, `topics()`,
  `orig_broker_id/name` — no cluster id, no controller. `Client::fetch_cluster_id` wraps `rd_kafka_clusterid` (and does
  not free the returned string). `rd_kafka_controllerid` is only in rdkafka-sys. `rd_kafka_DescribeCluster` exists in
  rdkafka-sys (nodes incl. rack, controller, cluster id) but has no safe wrapper. Nothing exposes a broker version.
- `ActiveConnectionController.topics` filters by internal (`_` prefix), "stream" suffixes and a substring filter
  (5.33 rewrites this); `_topicFilter` is reset on connect (≈ line 509).
- `TopicDetailView` header: `_buildTopicTags` renders `"${partitionCount} Partitions"`, `"RF: …"` (hard-coded, not
  caught by the l10n guard because `TopicTag` takes a positional string), cleanup policy and
  `formatRetention(retentionMs)` → `"x.x days"`/`"x.x hrs"`/`"Infinite"` (`topic_utils.dart:275`, also used by
  `topic_list_item.dart` tooltip). There is no `retention.bytes` anywhere.
- Topic tabs live in an `IndexedStack`; every restored tab runs `initState`. Per-tab controllers are created through
  `activeController.getStreamController(key)` / `getAnalysisController(key)`.
- Reusable helpers: `TopicAnalysisSummaryCards.formatBytes`, `DateFormatUtils`, `TimeDisplaySettings` (global
  local/UTC). No shared "message timestamp with zone" formatter exists in Dart today (grep for `timeZoneOffset`
  finds only the JSON tree tooltip).
- Siblings: 5.11 (`partition-offset-distribution`, proposal written) adds `kafka_metadata::fetch_partition_offsets`
  (per-partition result, bounded concurrency, deadline) and `kafkalyzer_core::offset_distribution` (span, total span),
  bridge `fetch_partition_offsets(profile, topic, skew_threshold_percent)`. 5.33 owns
  `describe_topic_configs(profile, topics) -> per-topic Result` (all entries with source/default/sensitive flags) and
  the topic-list filter pipeline.

## Goals / Non-Goals

**Goals:** one cheap broker read for the overview; reuse 5.11 and 5.33 reads for the header; a time-range probe whose
cost is bounded per partition and in time; all logic that is pure computation in `kafkalyzer-core` and unit-tested; no
change to existing bridge signatures.

**Non-Goals (design level):** no `DescribeCluster` wrapper; no new crate or package; no stream API (all new bridge calls
return one result); no caching across sessions.

## Decisions

### D1 Overview broker read: brokers-only Metadata request (spike-gated)

New `kafka_metadata::fetch_cluster_overview(profile) -> Result<ClusterOverview>` with
`ClusterOverview { brokers: Vec<BrokerEndpoint>, cluster_id: Option<String>, controller_id: Option<i32> }`:

1. `BaseConsumer` from `create_config` (no `group.id` needed, no `assign`).
2. `rd_kafka_metadata(rk, all_topics = 0, only_rkt = NULL, &md, 10 s)` — on a fresh handle librdkafka knows no topics, so
   the request carries an empty topic list and the response holds brokers, controller id and cluster id but no topic
   records. Read `broker_cnt/brokers` into `BrokerEndpoint`, then `rd_kafka_metadata_destroy` (RAII guard like the
   existing `QueueGuard`/`EventGuard`).
3. `rd_kafka_clusterid(rk, 0)` and `rd_kafka_controllerid(rk, 0)` read the response cached by step 2 (timeout 0 = no
   extra request). The cluster id string is freed with `rd_kafka_mem_free` (the safe `fetch_cluster_id` leaks it).
   `-1` controller → `None`; null cluster id → `None`.
4. Brokers sorted by id. Errors: `MetadataFetch(code)` → `Err`; authorization codes are mapped to a "not readable"
   message the Dart side recognizes (same convention 5.11 uses for partitions).

Spike (task 1.1) must confirm on the docker-compose broker: (a) the empty-topic request returns all brokers and no
topics; (b) cluster id and controller are non-null right after it; (c) a user without topic DESCRIBE still gets
brokers. If (a) fails, fall back to `fetch_metadata(None)` and ignore its topics (correct but costs a full topic list on
big clusters — record in the spike note).

**Spike 1.1 results (local KRaft broker `sift_kafka` on `localhost:9094`):**
- `rd_kafka_metadata(rk, 0, NULL, &md, 10000)` returned `broker_cnt=1`, `topic_cnt=1026` (all topics, not 0).
- `rd_kafka_clusterid(rk, 0)` returned `Some("MkU3OEVBNTcwNTJENDM2Qg")` and `rd_kafka_controllerid(rk, 0)` returned `1` (non-null/valid on KRaft).
- Because `all_topics=0, only_rkt=NULL` still returned the full topic list in librdkafka 2.3.0, D1 switches to `BaseConsumer::fetch_metadata(None, 10s)` (ignoring its topics) while reading `rd_kafka_clusterid(rk, 0)` (freed via `rd_kafka_mem_free`) and `rd_kafka_controllerid(rk, 0)`.

**Spike 1.2 results (transactional `spike-tx-12` & compacted `spike-compact-12` on `localhost:9094`):**
- Head phase: `pause()` immediately stopped further deliveries (`post_pause_msgs=0`) after the first record at `low=0`.
- Tail phase: reusing the paused `BaseConsumer` required `unassign()` + `assign(tail_tpl)` + `resume(tail_tpl)` (or a fresh `BaseConsumer`) so paused partitions deliver again.
- With a 16-offset tail window (`tail_start=0`), `spike-tx-12` (`high=12`) delivered `last_offset=Some(10)` (skipping the commit marker at 11) and `got_eof=true`; `spike-compact-12` (`high=8`) delivered `last_offset=Some(7)` and `got_eof=true`.

Alternatives: reuse the topic-list read (`fetch_topics`) and return brokers with it — rejected: 5.33 owns that result
type and is changing it; coupling the overview to it would serialize both changes. `DescribeCluster` admin API — gives
rack and authorized operations but needs broker ≥ 2.8 and the raw event-queue plumbing of
`list_consumer_group_offsets`; nothing in the requirement needs rack. `fetch_metadata(None)` — kept only as fallback.

### D2 Broker version is not shown

librdkafka negotiates `ApiVersions` per broker internally and exposes neither the result nor a version string; the
only trace is `debug=broker,protocol` log output. Parsing debug logs is fragile and noisy (5.3 decided against
`debug` contexts for the same reason). The roadmap's "only if readable" therefore resolves to "not shown"; the spec
does not mention a version.

### D3 Time-range probe

`kafkalyzer_kafka::topic_time_range::fetch_topic_time_range(profile, topic, deadline) -> Result<Vec<PartitionProbe>>`,
bridge `fetch_topic_time_range(profile, topic) -> TopicTimeRange` (deadline fixed at 15 s, see D7).

1. Watermarks: call 5.11's `fetch_partition_offsets(profile, topic)` (fresh values at probe time). Partitions whose
   offsets failed become `Unreadable(reason)`; `low == high` → `Empty` (no records can exist; this is not a completion
   inference).
2. Consumer: `create_config` + random `group.id` (same pattern as `create_consumer` in `kafka_consumer.rs`; no group is
   joined without `subscribe()`), `enable.auto.commit=false`, `enable.auto.offset.store=false`,
   `enable.partition.eof=true`, `auto.offset.reset=earliest` (low watermark may move by retention between step 1 and
   the fetch), `fetch.message.max.bytes=65536`, `fetch.wait.max.ms=100`, `queued.min.messages=1`,
   `queued.max.messages.kbytes=1024`. Default `isolation.level` (read_committed), consistent with the message view.
3. Head phase: `assign()` every non-empty partition at its low watermark. Poll until each partition delivered its first
   message (then `pause()` it — local call, no RPC) or reported `PartitionEOF`, or the deadline passes. The first
   delivered message's timestamp and type are the partition's oldest value.
4. Tail phase: `assign()` every non-empty partition at `kafkalyzer_core::topic_time_range::tail_start_offset(low, high,
   TAIL_WINDOW = 16)` = `max(low, high - 16)`. Poll until each partition reports `PartitionEOF` or the deadline passes;
   the last delivered message (highest offset) per partition is its newest value. No message before EOF →
   `NotFoundInWindow` (transaction markers, aborted or compacted records, or an open transaction holding the LSO
   below the window).
5. No network call inside either poll loop; progress is in-memory. Remaining budget is shared: head phase gets at most
   half of the deadline, tail phase the rest. Partitions still open at the deadline → `TimedOut`.
6. A message with `Timestamp::NotAvailable` → `NoTimestamp` for that value.

Pure part in `kafkalyzer_core::topic_time_range` (new module, unit tests without broker): outcome types
(`Found{offset, timestamp_ms, timestamp_type}`, `Empty`, `NotFoundInWindow`, `NoTimestamp`, `TimedOut`,
`Unreadable(String)`, `Failed(String)`), `tail_start_offset`, and `aggregate(&[PartitionProbe]) -> TopicTimeRange
{ oldest: Option<Found+partition>, newest: Option<…>, partitions_total, partitions_empty, oldest_known,
newest_known, all_empty }`. Oldest = minimum of per-partition first timestamps, newest = maximum of per-partition last
timestamps (CreateTime need not be monotonic in offset order; the label says "oldest/newest retained message" and the
tooltip names partition and offset).

Cost bound: per non-empty partition at most one fetch response at the low watermark and the batches covering 16
offsets at the tail; a broker returns at least one whole record batch even above `fetch.message.max.bytes`
(KIP-74), so the worst case is ≈ 2 × max batch size per partition. Memory is capped by `queued.max.messages.kbytes`.
The action is explicit and its tooltip shows the partition count.

Alternatives: `offsets_for_times` — gives offsets for a timestamp, not the timestamp of the first/last message;
useless for "oldest" and only a lower bound for "newest". Reading exactly `high - 1` — on transactional topics the last
offset is almost always a commit marker, so it would nearly always fail. Widening the tail window on miss — doubles the
cost on exactly the topics that are expensive; rejected (`shortcut:` comment in code: fixed window 16, widen only if
users report unknown newest values on transactional topics). Running the probe automatically on tab open — rejected:
restored sessions with many tabs would read messages from every topic.

### D4 Layer assignment

| Logic | Layer | Why |
|---|---|---|
| Tail start, probe outcome types, aggregation | `kafkalyzer-core::topic_time_range` | pure, unit-testable |
| Brokers-only metadata, cluster id, controller | `kafkalyzer-kafka::kafka_metadata` | rdkafka FFI |
| Probe consumer + poll loops | `kafkalyzer-kafka::topic_time_range` (new file; `kafka_metadata.rs` is already 1200 lines) | rdkafka |
| DTOs `ClusterOverview`, `TopicTimeRange`, `PartitionTimeProbe` | `rust/src/api/kafka_metadata.rs` (additive) | L3 |
| Cluster totals + health summary (topic/partition sums, unhealthy/unknown counts) | Dart pure function `summarizeCluster(List<TopicMetadata>)` in `features/explorer/domain/` | counts over already classified per-topic values; one caller; config rule "move to Rust only with a second caller" |
| Retention duration/bytes formatting | Dart `topic_utils.dart` | presentation + l10n |

### D5 Drill-down hook (coordination with 5.33)

`ActiveConnectionController` gets a transient `bool unhealthyTopicsOnly` with `showUnhealthyTopicsOnly()` (sets the flag,
clears the text filter, notifies) and `clearUnhealthyTopicsOnly()`. In the `topics` getter the flag is evaluated first:
when set, the result is every topic with `(underReplicatedPartitions ?? 0) + (leaderlessPartitions ?? 0) > 0`, ignoring
the internal/stream toggles; otherwise the existing pipeline runs. The flag is reset wherever `_topicFilter` is reset on
connect/disconnect and is never persisted. The sidebar shows an `InputChip` ("Only topics with unhealthy partitions
(n)") with a delete action above the list.

Contract for 5.33: its new filter pipeline (glob/regex, persisted switches, sorting, grouping) must keep this flag as
the first, transient stage that bypasses hide toggles, and keep the chip. Whichever change lands second wires the
flag into the other's code; the flag name and semantics above are fixed.

### D6 Per-tab `TopicFactsController`

`ChangeNotifier` created via `activeController.getTopicFactsController(key)` (same key and lifecycle as the stream
controller, disposed when the tab closes). It holds three independent async states, each `idle | loading | value |
error(notReadable?)`:

- `offsets`: result of 5.11's bridge `fetch_partition_offsets` → total span (from `offset_distribution`) or unknown if
  any partition failed;
- `configs`: result of `describe_topic_configs(profile, [topic])` → `retention.ms`, `retention.bytes`, and
  `cleanup.policy` when `TopicMetadata.cleanupPolicy` is null;
- `timeRange`: result of `fetch_topic_time_range`, only on user action.

Trigger: `TopicDetailView` listens to `activeController.activeTopic`; when its tab becomes active and `offsets`/`configs`
are `idle`, it calls `loadFacts()`. A header refresh icon button (tooltip + semantic label) reloads offsets and configs
and resets the time range to `idle`. Session-restored tabs that are never shown never load. If 5.11 introduces its own
per-dialog state, the dialog keeps it; the header does not share it (two small reads instead of a coupling).

### D7 Fixed values

`TAIL_WINDOW = 16` offsets, probe deadline 15 s, broker metadata timeout 10 s. Not configurable (no request for it).

### D8 Formatting

- `formatRetentionDuration(String raw, AppLocalizations l10n)`: `-1` → `retentionUnlimited`; not an integer → raw value;
  otherwise the two largest non-zero units of days/hours/minutes (ICU plurals `durationDays`, `durationHours`,
  `durationMinutes`); below one minute → seconds (`durationSeconds`); `0` → "0 minutes". Replaces `formatRetention` in
  the header and in `topic_list_item.dart` (the sidebar tooltip already takes the retention as a parameter).
- `retention.bytes`: `-1` → unlimited, else `TopicAnalysisSummaryCards.formatBytes` + localized "per partition".
- Estimate: `NumberFormat.decimalPattern(locale)` with the label "≈ n messages (estimate)".
- Timestamps: if 5.27/5.30 has introduced a shared message-timestamp formatter (global local/UTC mode with zone) by
  implementation time, use it; otherwise a small helper next to the header that formats with `DateFormatUtils` on
  `toUtc()`/`toLocal()` according to `TimeDisplaySettings` and appends `UTC` or the local offset.
- Partition/RF tags: new ARB keys `topicPartitionsTag` (plural) and `topicReplicationFactorTag`.

## Risks / Trade-offs

- [Brokers-only metadata behaves differently on some broker versions] → spike 1.1; documented fallback to the full
  metadata read.
- [Missing ACLs] → broker read denied: overview shows "not readable" with retry; `describe_topic_configs` denied:
  retention "not readable"; partition offsets denied (5.11 per-partition error): estimate unknown; probe on unreadable
  partition: counted unknown. Never 0, never "unlimited".
- [Unreachable broker] → each read fails on its own timeout (10 s / 15 s); inline error with retry; the overview's
  topic totals stay as loaded.
- [Compacted or transactional topics] → estimate carries the compaction note; newest timestamp may be unknown for
  partitions whose tail window holds only markers/aborted records, shown as partial, never guessed.
- [Empty topics] → `low == high` per partition → "no messages"; a topic whose partitions are all timed out is
  "unknown", not "empty".
- [Very large topics / many partitions] → probe cost is per partition, not per message; 1000 partitions × large
  batches can still transfer hundreds of MB → explicit action, partition count in the tooltip, 15 s deadline, capped
  prefetch memory.
- [Large payloads] → only timestamps are kept; payloads are dropped immediately after reading the timestamp, never
  decoded, logged or sent to Dart.
- [CreateTime not monotonic] → labels say "oldest/newest retained message", tooltip names partition/offset/type.
- [Overlap with 5.33 on `ActiveConnectionController.topics` and the sidebar] → D5 contract; second change to land
  rebases.
- [Overlap with 5.32 on `cluster_overview_view.dart`] → 5.32 owns "PLAINTEXT", "Available Topics", "Optional metadata
  registry"; if the topics card is rewritten here first, "Available Topics" is replaced by a localized label and its
  allowlist entry removed in the same commit.
- [`formatBytes` uses `.` as decimal separator in German] → accepted (existing helper, same as analysis view).

## Migration Plan

Additive only: new bridge functions and DTOs, new transient state, new ARB keys. No stored data changes. Rollback =
revert the change.

## Open Questions

- Whether the spike shows that `rd_kafka_controllerid` returns `-1` on KRaft clusters (KRaft reports a random broker as
  controller in Metadata v12+). If so, the controller row reads "unknown" there; no spec or task change needed.
