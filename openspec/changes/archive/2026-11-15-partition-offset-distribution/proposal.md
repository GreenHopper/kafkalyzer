# Proposal: partition-offset-distribution

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.11 (size S, Phase 2a). Follows guardrails L1–L5,
findings §2.4 (row "Skew anhand der bereits abgerufenen Watermarks"), decision E14 and the non-goals in §7.

## Why

Users today can only see partition skew after a full topic analysis scan (`topic-content-analysis`, exact). A quick,
scan-free estimate from the per-partition low/high watermarks answers "is one partition hot?" in one round trip. The
roadmap draft assumed the watermarks were already loaded; they are not: neither the topic list nor `PartitionRow`
carries any offsets (`rust/src/api/kafka_metadata.rs`), so a new on-demand read is needed. Because `high − low` is not a
message count on compacted or transactional topics, the result must be labelled as an estimate.

## What Changes

- New read-only Rust function `kafkalyzer_kafka::kafka_metadata::fetch_partition_offsets(profile, topic)`: reads the
  topic's partition list once and the low/high watermark of every partition with bounded concurrency and a per-call
  deadline. Each partition carries its own result (offsets or error, permission errors marked "not readable"). It is
  the shared building block for 5.34 (message-count estimate) and 5.37 (scan size estimate).
- New pure module `kafkalyzer_core::offset_distribution`: span per partition, total span, share per partition, and a
  skew check (share above a threshold, only with ≥ 2 partitions, all partitions readable and a non-empty topic).
  Unknown inputs stay unknown; nothing is guessed as 0.
- New bridge function `fetch_partition_offsets(profile, topic, skew_threshold_percent)` with additive DTOs. The
  existing `fetch_topic_partitions` / `PartitionRow` stay unchanged (deviation from the roadmap's "extend
  `PartitionRow`", see design D1).
- Partition health dialog (opened from the topic detail header) gets an "Offset distribution (estimate)" block: per
  row low watermark, high watermark, span and a share bar; a per-row error when that partition could not be read; a
  skew badge with icon and text; a note that offset spans are not message counts on compacted topics (or that the
  cleanup policy is unknown); and an action that opens the topic analysis for exact values. Watermarks load only when
  this dialog is opened or refreshed, never for the topic list or the analysis tab.
- New General setting "Partition skew threshold (%)", range 1–100, default 50.
- en + de strings for every new text.

## Capabilities

### New Capabilities

- None.

### Modified Capabilities

- `partition-health-visibility`: adds on-demand estimated offset distribution, the skew hint and the per-partition
  error/unknown handling.
- `ergonomic-settings-and-cluster-onboarding`: the numeric-settings range list and the General reset scenario gain the
  skew threshold.

## Impact

- **Read-only impact:** adds only read-only calls already used elsewhere in the app: one `fetch_metadata(topic)`
  (Metadata request) and one `fetch_watermarks(topic, partition)` per partition (two ListOffsets lookups for earliest
  and latest), on a `BaseConsumer` built by `create_config` with `enable.auto.commit=false`, no `assign()`, no
  `subscribe()`, no commit. No Admin client, no `describe_configs`, no Schema Registry call. The cleanup policy comes
  from the `TopicMetadata` the detail view already holds. `scripts/check_read_only.sh` must pass unchanged.
- **Code:** `rust/kafkalyzer-core/src/offset_distribution.rs` (new), `rust/kafkalyzer-core/src/lib.rs`,
  `rust/kafkalyzer-kafka/src/kafka_metadata.rs`, `rust/src/api/kafka_metadata.rs`, regenerated
  `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart`, `lib/src/services/kafka_metadata_service.dart`,
  `lib/src/services/settings_service.dart`, `lib/src/features/settings/presentation/settings_view.dart`,
  `lib/src/features/topic/presentation/widgets/topic_partition_health_dialog.dart`, new
  `lib/src/features/topic/presentation/widgets/partition_offset_distribution_view.dart`,
  `lib/src/features/topic/topic_detail_view.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, tests.
- **Dependencies:** none new.
- **Prerequisites:** none hard. Phase 0/1 are archived. Soft ordering: if `accessibility-and-l10n-sweep` lands first,
  the new widget follows its status-colour mapping (warning = `tertiary`) and passes its hard-coded-string guard
  (`test/l10n/hardcoded_strings_guard_test.dart`, already in the tree). If `topic-list-scale-and-organisation` (5.33)
  makes configs lazy, `TopicMetadata.cleanupPolicy` may be `null` more often; this change already shows "cleanup policy
  unknown" for that case.
- **Consumers of the new API:** `cluster-overview-and-topic-facts` (5.34) and `analysis-scope-and-history` (5.37)
  reuse `fetch_partition_offsets`; 5.34 adds timestamps itself.

## Non-Goals

- Watermarks or skew in the topic list or sidebar (roadmap: detail view only).
- Exact per-partition message counts or byte sizes: those stay with the analysis scan (`topic-content-analysis`,
  Partition Utilization and Balance Analysis); no duplicate of that requirement.
- Message-count estimate, oldest/newest timestamps and `retention.bytes` in the topic header (5.34).
- Scan size confirmation before analysis (5.37).
- Fetching `cleanup.policy` or other configs (5.33 / 5.10 own `describe_topic_configs`).
- Changes to the analysis tab's partition health card or `PartitionBalanceView`.
- Persisting offset snapshots, history or trends; any write call (L1).
