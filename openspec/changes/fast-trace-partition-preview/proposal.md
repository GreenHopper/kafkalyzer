# Proposal

## Why

Fast Trace narrows a topic search to the single partition the message key hashes to, but the user never sees which
partition that is or what the hash assumes. When the producer used a different partitioner (librdkafka's default
`consistent_random`/CRC32, a custom partitioner) or a binary key serializer, the scan silently reads the wrong
partition and reports "no messages" — a misleading empty result. Roadmap
`design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.6 (`fast-trace-partition-preview`, size S, Phase 1b).

## What Changes

- With Fast Trace active, the topic search bar shows the computed target partition before the scan starts
  (e.g. "Partition 3 of 12"), both in the expanded advanced panel and in the collapsed Fast Trace chip.
- The preview names its assumption (Java default partitioner: `murmur2` over the UTF-8 bytes of the key text, modulo
  the partition count from the loaded topic metadata) and warns that other partitioners (librdkafka
  `consistent`/CRC32 default, custom partitioners), binary or serialized keys (e.g. Avro keys with the Confluent wire
  prefix) and later partition increases make the real partition differ.
- Unknown or placeholder metadata (partition count `0`) shows "partition count unknown" instead of a number; an empty
  key shows no partition.
- Single source of truth: the partition formula moves into `kafkalyzer-core` (`partitioner` module with `murmur2`,
  `to_positive` and `default_partition`). The scan (`resolve_target_partitions`) and a new bridge function
  `predict_default_partition(key, partition_count)` both call it, so the preview cannot drift from the scan. The
  existing bridge functions `murmur2`/`to_positive` keep their signatures.
- The key the preview hashes is derived exactly like the key the scan receives (first non-empty, trimmed,
  comma-separated filter term) through one shared Dart helper; with several terms the preview notes that only the
  first one selects the partition.
- The script step editor's Fast Trace switch gets the same assumption text as a tooltip; it shows no computed
  partition (see Non-goals).

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `search-configuration-panel`: ADDED requirement *Fast Trace Target Partition Preview* (computed partition, stated
  assumption and caveats, unknown/empty handling, parity with the scan).

## Impact

- **Rust:** new `rust/kafkalyzer-core/src/partitioner.rs` (moved `murmur2`/`to_positive` + `default_partition`, unit
  tests with Kafka's reference vectors); `rust/kafkalyzer-kafka/src/kafka_utils.rs` re-exports them;
  `rust/kafkalyzer-kafka/src/kafka_consumer.rs::resolve_target_partitions` calls `default_partition`;
  `rust/src/api/kafka_utils.rs` adds `predict_default_partition`. Bridge regeneration and mock regeneration required.
- **Dart:** `lib/src/features/search/presentation/widgets/topic_search_bar.dart` (preview, chip, localized Fast Trace
  label), `lib/src/features/topic/topic_detail_view.dart` (passes `topic.partitionCount`, uses the key helper),
  `lib/src/features/search/presentation/widgets/search_stream_configuration.dart` (tooltip), new small helper under
  `lib/src/features/search/domain/`, `lib/l10n/app_en.arb` + `app_de.arb`.
- **Read-only impact:** no new Kafka or Schema Registry calls. The preview is pure computation on already loaded
  metadata; `scripts/check_read_only.sh` must pass unchanged.
- **Prerequisites:** none hard. Sequence after `app-diagnostics-and-error-reporting` task 2.2, which rewrites the
  Fast Trace log line in `resolve_target_partitions` (drops the key); whichever lands second keeps that line keyless.
  `restore-tls-verification` also edits `kafka_utils.rs` (`create_config`) — expect a trivial merge only.
- **Non-goals:** computed partition in the script step editor (key is a template resolved at run time, several topics,
  no partition counts loaded there); support for other partitioners or for binary/serialized keys; changing Fast
  Trace scan semantics (e.g. scanning all partitions for several keys); fixing placeholder topic metadata (roadmap
  5.33); a live metadata refresh for the preview.
