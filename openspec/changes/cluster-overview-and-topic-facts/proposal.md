# Proposal: cluster-overview-and-topic-facts

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.34 (size M, Phase 2a, uses 5.11). Follows guardrails
L1–L6, finding §2.4 C ("Cluster-Übersicht ohne Broker-Angaben"), decisions E14 and E16, and the non-goals in §7.

## Why

With a cluster connected and no topic open, the Explorer shows only the profile name, bootstrap address, a topic count
and whether a Schema Registry URL is configured (`cluster_overview_view.dart`). It does not answer the first questions of
a diagnosis: which brokers answer, how big is the cluster, are any partitions under-replicated or leaderless. The topic
header shows partitions, RF, cleanup policy and `retention.ms` as an unlocalized "x.x days"/"x.x hrs" string
(`topic_utils.dart` `formatRetention`), but not how many messages the topic roughly holds, how old its data is, or
`retention.bytes`. The per-topic health counts already exist in the topic list; the cluster-wide view and the drill-down
are missing.

## What Changes

- **Cluster overview** (Explorer, no topic tab open; E16, no new navigation destination):
  - broker list with id, host and port, from one new read-only metadata read;
  - cluster id and controller broker id, shown only when the broker returned them; otherwise the rows are absent
    (cluster id) or shown as "unknown" (controller). Broker version is not shown: librdkafka 2.3 / rdkafka 0.36 expose
    no broker version to clients (see design D2);
  - totals of topics and partitions from the already loaded topic list;
  - count of topics with under-replicated or leaderless partitions, and a separate count of topics whose health is
    unknown; activating the unhealthy count opens the topic list filtered to those topics (drill-down hook, design D5);
  - refresh action, loading state, inline error state with retry for the broker read; a failed or still loading topic
    list is shown as unknown, never as "0 Topics" (today it shows "0 Topics" after a failed load).
- **Topic header facts**:
  - estimated message count = sum of offset spans from 5.11's `fetch_partition_offsets`, labelled as an estimate, with
    the compacted-topic note; loaded when the tab first becomes visible, not for restored background tabs;
  - oldest and newest retained message timestamps, read on demand ("Load time range") by a bounded probe that reads the
    first message from the low watermark and the last message of a small tail window per partition, ending on
    `PartitionEOF` and a deadline; partial results are labelled;
  - `retention.ms` as localized days/hours/minutes (also used by the sidebar tooltip) and `retention.bytes` as a
    human-readable size "per partition", read with 5.33's `describe_topic_configs`; "unlimited" for `-1`, "not readable"
    on denied access, "unknown" while missing;
  - the "N Partitions" and "RF: n" tags become localized (they are touched by the header rework and are missed by the
    l10n guard because `TopicTag` takes a positional string).
- en + de strings for every new text.

## Capabilities

### New Capabilities

- `topic-header-facts`: estimated message count, oldest/newest retained message timestamps and retention settings in
  the topic detail header, including the bounded read-only time-range probe and unknown/error handling.

### Modified Capabilities

- `explorer-onboarding`: requirement *Cluster Overview Dashboard Empty State* gains brokers, cluster identity, topic and
  partition totals, the unhealthy-topic count, refresh and error/unknown states.
- `partition-health-visibility`: adds a cluster-wide replication health summary and the "only unhealthy topics"
  topic-list filter reached from it.

Deviation from roadmap: §5.34 lists only `explorer-onboarding` and `partition-health-visibility`. The topic header facts
are neither onboarding nor replication health, so they get the new capability `topic-header-facts` instead of being
forced into one of the two.

## Impact

- **Read-only impact** (exact new calls; all on clients built by `create_config`, no producer, no commit, no
  `subscribe()`, no Admin write call; `scripts/check_read_only.sh` must pass unchanged):
  - cluster overview: one Metadata request without topic list (brokers, cluster id, controller id) via librdkafka's
    `rd_kafka_metadata` (`all_topics=0`), plus `rd_kafka_clusterid` / `rd_kafka_controllerid`, which read the cached
    response; fallback to `fetch_metadata(None)` if the spike disproves the brokers-only request (design D1);
  - topic facts: 5.11's `fetch_partition_offsets` (Metadata for one topic + ListOffsets per partition) and 5.33's
    `describe_topic_configs(profile, [topic])` (DescribeConfigs) — both reused, not new;
  - time range (on demand only): a `BaseConsumer` with manual `assign()`, `enable.auto.commit=false`,
    `enable.auto.offset.store=false`, `enable.partition.eof=true`, small fetch sizes and capped
    `queued.max.messages.kbytes`; at most one record batch at the low watermark and a 16-offset tail window per
    partition are fetched (design D3). No Schema Registry call.
- **Code:** `rust/kafkalyzer-core/src/topic_time_range.rs` (new), `rust/kafkalyzer-core/src/lib.rs`,
  `rust/kafkalyzer-kafka/src/kafka_metadata.rs` (`fetch_cluster_overview`), new
  `rust/kafkalyzer-kafka/src/topic_time_range.rs` (`fetch_topic_time_range`), `rust/kafkalyzer-kafka/src/lib.rs`,
  `rust/src/api/kafka_metadata.rs`, regenerated `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart`,
  `lib/src/services/kafka_metadata_service.dart`, new `ClusterOverviewController` and `TopicFactsController`,
  `lib/src/features/explorer/presentation/widgets/cluster_overview_view.dart`,
  `lib/src/features/explorer/presentation/explorer_view.dart`,
  `lib/src/features/cluster/presentation/controllers/active_connection_controller.dart` (health filter hook),
  `lib/src/features/topic/topic_detail_view.dart`, `lib/src/features/topic/topic_utils.dart`,
  `lib/src/features/topic/presentation/widgets/topic_list_item.dart`, `lib/src/dependency_injection.dart`,
  `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, tests.
- **Dependencies:** no new crate or package. `rdkafka-sys` (already a direct dependency) for the brokers-only metadata
  call and `rd_kafka_controllerid`.
- **Prerequisites:** `partition-offset-distribution` (5.11, `fetch_partition_offsets` + `kafkalyzer_core::
  offset_distribution`) must be implemented first. `topic-list-scale-and-organisation` (5.33, `describe_topic_configs`)
  should be implemented first; if it is not, this change creates `describe_topic_configs(profile, topics) -> per-topic
  Result` exactly as 5.33 specifies and 5.33 adopts it. Soft: `accessibility-and-l10n-sweep` (guard test and status
  colours; it owns the three remaining overview literals "PLAINTEXT", "Available Topics", "Optional metadata
  registry").

## Non-Goals

- Broker version, rack, broker configs, ACL listing, controller/KRaft quorum details (not readable or not asked).
- Watermarks, estimates or timestamps in the topic list or sidebar; per-partition offset table (5.11).
- Full topic configuration view and config diff (5.10); lazy config loading of the topic list, list sorting/grouping,
  persisted filter switches (5.33). The health drill-down filter is transient and not persisted.
- Exact message counts (stay with the topic analysis scan, `topic-content-analysis`).
- Automatic time-range probing on tab open, background refresh, history of any value.
- Any write call against Kafka or the Schema Registry (L1); a fifth navigation destination (E16).
