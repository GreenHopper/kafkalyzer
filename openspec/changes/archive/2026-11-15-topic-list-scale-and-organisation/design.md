# Design

## Context

Motivation and the checked findings are in `proposal.md` (Why). Facts that shape the approach:

- `kafkalyzer_kafka::kafka_metadata::fetch_topics` (`kafka_metadata.rs:181`) does a `BaseConsumer::fetch_metadata(None,
  10 s)`. It then creates a new Tokio `Runtime` and an `AdminClient` and sends one `describe_configs` for every topic.
  It extracts only `retention.ms` and `cleanup.policy`, skips topics with `topic_meta.error()`, and sorts by name.
- rdkafka is pinned to 0.36.2 (`rdkafka-sys =4.7.0`, librdkafka 2.3.0). Its `DescribeConfigsFuture` never reads
  `rd_kafka_ConfigResource_error`: a per-topic error comes back as `Ok(ConfigResource)` with an empty `entries` list.
  Only a request-level error (`event.check_error()`) becomes `Err(KafkaError::AdminOp(code))`. `ConfigEntry` has
  `value`, `source` (`ConfigSource::{Unknown, DynamicTopic, DynamicBroker, DynamicDefaultBroker, StaticBroker,
  Default}`), `is_read_only`, `is_default` and `is_sensitive`.
- An all-topics metadata request only returns topics the principal may describe. A single-topic request returns the
  topic with `TOPIC_AUTHORIZATION_FAILED` or `UNKNOWN_TOPIC_OR_PART`. The librdkafka consumer default
  `allow.auto.create.topics=false` applies (`create_config` refuses to set it through extra properties,
  `kafka_utils.rs:484`), so a by-name lookup does not create topics. Spike 1.1 confirms this.
- `kafka_analyzer.rs:1120-1139` does its own `describe_configs` with a 3 s timeout and defaults `is_compacted=false`.
  `TopicAnalysisReport` (`rust/src/api/kafka_types.rs:592`) is `Serialize/Deserialize` without `default`. The Dart
  report file maps keys by hand (`topic_analysis_report_file.dart:156,190`).
- Dart: `TopicController` (cache, `_isLoading`, `_errors` per cluster name; from 5.23) is the only caller of
  `fetchTopics` besides the script step editor. `ActiveConnectionController.topics` recomputes the filtered list on
  every read. `isConnecting` also returns true while the topic list loads, so the sidebar replaces the list with a
  spinner during a refresh. Per-cluster preferences follow the `cluster_session_tabs_<name>` pattern
  (`session_restore_service.dart:60`). `stored_list.dart` (from 5.22) provides `writeStoreBackup`.
- The bridge `TopicMetadata` constructor takes `Option` fields as optional named parameters
  (`lib/src/rust/api/kafka_metadata.dart:161`). An additive `Option` field therefore keeps every existing Dart
  constructor call compiling.
- `test/l10n/hardcoded_strings_guard_test.dart` and `arb_consistency_test.dart` (from 5.32) exist and must stay green.

## Goals / Non-Goals

**Goals:** the list appears after one metadata round trip. Every missing value has a visible reason. The list costs
O(N) per input change, not per row. `describe_topic_configs` is reusable by 5.10 and MCP without changes.

**Non-Goals:** a shared Tokio runtime for the crate (one runtime per call, as today). Virtualised fixed-extent rows:
rows keep their variable height because of the DLQ sub-tree. Topic search on the broker side. Changing session
restore, which keeps reporting topics missing from the list as "not restored".

## Decisions

### D1 Rust: metadata-only `fetch_topics`, by-name `fetch_topic_metadata` (kafkalyzer-kafka)

- Move the per-topic mapping into `fn topic_metadata_from(meta: &MetadataTopic) -> TopicMetadata`. It sets
  `metadata_error` from `meta.error()`: `TopicAuthorizationFailed` maps to `NotAuthorized`, `UnknownTopicOrPartition`
  to `NotFound`, anything else to `Other`. The message is the `RDKafkaErrorCode` display text. Partition count,
  replication factor and health are computed only when `metadata_error` is `None`. Otherwise they are `0` / `None`,
  and Dart never shows them (D7).
