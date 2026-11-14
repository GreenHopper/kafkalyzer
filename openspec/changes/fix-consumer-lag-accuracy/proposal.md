# Proposal

## Why

The Consumer Lag view reports a stopped consumer group (state `Empty`) as "no lag", which is exactly the case users
open the view for (roadmap `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.24, findings B1 and B2 in §2.4).
Several other code paths also turn "not known" into 0 or drop data silently, so lag values, sorting and the total-lag
KPI cannot be trusted today.

Findings verified in the code:

- **B1** `rust/kafkalyzer-kafka/src/kafka_metadata.rs`: members, and therefore the group's topics, are only read when
  the state is `Stable` (`fetch_consumer_lags`, `fetch_consumer_groups`, `fetch_consumer_group_lag`). A member-less
  group gets no topics, no partitions, and an empty `partition_lags` list, which the UI sums to 0.
- **B1** Partitions whose committed offset is not `rdkafka::Offset::Offset(_)` (no commit) are dropped; partitions
  whose watermark fetch fails are dropped; topics whose metadata fetch fails are dropped. In `fetch_consumer_lags`, a
  failing group consumer or `committed_offsets` call removes the whole group from the result (`continue`).
- `unassigned_partitions` reports every partition of a topic as "without owner" when a member's assignment bytes could
  not be decoded; the existing unit test `member_without_a_decodable_assignment_is_marked` currently asserts this
  false positive.
- The per-group consumer used for `committed_offsets` is built from `create_config` with `group.id` set but without
  `enable.auto.commit=false`, unlike the other consumers in `kafkalyzer-kafka`.
- **B2** `lib/src/features/consumer/presentation/consumer_lag_view.dart`: lag is loaded lazily per row from the list
  `itemBuilder`; `_calculateGroupLag` returns 0 for groups not loaded yet, so sort-by-lag and the "Total Lag" KPI only
  reflect rows that were scrolled into view.
- The periodic refresh (`Timer.periodic` → `_fetchLags`) starts a new cycle while the previous one is still running,
  and a failed per-group query only records the group id; the error text is discarded and the badge shows a hard-coded
  "Error".

## What Changes

- Lag of a group without active members is computed from its committed offsets; when the committed offsets cannot be
  read, the lag is shown as **unknown**, never as 0.
- Partitions without a committed offset are listed and marked "no commit"; partitions whose log-end offset or topic
  metadata cannot be read are listed as "unknown" with the reason. Neither contributes a made-up value to a total.
- A group whose committed offsets cannot be read stays in the result with its error; it is never omitted.
- Sorting by lag and the "Total Lag" KPI load all listed groups in the background (respecting the existing concurrency
  setting) and show "n of m loaded" until complete; groups without a known lag are never ranked or summed as 0.
- A refresh cycle does not start while the previous one is still running; results of an outdated cycle are discarded.
- The error of each failed group stays retrievable from the group row and the group details, with a retry action.
- "Partition without owner" is not reported when a member's assignment could not be decoded, and not for a group
  without members; instead the group states that ownership cannot be determined.
- Members are reported for every group state the cluster returns them for, not only for `Stable`.
- A batched bridge call returns lag for a list of groups with one shared client and a shared metadata and watermark
  cache; one group's failure does not fail the batch. The existing three lag functions keep their signatures.
- Bridge DTOs are extended additively (per-partition offset status and error, per-group lag error and ownership
  completeness flag); no existing field changes type.
- A spike runs first to decide how committed offsets of a member-less group are listed read-only with rdkafka 0.36.2 /
  librdkafka 2.3.0.

Non-goals (owned by other changes): lag as time, topic-name filter, additional state filters, export, rebalance or
membership-change markers (`consumer-lag-insights`, §5.38); moving polling into a view-independent controller and stall
alerts (`lag-stall-detection-and-alerts`, §5.13); persistent lag history (E17); localising the existing hard-coded
KPI texts (`accessibility-and-l10n-sweep`, §5.32); any change to `scripts/check_read_only.sh` (`harden-read-only-gate`,
§5.1).

Prerequisites: none. `consumer-lag-insights` (§5.38) builds on this change.

## Read-Only Impact

No new kind of Kafka request and no Schema Registry calls. Lag reading keeps using: group listing/description
(`fetch_group_list`), topic metadata, committed-offset reads (OffsetFetch) and watermark reads (ListOffsets). Depending
on the spike, committed offsets of a member-less group are read either via librdkafka's
`rd_kafka_ListConsumerGroupOffsets` admin call (an OffsetFetch, read-only) or via `committed_offsets` over a bounded
partition set. The consumer that reads committed offsets is configured with `enable.auto.commit=false` and never
subscribes, assigns or commits, so it does not join the group. `scripts/check_read_only.sh` must pass unchanged; no new
exception is requested.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `consumer-lag-monitoring`: lag display distinguishes known lag, "no commit" and "unknown"; member-less groups get lag
  from committed offsets; aggregates and sorting over groups are complete or marked partial; refresh cycles do not
  overlap; per-group errors stay retrievable; lag reading stays read-only.
- `consumer-group-member-insights`: members are reported in every state the cluster returns them for; unassigned
  partitions are not reported when ownership cannot be determined (undecodable assignment, no members).

## Impact

- `rust/kafkalyzer-core/src/kafka_types.rs`: additive fields on `TopicPartitionLag` / `ConsumerGroupLag`, new offset
  status enum; pure aggregation helper (group total: known / partial / unknown) with unit tests.
- `rust/kafkalyzer-kafka/src/kafka_metadata.rs`: shared lag implementation for the three existing entry points plus a
  batched one; member collection in all states; unassigned computation; explicit `enable.auto.commit=false`;
  committed-offset listing for member-less groups per spike outcome (may add an `unsafe` FFI wrapper over
  `rdkafka-sys` 4.7.0).
- `rust/src/api/kafka_metadata.rs`, `rust/src/api/kafka_types.rs`: new batched bridge function, additive DTO fields;
  regenerated `lib/src/rust/` bindings and `test/src/rust/api/rust_mocks.mocks.dart`.
- `lib/src/features/consumer/presentation/`: `consumer_lag_view.dart`, `group_details_view.dart`,
  `topic_partition_table.dart`, `widgets/group_lag_badge.dart`; `lib/src/services/kafka_metadata_service.dart`.
- `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`: new strings (unknown, no commit, n of m loaded, error details,
  ownership unknown).
- Tests: Rust unit tests in `kafkalyzer-core` and `kafkalyzer-kafka`; widget tests in
  `test/src/features/consumer/presentation/consumer_lag_view_test.dart`; a manual check against `docker-compose.yaml`.
