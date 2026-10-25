# Proposal

## Why

`design/feature-gap-analysis.md` §4 (B1–B5) lists five observability gaps that all share one property: the answer is already inside data kafkalyzer receives, and is thrown away before it reaches the UI. That blocks the most common production questions.

1. Partition health: `grep "leader\|isr"` over the Rust crates returns zero hits. rdkafka already delivers leader, replica set and ISR in every metadata response, so "which broker is missing, which partition is under-replicated" cannot be answered at all today.
2. Consumer group members: `parse_member_subscription` / `parse_member_assignment` (`rust/kafkalyzer-kafka/src/kafka_metadata.rs:117/154`) already decode the member bytes, but the result is reduced to topic name lists plus `members_count`. "Which client holds this partition" is the most frequent follow-up question after a lag number.
3. Schema origin per message: the wire-format schema id is read during decoding (`rust/kafkalyzer-kafka/src/kafka_consumer.rs:1266` and `:1333`) and the registered schema (subject, version) is fetched and cached, but neither value is attached to `KafkaMessage`. Whether a consumer reads an outdated schema is invisible.
4. Report statistics: `TopicAnalysisReport` (`rust/kafkalyzer-core/src/kafka_types.rs:128`) carries only `min_message_size`, `max_message_size`, `avg_message_size`. The average hides the outliers that cause producer-side buffer and fetch problems, and two reports can never be compared, so "what changed since yesterday" needs a manual re-scan.
5. Lag trend: `ConsumerGroupLag` is a snapshot; the UI shows the current number plus a delta badge. A single lag value cannot distinguish a growing backlog from a transient fetch skew.

Doing these together is efficient: B1/B2 extend the same metadata call path and its bridge types, B3 extends the decode path that already resolves schemas, and B4/B5 extend the two aggregation structures that already exist.

## What Changes

- Topic metadata gains per-partition health data: leader, replica ids, ISR ids, and derived per-topic counts of under-replicated and leaderless partitions, surfaced in the topic list and topic detail view.
- Consumer group detail gains member rows: member client id, client host, and the topic-partitions assigned to that member, replacing the current topic-list-plus-count reduction.
- Each consumed message gains schema provenance (registry subject, version, schema id, per key and value side) shown in the message inspector metadata header, with a one-click jump into the existing schema inspector for that subject/version.
- The analysis report gains p50/p95/p99 message size and an estimated distinct-key count, and two reports (live vs imported, or two imported files) can be compared side by side with per-metric deltas.
- Consumer lag gains a per-group trend (last N lag samples per group and per partition table) with a configurable warning threshold that highlights groups above it.
- Read-only guarantee is unchanged and extended: only additional metadata reads (`Metadata`, `describe_configs`) and consumer reads; still no producer, no commit, no `subscribe()`, no admin write.

No breaking API change for stored artifacts: the analysis report file gains optional fields and keeps its format version readable, so reports written by the current version still import.

## Capabilities

### New Capabilities

- `partition-health-visibility`: per-partition leader/replica/ISR metadata and the derived under-replicated / leaderless health state shown for topics.
- `consumer-group-member-insights`: identity of consumer group members (client id, host) and their assigned topic-partitions.
- `message-schema-provenance`: which Schema Registry subject, version and schema id a specific message key/value was encoded with, and navigation from a message to that schema.
- `topic-report-comparison`: comparison of two topic analysis reports with per-metric deltas.
- `consumer-lag-trend`: retention and display of recent lag samples per consumer group, plus a configurable warning threshold.

### Modified Capabilities

- `topic-content-analysis`: "Topic Message Volume and Size Aggregation" additionally reports p50/p95/p99 message size; "Message Key Frequency Analysis" additionally reports the estimated number of distinct keys.
- `integrated-schema-inspector`: the inspector can be opened directly for an explicit subject and version selected from a message, not only for the topic-level schema.

## Impact

**Rust**
- `rust/kafkalyzer-kafka/src/kafka_metadata.rs`: read partition metadata (leader/replicas/ISR) from the existing metadata response; keep member subscription/assignment parsing but retain partition and member identity instead of discarding it.
- `rust/kafkalyzer-kafka/src/kafka_consumer.rs`: attach schema subject/version/id to `KafkaMessage` in the decode path without extra registry round-trips (cache only, no per-message blocking lookup).
- `rust/kafkalyzer-kafka/src/kafka_analyzer.rs` + `rust/kafkalyzer-core/src/kafka_types.rs`: new report fields; percentiles and distinct-key estimate computed from a bounded sample/counter structure in `kafkalyzer-core` so the math is unit-testable without rdkafka.
- Bridge (`rust/src/api/kafka_metadata.rs`, `rust/src/api/kafka_types.rs`): new bridge-local types (partition metadata/health, group member, message schema origin) mapped at the boundary, plus `flutter_rust_bridge` regeneration and regenerated Dart mocks.

**Dart**
- Topic surface: `lib/src/features/explorer/presentation/explorer_view.dart`, `lib/src/features/topic/presentation/widgets/topic_list_item.dart`, `lib/src/features/topic/topic_detail_view.dart`.
- Consumer surface: `lib/src/features/consumer/presentation/consumer_lag_view.dart`, `group_details_view.dart`, `topic_partition_table.dart` and the badges in `widgets/` (trend reuses the existing badge/KPI patterns).
- Message surface: `lib/src/ui/messages/widgets/message_metadata_card.dart` and the inspector shell header; schema inspector entry points in the integrated inspector.
- Analysis surface: `lib/src/features/topic/presentation/widgets/analysis/` plus `lib/src/features/topic/data/topic_analysis_report_file.dart` for the new optional fields and the comparison view.

**Cross-cutting**
- New localized strings in `lib/l10n/app_en.arb` / `app_de.arb` (identical key counts); no hard-coded UI text.
- No new Dart or Rust dependencies; percentile and estimation helpers are hand-rolled in `kafkalyzer-core`.
- Settings: one new numeric setting for the lag warning threshold.