- `fetch_topics(profile)` keeps its signature. It returns every topic in the response, errors included, sorted by
  name, and has no `AdminClient` or runtime any more. `cleanup_policy`/`retention_ms` stay on the struct but are no
  longer filled; a doc comment points to `describe_topic_configs`.
- New `fetch_topic_metadata(profile, topic) -> Result<TopicMetadata>`: `fetch_metadata(Some(&topic), 10 s)`, then
  `topic_metadata_from`. `Err` only for transport or client errors. A missing topic entry in the response becomes
  `NotFound`. (Spike 1.1 confirmed: `fetch_metadata(Some("does-not-exist-..."))` returns
  `RD_KAFKA_RESP_ERR_UNKNOWN_TOPIC_OR_PART` with 0 partitions, and `kafka-topics --list` confirms the topic is not
  created.)
- Alternative rejected: computing partition count and RF in Dart from `fetch_topic_partitions`. That would duplicate
  the RF and health rules that live in Rust today (`summarize_topic_health`).

### D2 Rust: `describe_topic_configs(profile, topics) -> Result<Vec<TopicConfigResult>>` (kafkalyzer-kafka)

- Domain types: `TopicConfigResult { topic, outcome: TopicConfigOutcome }` with
  `TopicConfigOutcome::{Available(Vec<TopicConfigEntry>), NotReadable(String), Failed(String)}`, and
  `TopicConfigEntry { name, value: Option<String>, source: TopicConfigSource, is_default, is_sensitive, is_read_only }`.
  `TopicConfigSource` mirrors `ConfigSource` 1:1, so rdkafka types do not leak to callers.
- One `Runtime` and one `AdminClient` per call. Input names are de-duplicated with order kept. Internal chunks of
  `CONFIG_CHUNK_SIZE = 100` (Spike 1.1 measured 100 topics in < 1 ms and 500 topics in 1 ms on local Kafka, well under
  the 2 s threshold, so `CONFIG_CHUNK_SIZE` stays 100; it also confirmed a missing topic in `describe_configs` comes back
  as `Ok(ConfigResource)` with `entries.len() == 0`, matching `NotReadable`). Each chunk uses
  `AdminOptions::operation_timeout(10 s)` and `request_timeout(15 s)`, so the whole call never hangs on one chunk.
- Classification is a pure `fn classify_chunk(requested: &[&str], result: KafkaResult<Vec<ConfigResourceResult>>)`
  and is unit-tested without a broker:
  - `Err(AdminOp(TopicAuthorizationFailed | ClusterAuthorizationFailed))`: every topic in the chunk is `NotReadable`.
  - Any other `Err`: every topic in the chunk is `Failed(err.to_string())`.
  - `Ok(ConfigResource)` with no entries: `NotReadable("broker returned no configuration entries")`. This is how
    rdkafka 0.36.2 surfaces a per-topic denial (Context).
  - `Ok` with entries: `Available`. A requested topic missing from the response: `Failed("no result for topic")`.
  - A sensitive entry always has `value: None`, so no caller (5.10, MCP) can show a secret.
- Outer `Err` only when the client cannot be created. Results come back in input order.
- Layer: it stays in `kafkalyzer-kafka`. The mapping works on rdkafka types, and the classification has no second
  caller outside this crate. Moving it to core would mean mirroring rdkafka error codes there.
- The analyzer (D9) is the second caller. 5.10 is the third.

### D3 Bridge DTOs (`rust/src/api/kafka_metadata.rs`, additive)

- `TopicMetadata.metadata_error: Option<TopicMetadataError>` with
  `TopicMetadataError { kind: TopicMetadataErrorKind (NotAuthorized|NotFound|Other), message: String }`.
