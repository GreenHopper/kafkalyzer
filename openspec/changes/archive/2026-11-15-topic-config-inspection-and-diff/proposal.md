# Proposal: topic-config-inspection-and-diff

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.10 (Phase 2a), guardrails §1 (L1–L5), finding
§2.2 ("Config-Diff: backend already supports `describe_configs`"), §2.4 B9, decisions E2/E14/E16, non-goals §7.

## Why

Users cannot see a topic's configuration in kafkalyzer. Only `cleanup.policy` and `retention.ms` are read, and only as
tags. Answering "why does this topic behave differently in PROD than in TEST?" means leaving the tool for the CLI.
Comparing the full configuration of two topics, in the same cluster or across two saved profiles, is the core
read-only diagnosis that is still missing. It needs only `DescribeConfigs`, which the recommended least-privilege
service account already has (`read-only-security-guidance`).

Verified against the current code (roadmap claims):
- Confirmed: `kafkalyzer-kafka/src/kafka_metadata.rs::fetch_topics` issues one `describe_configs` for all topics. It
  keeps only `retention.ms` and `cleanup.policy` (lines ~229–236) and drops source, default and sensitive flags. There
  is no bridge function for the full config list and no broker config read.
- Confirmed (scope of 5.33, unchanged here): a failed or denied describe is dropped silently
  (`if let Ok(configs)`). `kafka_analyzer.rs` (~1120–1137) assumes "not compacted" when its own describe fails.
- Changed since the roadmap: the function name `fetch_topic_configs` (§5.10) is replaced by the shared
  `describe_topic_configs`, which sibling change `topic-list-scale-and-organisation` (5.33) owns.

## What Changes

- New read-only Kafka function `describe_topic_configs(profile, topics)` → per-topic result (shared with 5.33; see
  Prerequisites). It returns every config entry with name, value, source and default/sensitive flags. Sensitive values
  are removed before they leave `kafkalyzer-kafka`. Per-topic failures are classified as *not authorized*,
  *topic not found* or *failed*.
- New pure module `kafkalyzer_core::topic_config`: config entry types and `diff_topic_configs`. Rows are sorted by
  name and classified (equal / different / only left / only right / not comparable / unknown). It has unit tests.
- New bridge module `rust/src/api/topic_config.rs`: `fetch_topic_config(profile, topic)` returns a snapshot that
  includes availability, so it never throws for "not readable". `diff_topic_configs(left, right)` is a sync, pure
  function.
- Topic detail view: a third mode **Configuration**, next to Messages and Analysis. It loads on first open and shows
  a stable name-sorted table: value, source and a default marker. Sensitive values show as hidden. A toggle shows
  only non-default entries. The view has refresh and retry.
- **Compare…**: pick a second topic in the same profile or in another saved profile. The default is the same topic
  name. The view shows a side-by-side diff with the toggle **only differences and non-defaults**. An unreadable side
  shows "not readable (missing DescribeConfigs permission?)" or its error, and its rows show as unknown, not as
  differences. Each side shows its environment tag and, if the profile skips TLS verification, its insecure badge.
- **Copy as text**: copies the visible diff or config list (respecting the toggle) to the clipboard. Sensitive values
  show as a placeholder. Export to a file is not included.

## Capabilities

### New Capabilities
- `topic-config-inspection`: read-only display of a topic's full configuration (value, source, default and
  sensitive flags, availability). Also comparison of two topics' configurations within one profile or across two
  saved profiles, with difference classification, filtering and text copy.

### Modified Capabilities
- none. `tls-verification` already requires that undecided profiles connect only with verification and that
  insecure profiles are flagged wherever shown. The comparison side follows those rules without a delta.

## Impact

- **Read-only impact:** one new read-only Kafka call path: `AdminClient::describe_configs` with
  `ResourceSpecifier::Topic(<topic>)`, one call per side, on demand only (opening the Configuration mode, Refresh,
  Compare). There are no new metadata, Schema Registry, broker-config or group calls. Nothing is cached across
  sessions. The CI gate already allows `describe_configs(` and passes unchanged; the change adds no exception.
- **Rust:** `kafkalyzer-core` (new `topic_config.rs`), `kafkalyzer-kafka` (`kafka_metadata.rs`:
  `describe_topic_configs` plus entry/error mapping, using the existing `kafka_consumer::shared_runtime()`), bridge
  (`rust/src/api/topic_config.rs`, `mod.rs`). Existing bridge signatures do not change (L3).
- **Dart:** new `TopicConfigService` (`lib/src/services/`), `TopicConfigController` and widgets under
  `lib/src/features/topic/presentation/`, `TopicViewMode.config` in `topic_detail_view.dart`, and en+de ARB keys.
  `KafkaMetadataService` stays unchanged, so its six test fakes need no update.
- **Generated:** `flutter_rust_bridge_codegen generate` and `dart run build_runner build` (bridge mocks).
- **Prerequisites:** none are blocking. If 5.33 `topic-list-scale-and-organisation` lands first, this change reuses
  its `describe_topic_configs`. Otherwise this change creates it with the contract in design.md D2, and 5.33 reuses
  it. Phase 0 (`restore-tls-verification`, `harden-local-storage-and-imports`) is already archived and supplies TLS
  handling and the keyring-backed profile list.
- **Unlocks:** `mcp-extended-tools` (`kafka_get_topic_config`) reuses `describe_topic_configs` and
  `diff_topic_configs`.

## Non-Goals

- Broker configuration (`ResourceSpecifier::Broker`) or cluster-wide defaults. This is an optional follow-up change
  that uses the same pattern (§5.10).
- Any config change, "apply this value to the other side" or generated `kafka-configs` commands (L1).
- Config synonyms, documentation text or value types; librdkafka 2.3 / rdkafka 0.36 do not provide them.
- Topic-list config loading, chunking and the config-availability flag in the list (5.33). Partition watermarks and
  topic facts (5.11, 5.34).
- File export of the diff, saved comparisons, or comparing more than two topics.
- Showing or comparing sensitive values in any form, including hashes.
- MCP tools (Phase 4).
