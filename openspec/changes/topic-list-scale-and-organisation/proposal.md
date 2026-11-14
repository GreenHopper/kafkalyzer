# Proposal

## Why

The Explorer topic list is the entry point of every session, and it does not scale and hides failures
(roadmap `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.33, findings B7, B8, B9). Checked against the
current code:

- `fetch_topics` (`rust/kafkalyzer-kafka/src/kafka_metadata.rs:181-279`) sends one `describe_configs` for all topics
  with a 10 s operation timeout. If that call fails, `if let Ok(configs)` has no `else`: every retention and cleanup
  tag disappears without a notice (B9). rdkafka 0.36.2 also drops per-topic errors of `describe_configs`; a denied
  topic comes back with no entries. Topics whose metadata has an error are skipped (`if topic_meta.error().is_none()`).
- The topic analysis does its own `describe_configs` and treats an unreadable `cleanup.policy` as "delete"
  (`kafka_analyzer.rs:1120-1139`); the summary card then shows a `delete` badge as a fact (B9).
- `ActiveConnectionController.topics` filters the whole list again on every access. The sidebar calls it in the
  header and in every `itemBuilder` call (`explorer_view.dart:600,725,769,777,779,791`), so building the list costs
  O(N) per row.
- Names ending in `-topic` count as Kafka Streams topics and are hidden by default
  (`active_connection_controller.dart:87-97`, B8). The two filter switches are not saved.
- Opening a recent topic or a topic from the cluster overview that is not in the loaded list creates made-up
  metadata (0 partitions, RF 1, `delete`, retention `0`) that the header shows as fact (`explorer_view.dart:904-913`,
  `938-947`, B7). Quick Jump and the DLQ "jump to original" look the topic up in the *filtered* list and silently do
  nothing when a filter hides it (`quick_jump_dialog.dart:168`, `message_inspector_panel.dart:1043`).
- Refresh is disabled while the Schema Registry loads (`explorer_view.dart:619-637`). During a refresh the whole list
  is replaced by a spinner, and a failed refresh with a cached list shows no error at all (`explorer_view.dart:718-725`).
- The list has no sorting, grouping, favourites, age indicator or pattern filter.

## What Changes

- The topic list loads from cluster metadata only. Configurations load afterwards in background chunks, and the
  opened topic's configuration loads first.
- New read-only Rust function `describe_topic_configs(profile, topics)` returns one result per topic: all entries with
  source, default, sensitive and read-only flags, or "not readable" / "failed" with the reason. Sensitive values are
  never returned. 5.10 `topic-config-inspection-and-diff` reuses this function for its full config view and diff.
- `fetch_topics` keeps its signature. It no longer calls `describe_configs`, and it returns topics with metadata
  errors marked by a new optional `metadata_error` (kind: not authorized / not found / other, plus a message) instead
  of skipping them.
- New `fetch_topic_metadata(profile, topic)` loads one topic by name when that topic is not in the loaded list.
- Recents, cluster overview, Quick Jump and DLQ jump open topics by name. No made-up metadata is shown. Unknown
  values show as unknown, and errors show as "not readable — permission?" or "topic not found".
- The sidebar shows the list's age ("updated n min ago"). Refresh works independently of the Schema Registry, keeps
  the old list visible while it loads, and shows a failed refresh inline with Retry.
- Filter modes: substring (default), glob and regex. An invalid pattern shows an inline error. Matches are
  highlighted in substring and regex mode.
- The filter switches (internal, Kafka Streams), filter mode, sort order, prefix grouping and favourites are saved per
  cluster. The sidebar shows how many topics the filters hide.
- **BREAKING (behaviour)**: names ending in `-topic` no longer count as Kafka Streams topics. Only `-changelog` and
  `-repartition` do, so these topics become visible by default.
- Sorting by name, partition count or health; optional grouping by name prefix; favourites pinned on top.
- Unreadable or failed configuration shows in the tooltip and topic header instead of disappearing.
- The topic analysis reports "cleanup policy unknown" instead of assuming "delete" when the configuration cannot be
  read (additive report field; older saved reports load unchanged).
- The filtered, sorted and grouped list is computed once per input change. Measured targets for 10 000 topics are in
  the specs and tasks.

## Capabilities

### New Capabilities

None. 5.10 creates the capability `topic-config-inspection`. This change adds only the shared Rust function and the
sidebar or header use of it.

### Modified Capabilities

- `compact-topic-sidebar`: tooltip shows unknown, loading and not-readable configuration states. Filter controls get
  modes, saved per-cluster switches, a hidden count and the narrower Kafka Streams rule. Highlighting covers substring
  and regex mode. New requirements cover metadata-first loading with chunked configurations, list age and refresh,
  sort, prefix grouping, favourites, not-readable topics, list performance and read-only loading.
- `explorer-onboarding`: new requirement for opening a topic that is not in the loaded list (recents, cluster
  overview, Quick Jump, DLQ jump) without placeholder metadata. "Load Failure Error States in Explorer" now covers a
  failed refresh while an earlier list is still shown.
- `topic-content-analysis`: "Tombstone Detection and Compaction Analysis" reports an unknown cleanup policy when the
  configuration cannot be read.

`dead-letter-queue-detection` is unchanged. Failure-topic badges and sub-trees keep working inside sorted and
grouped lists. This is covered by a scenario in `compact-topic-sidebar`.

## Impact

- **Read-only impact**: no new kind of Kafka access and no Schema Registry calls. Added read-only calls are
  `AdminClient::describe_configs` on `ResourceSpecifier::Topic` in chunks (`describe_topic_configs`) and a
  single-topic metadata request (`fetch_metadata(Some(topic))` in `fetch_topic_metadata`, same as the existing
  `fetch_topic_partitions`). Removed: the all-topics `describe_configs` inside `fetch_topics` and the inline one in
  the analyzer, which now uses `describe_topic_configs`. `scripts/check_read_only.sh` must pass unchanged.
- **Rust**: `kafkalyzer-kafka/src/kafka_metadata.rs` (`fetch_topics`, new `describe_topic_configs`,
  `fetch_topic_metadata`), `kafka_analyzer.rs` (cleanup policy via `describe_topic_configs`, new report flag).
  `kafkalyzer-core` is unchanged; the new logic is error classification and entry mapping of rdkafka types, so it
  stays in the I/O crate.
- **Bridge** (additive): `rust/src/api/kafka_metadata.rs` adds `TopicMetadata.metadata_error`, the
  `TopicConfigResult` and `TopicConfigEntry` DTOs and two functions. `rust/src/api/kafka_types.rs` adds
  `TopicAnalysisReport.cleanup_policy_unknown` with `#[serde(default)]`. Regenerate the bridge and mocks.
- **Dart**: `TopicController` (fetch time, config map, chunk loader, by-name lookup, single-topic resolve),
  `ActiveConnectionController` (memoised list view, per-cluster preferences, open by name), a new pure topic-list
  query (filter, sort, group), a new per-cluster preferences service, `explorer_view.dart`, `topic_list_item.dart`,
  `topic_detail_view.dart`, `quick_jump_dialog.dart`, `message_inspector_panel.dart`,
  `topic_analysis_summary_cards.dart`, `topic_analysis_report_file.dart`, en and de ARB.
- **Stored data**: new SharedPreferences key per cluster. Existing keys are untouched.
- **Prerequisites**: none functionally. `accessibility-and-l10n-sweep` (in progress) edits `explorer_view.dart`,
  `topic_list_item.dart` and `cluster_overview_view.dart`, so land it first or rebase onto it. New strings must pass
  its `test/l10n/hardcoded_strings_guard_test.dart`.
- **Interaction with Phase 2 siblings**: 5.10 reuses `describe_topic_configs`. 5.34 and 5.35 may also modify
  `explorer-onboarding` and the sidebar tooltip's schema indicator; this change does not touch the "Cluster Overview
  Dashboard Empty State" requirement.

## Non-goals

- Full configuration view or diff and broker configs (5.10). Watermarks or offset distribution in the list (5.11).
  Broker or cluster facts (5.34). Schema type in the tooltip (5.35).
- Listing topics the broker hides: an all-topics metadata request only returns topics the principal may describe.
  Such topics appear only when opened by name.
- Server-side filtering, user-defined prefix separators, nested prefix trees, syncing favourites across machines, and
  moving per-cluster preferences when a profile is renamed (same as the existing per-cluster session tabs).
- Any write call (§7, L1). No new navigation destination (L6).