- `TopicConfigResult { topic, status: TopicConfigStatus (Available|NotReadable|Failed), message: Option<String>,
  entries: Vec<TopicConfigEntry> }` and `TopicConfigEntry { name, value: Option<String>, source:
  TopicConfigSource, is_default, is_sensitive, is_read_only }`. The struct is flat with plain enums instead of a
  data enum, so the Dart side gets plain `enum`s and no freezed sealed class. These DTOs are not persisted, so no serde.
- Functions: `fetch_topic_metadata(profile, topic)`, `describe_topic_configs(profile, topics: Vec<String>)`. Both
  are added to `KafkaMetadataService`.
- Config availability lives on `TopicConfigResult`, not on `TopicMetadata`. The list never carries configs, so a
  flag on `TopicMetadata` would always read "not loaded" and would go stale in already opened tabs. Siblings that
  expect "topic list with a config-availability flag" read `TopicController.configFor(profile, topic)` (D4).

### D4 Dart: `TopicController` owns list, age, config state and lookups

Per cluster name it keeps the following state:

- `List<TopicMetadata> topics`, a `Map<String, TopicMetadata>` index, `DateTime fetchedAt`, `isLoading`, `error`, and
  an `int generation`.
- `Map<String, TopicConfigResult> configs`, a `LinkedHashSet<String> pendingConfigs`, a `Set<String> inFlight`, and
  `Map<String, TopicMetadata> resolved` for by-name lookups.

The controller works like this:

- `fetchTopics(force)` keeps the old list during a refresh. On success it replaces the list and index, sets
  `fetchedAt`, increments `generation`, clears `configs`/`resolved`, queues all names and starts the loader. On failure
  it keeps the old list and `fetchedAt` and sets `error`; the sidebar shows the inline notice.
- Loader: an async loop with at most one bridge call in flight per cluster. Each call takes up to 100 names from the
  front of `pendingConfigs`. Results apply only if `generation` is unchanged and the cluster is still cached. It calls
  `notifyListeners()` once per chunk, not per topic.
- `ensureConfig(profile, topic)` (called by the topic header) moves the topic to the front. If nothing is in flight,
  it starts the loader. `retryConfig` re-queues one topic at the front.
- `clearCache` (disconnect) increments `generation` and drops the state.
- `findTopic(profile, name)` is an O(1) index lookup. `resolveTopic(profile, name)` returns the index hit or calls
  `fetchTopicMetadata` and caches the result in `resolved`. Bridge errors are rethrown to the caller.
- `ActiveConnectionController.isConnecting` stops including topic loading. The sidebar shows a full spinner only
  when no list is cached, and a `LinearProgressIndicator` above the list otherwise.

### D5 Dart: pure topic-list query with memoisation

- New `lib/src/features/topic/domain/topic_list_query.dart`:
  - `TopicListQuery` is a value object with `==`/`hashCode`. It holds the text, the `TopicFilterMode` (substring,
    glob, regex), `showInternal`, `showStream`, the `TopicSortOrder` (name, partitions, health), `groupByPrefix`, the
    favourites and the collapsed groups.
  - `TopicListView buildTopicListView(List<TopicMetadata> all, TopicListQuery q)` returns the flattened rows
    (favourites header and rows, group headers, topic rows), `visibleTopics`, hidden counts per reason
    (internal, stream, text), `patternError`, the highlight `RegExp?` and the DLQ `failureGroups` (computed once on
    `visibleTopics`).
  - The matcher is compiled once per call:
    - substring: `RegExp(RegExp.escape(text), caseSensitive: false)`;
    - glob: escape everything, `*` becomes `.*` and `?` becomes `.`, anchored `^…$`;
    - regex: `RegExp(text, caseSensitive: false)`. A `FormatException` sets `patternError` and disables the text
      filter.
  - Stream rule: suffix `-changelog` or `-repartition`. Internal rule: leading `_`.
  - Prefix: strip leading `_`, then cut at the first `.`, `-` or `_`. Groups with fewer than 2 visible members are
    flattened.
  - Health rank: `metadataError` → 0; `leaderless + underReplicated > 0` → 1 (count descending); health `null` → 2;
    healthy → 3. Ties sort by name. With partition sort, unknown counts go last.
- It is pure Dart in the domain layer. It is view state with one caller. MCP lists topics without UI filters, so
  moving it to Rust is not justified.
- `ActiveConnectionController` keeps `_query` and the last `(List identity, query) → view`. `topicListView`
  recomputes only when `identical(list)` or `query` changed. A `@visibleForTesting int viewComputations` counter
  exists for the spec test. The `topics` getter stays as `topicListView.visibleTopics`.
- Highlighting: `buildTopicNameSpans`/`fitTopicNameToWidth` get an optional `RegExp? highlightPattern`. The
  substring path is replaced by `pattern.allMatches`. Glob mode passes `null`.
- Rejected alternative: computing the view in an isolate. 10 000 short names take well under 100 ms (target in the
  spec), and an isolate adds copying and async UI states.

### D6 Dart: per-cluster preferences

- New `lib/src/services/topic_list_preferences_service.dart`. It stores the key `topic_list_prefs_<clusterName>` as
  the JSON object `{"version":1, "showInternal", "showStream", "filterMode", "sort", "groupByPrefix", "favourites":
  [..]}`. Unknown fields are ignored, and missing fields fall back to the defaults from the spec. Unknown enum
  strings fall back to the default.
- It is loaded in `connect` before the list is shown and saved on every change (small value, no debounce).
- Unreadable value (invalid JSON or not an object): the service reports `unreadable`, and the controller uses
  defaults and exposes a notice. Before the first overwrite it calls `writeStoreBackup('topic_list_prefs_<name>',
  raw)`. If that returns `null`, nothing is written for this cluster in this session, and the notice says so.
- A profile rename does not move the key, the same as session tabs (proposal non-goal). The old key stays and is
  harmless.

### D7 Dart: open by name, unknown rendering

- `ActiveConnectionController.openTopicByName(profile, name)` follows `findTopic` → `resolveTopic` → `openTopic`.
  On a bridge exception it rethrows. Callers then show a localized SnackBar with Retry and open no tab. It replaces
  the two placeholder constructions in `explorer_view.dart` (recents, cluster overview), the filtered lookups in
  `quick_jump_dialog.dart:168` and `message_inspector_panel.dart:1043`, and the favourites "not in topic list" rows.
- `extension TopicMetadataFacts on TopicMetadata { bool get metadataKnown => metadataError == null; }` lives in
  `topic_utils.dart`.
- The header (`topic_detail_view.dart`) reads `topicController.findTopic(profile, name) ?? widget.topic`, so a
  refresh updates open tabs.
  - When `!metadataKnown`, partitions, RF and health show "unknown" and the error shows as a tag. The tag text is
    "not readable — permission?" for `notAuthorized`, "topic not found" for `notFound`, or the message.
  - It passes `partitionCount: null` to `TopicSearchBar` (Fast Trace off).
  - The literal `"N Partitions"` and `"RF: N"` become ARB texts.
- The tooltip (`topic_list_item.dart`) shows "unknown" values for `!metadataKnown` in the same way.
- Not touched: `script_runner.dart:799-822` builds a `TopicMetadata(partitionCount: 0)` fallback for scripts. It is
  not shown in the explorer header. The follow-up is noted in the PR.

### D8 Dart: config display

- `TopicController.configFor(profile, name)` returns a small Dart view: `TopicConfigView { state (loading,
  available, notReadable, failed), message, retentionMs, cleanupPolicy }`. A topic still in `pendingConfigs` or
  in flight is `loading`. `retention.ms`/`cleanup.policy` are read from `entries`; an entry missing from an available
  result is shown as unknown.
- The tooltip and the header tags use it with the texts from the spec. The header calls `ensureConfig` in
  `initState` and offers Retry for `failed`.

### D9 Analyzer cleanup policy (kafkalyzer-kafka + bridge)

- Replace the inline `describe_configs` with `describe_topic_configs(&profile, &[topic])`. `Available` sets
  `is_compacted = cleanup.policy contains "compact"`. Any other outcome sets `cleanup_policy_unknown = true` and
  `is_compacted = false`, and logs the reason with `log::warn!` without any payload.
- `TopicAnalysisReport` and the domain report get `cleanup_policy_unknown: bool` with `#[serde(default)]`. In Dart,
  `topic_analysis_report_file.dart` reads `cleanup_policy_unknown` with `_toBool`, so missing means `false` and old
  reports look unchanged. The summary card shows a "not readable" subtitle and a `?` badge, not `delete`.
- The analyzer timeout goes from 3 s to D2's 10 s per chunk. This adds at most 7 s before a scan of a topic with
  unreadable configs, and it is logged.

### D10 Sidebar layout

- Header row: title with `visible/total`, the age label (a small `StatefulWidget` with `Timer.periodic(30 s)`,
  ARB plurals for minutes and hours), a sort `PopupMenuButton`, a group `IconButton` (toggle), Quick Jump and Refresh.
  Every icon control has a tooltip and the hit-area rules of 5.32.
- Refresh calls `topicController.fetchTopics(force: true)`, and also `schemaController.fetchSchemas(force: true)`
  when the registry is not already loading. It is disabled only by `topicController.isLoading`.
- Filter row: chips (internal, stream), a mode `PopupMenuButton` as the text field prefix (labels
  "Text"/"Glob"/"Regex"), `errorText` for `patternError`, and the hidden-count `ActionChip` with tooltip and
  "Show all". The unreadable-preferences notice and the refresh-error notice appear as inline rows above the list.
- List: one `ListView.builder` over the flattened rows. Rows are built lazily, and no row reads the view again. The
  favourite toggle is a trailing 24×24 `IconButton` (`star`/`star_border`) with a tooltip.

### D11 Measurable performance tests

- Unit test: `buildTopicListView` on 10 000 generated names (mixed prefixes, 5 % internal, 5 % stream, health
  variety) with regex `\.v[0-9]$`, health sort and grouping. Best of 3 runs < 100 ms (`Stopwatch`). The bound is
  generous for debug JIT in CI.
- Controller test: after one computation, reading `topicListView`/`topics` 10 000 times leaves `viewComputations`
  unchanged. Changing the filter text increments it by exactly 1.
- Widget test: 1280×800 surface with the sidebar and 10 000 topics. `find.byType(TopicListItem)` ≤ 60. After
  `enterText` of one character and `pump`, it is still ≤ 60 and `viewComputations` grew by 1.

## Risks / Trade-offs

- [rdkafka hides per-topic config errors] → An empty entry list is treated as "not readable — permission?". The
  question mark marks it as a likely cause, not a certainty. Spike 1.1 confirms the behaviour on the local broker.
- [`-topic` topics become visible (behaviour change)] → Called out in the proposal and the release notes. The stream
  chip still hides `-changelog`/`-repartition`.
- [Background config loading on 10 000-topic clusters means 100 sequential describe requests] → One request in
  flight, cancelled on refresh or disconnect, opened topic first. The load is comparable to today's single request,
  spread over time.
- [A user-entered regex with catastrophic backtracking freezes the UI] → Topic names are at most 249 characters,
  and the pattern only runs on the user's own machine. The UI uses `RegExp` as is; no timeout is added.
- [Analyzer waits up to 10 s on an unreadable config instead of 3 s] → Logged. The scan result is unchanged.
- [Concurrent siblings edit the same specs] → This change does not modify "Cluster Overview Dashboard Empty State"
  (5.34) or schema indicators (5.35). It modifies "Load Failure Error States in Explorer". If 5.35 also modifies that
  requirement, the second change to archive must rebase its delta.

## Migration Plan

- No data migration. The new SharedPreferences key is created on first change. Older versions ignore it.
  `cleanup_policy_unknown` is ignored by older readers: serde without `deny_unknown_fields`, and the Dart map reader.
- Rollback: revert the change. Stored preferences stay unused. Reports written with the new field load in the old
  version.
