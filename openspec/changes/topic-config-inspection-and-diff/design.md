# Design

## Context

See proposal.md (Why). Behaviour contract: `specs/topic-config-inspection/spec.md`. Observed state of the code
(working tree, not the roadmap commit):

- `rust/kafkalyzer-kafka/src/kafka_metadata.rs::fetch_topics` builds one `AdminClient` with a per-call
  `Runtime::new()`. It sends a single `describe_configs` for all topics with a 10 s operation timeout and keeps only
  `retention.ms`/`cleanup.policy`. Per-resource errors and request errors are ignored (`if let Ok`).
- `kafka_analyzer.rs` (~1120) sends its own one-topic `describe_configs` (3 s) and only reads `cleanup.policy`. Not
  touched here.
- rdkafka 0.36.2 / librdkafka 2.3.0: `ConfigEntry { name, value: Option<String>, source: ConfigSource, is_read_only,
  is_default, is_sensitive }`, `ConfigSource { Unknown, DynamicTopic, DynamicBroker, DynamicDefaultBroker,
  StaticBroker, Default }`, `ConfigResourceResult = Result<ConfigResource, RDKafkaErrorCode>`. No synonyms, no
  documentation, no type.
- `kafka_consumer::shared_runtime()` is a shared `LazyLock<Runtime>` (pub(crate)) that is already used for blocking
  admin and registry calls.
- Bridge functions in `rust/src/api/kafka_metadata.rs` take the bridge `ClusterProfile` DTO and call
  `profile.to_domain()`. `to_domain()` maps `TlsVerification::Disabled` to `ssl_verification_disabled = true` and
  maps `Unreviewed`/`Enabled` to verified (archived `restore-tls-verification` D1). `create_config` applies TLS,
  SASL and the profile's allow-listed extra properties (archived `cluster-profile-ergonomics`).
- Dart: `ClusterListController.clusters` comes from `ClusterService.loadClusters`, which attaches keyring secrets
  through `withSecrets` (archived `harden-local-storage-and-imports`). So any saved profile can be passed to a bridge
  call without connecting. `ActiveConnectionController.connect` skips validation when `TopicController` already has
  cached topics for the profile name.
- `TopicDetailView` has `enum TopicViewMode { messages, analysis }`, switched by `_TopicModeButton`s in the header.
  The partition health dialog is the existing pattern for an on-demand describe from the header.
- Six test fakes `implements KafkaMetadataService`. The l10n guard (`test/l10n/hardcoded_strings_guard_test.dart`)
  and the ARB consistency test exist and apply to new widgets.

## Goals / Non-Goals

**Goals:**
- One Kafka function that reads full topic configs with a per-topic, classified result, shared with 5.33 and later MCP.
- The diff is pure, deterministic and unit-tested in `kafkalyzer-core`. Dart only holds view state and formats text.
- Sensitive values never leave `kafkalyzer-kafka`.
- Comparison with another saved profile does not touch the active connection, the topic cache or TLS transition state.

**Non-Goals:**
- Changing `fetch_topics` or the analyzer's describe call (owned by 5.33 / 5.37).
- Caching configs across view instances or sessions. Admin-client pooling.
- Persisting the filter toggle or the last comparison target.

## Decisions

### D1 — Layer assignment

| Piece | Layer | Why |
|---|---|---|
| `TopicConfigEntry`, `TopicConfigSource`, `TopicConfigUnavailable`, `diff_topic_configs`, diff row/status types | `kafkalyzer-core::topic_config` | Pure computation. Second consumer is MCP `kafka_get_topic_config` (§6.2). Testable without a broker. |
| `describe_topic_configs`, rdkafka → core mapping, sensitive redaction, error classification | `kafkalyzer-kafka::kafka_metadata` | Needs rdkafka. Redaction sits at the earliest point the value exists. |
| DTOs + `fetch_topic_config`, `diff_topic_configs` | bridge `rust/src/api/topic_config.rs` | L3: DTOs only in the bridge crate. New module, so existing signatures stay unchanged. |
| Fetch orchestration, stale-result guard, filter, text copy, widgets | Dart | View state and presentation. The text format is a UI artefact; MCP will return structured data. |

Alternative: diff in Dart. Rejected because the brief and E11-style reasoning put reusable diffs in the core, and MCP
would otherwise need a second implementation.

### D2 — `describe_topic_configs` contract (shared with 5.33)

```rust
// kafkalyzer_core::topic_config
pub enum TopicConfigSource { DynamicTopic, DynamicBroker, DynamicDefaultBroker, StaticBroker, Default, Unknown }
pub struct TopicConfigEntry { pub name: String, pub value: Option<String>, pub source: TopicConfigSource,
                              pub is_default: bool, pub is_sensitive: bool }
pub enum TopicConfigUnavailable { NotAuthorized, TopicNotFound, Failed(String) }

// kafkalyzer_kafka::kafka_metadata
pub struct TopicConfigs { pub topic: String, pub result: Result<Vec<TopicConfigEntry>, TopicConfigUnavailable> }
pub fn describe_topic_configs(profile: &ClusterProfile, topics: &[String]) -> Vec<TopicConfigs>
```

- It always returns exactly one `TopicConfigs` per requested topic, in request order. A request-level failure
  (admin client creation, timeout, transport, TLS/SASL) becomes `Failed(<error text>)` for every topic in that
  request, so callers never mistake a failure for "no configs".
- It sends requests in chunks of at most 100 topics (constant). For this change it is always one topic per call.
  The chunking exists so 5.33 can adopt the function unchanged. Chunks run one after another on
  `kafka_consumer::shared_runtime()` (already `pub(crate)` in the same crate) instead of a per-call `Runtime::new()`.
  `AdminOptions` sets `request_timeout` and `operation_timeout` to 10 s, so a hung broker returns a bounded error.
- Mapping: `value = if is_sensitive { None } else { value }`. `is_read_only` is dropped. Entries are sorted by `name`
  (byte order).
- Error classification of `RDKafkaErrorCode`: `TopicAuthorizationFailed`, `ClusterAuthorizationFailed` →
  `NotAuthorized`; `UnknownTopicOrPartition`, `UnknownTopic` → `TopicNotFound`; every other code →
  `Failed(code.to_string())`. A requested topic missing from the response → `Failed("no result for topic")`.
- Logging: `log::warn!` with topic name and classification only. It never logs values or entry lists.
- Ownership: 5.33 owns this function. If 5.33 is implemented first, this change uses its function and types, renaming
  this change's references if 5.33 chose other type names. Otherwise this change creates them exactly as above.

Alternatives: return `anyhow::Result<Vec<…>>` with request errors as `Err` (rejected; callers then need two error
paths and 5.33's list would lose per-topic availability). Redact in the bridge (rejected; the value would exist in a
second crate's types and in MCP's path).

### D3 — Pure diff in the core

```rust
pub enum ConfigDiffStatus { Equal, Different, OnlyLeft, OnlyRight, NotComparable, Unknown }
pub struct ConfigDiffRow { pub name: String, pub left: Option<TopicConfigEntry>, pub right: Option<TopicConfigEntry>,
                           pub status: ConfigDiffStatus, pub non_default: bool }
pub struct TopicConfigDiff { pub rows: Vec<ConfigDiffRow>, pub difference_count: Option<u32> }
pub fn diff_topic_configs(left: Option<&[TopicConfigEntry]>, right: Option<&[TopicConfigEntry]>) -> TopicConfigDiff
```

- `None` means the side is unreadable. Rows are the union of names via `BTreeMap` (byte-order, locale-independent),
  so order is stable across clusters and runs.
- Status rules in order: either side `None` → `Unknown` (only rows from the readable side). Sensitive on any present
  side → `NotComparable`. Present on one side only → `OnlyLeft`/`OnlyRight`. `value` equal (`Option<String>`, exact
  string) → `Equal`. Otherwise → `Different`. Source is not part of equality (spec "same value, different source").
- `non_default` = any present entry has `!is_default`. This uses `is_default` and not `source`, because brokers
  before 1.1 report source `Unknown` but still send the flag.
- `difference_count` = number of `Different|OnlyLeft|OnlyRight`. It is `None` when either side is unreadable, so the
  UI shows "unknown" and not 0. Both sides unreadable → empty rows, `None`.
- Filter "only differences and non-defaults" = `status ∈ {Different, OnlyLeft, OnlyRight} || non_default`. This is a
  single Dart predicate on the row flags and needs no core function. The single-topic toggle = `!entry.is_default`.
- Duplicate names within one side (not expected from Kafka) are handled first-wins and covered by a test.

### D4 — Bridge API (`rust/src/api/topic_config.rs`)

- DTOs mirroring D2/D3: `TopicConfigSource`, `TopicConfigEntry`, `TopicConfigAvailability { Available, NotAuthorized,
  TopicNotFound, Failed }`, `TopicConfigSnapshot { topic, availability, error_message: Option<String>, entries }`,
  `TopicConfigDiffStatus`, `TopicConfigDiffRow`, `TopicConfigDiff { rows, difference_count: Option<u32> }`. They are
  not persisted, so no serde attributes are needed.
- `pub fn fetch_topic_config(profile: ClusterProfile, topic: String) -> TopicConfigSnapshot` returns no `Result`.
  Availability is data, so Dart never parses error strings. It calls `describe_topic_configs(&profile.to_domain(),
  &[topic])`. frb runs it on its worker pool; the blocking `block_on` is outside any poll loop.
- `#[frb(sync)] pub fn diff_topic_configs(left: TopicConfigSnapshot, right: TopicConfigSnapshot) -> TopicConfigDiff`:
  a non-`Available` snapshot maps to `None`. It is sync because it is pure and small (≤ a few hundred entries),
  following the pattern in `profile_tools.rs`.
- Alternative: a single `compare_topic_configs(left_profile, left_topic, right_profile, right_topic)`. Rejected
  because spec "Retry one side" requires re-reading only one side, and the single view needs the fetch alone anyway.

### D5 — Dart state flow

- `TopicConfigService` (`lib/src/services/topic_config_service.dart`, getIt lazy singleton) wraps the two bridge
  functions. It is a new class, so the six `KafkaMetadataService` fakes stay untouched and tests fake one small
  service.
- `TopicConfigController` (ChangeNotifier) is created lazily by `_TopicDetailViewState` the first time the
  configuration mode is selected and disposed with the view. It is per tab, not global. State:
  `left: SideState`, `compare: (ClusterProfile profile, String topic, SideState right)?`, `diff: TopicConfigDiff?`,
  `nonDefaultOnly: bool`. `SideState` = `loading | loaded(TopicConfigSnapshot)`, and a snapshot carries its own
  availability.
- Each side has a monotonically increasing request token. A result whose token is stale, or arrives after dispose,
  is dropped. This covers refresh during load, changing the comparison target and closing the tab.
- Both sides load in parallel. `diff` is recomputed (sync bridge) only when both sides are `loaded`. While one side is
  loading, the table shows the loaded side with a per-side spinner and no difference count (spec "Comparison in
  progress"). Refresh re-reads all visible sides. "Retry" on a side re-reads only that side.
- Left profile = `widget.profile` (the tab's profile). Right profile = the profile picked from
  `getIt<ClusterListController>().clusters`. If it has the same name as the left profile, `widget.profile` is used.
  The picked profile is passed unchanged. There is no `ActiveConnectionController` call and no
  `TlsTransitionController` call, which matches the headless rule for undecided profiles (verify only, state
  unchanged).

### D6 — UI

- `TopicViewMode.config` with a third `_TopicModeButton` (icon `Icons.tune`, label "Configuration"). The content area
  shows `TopicConfigView` (`lib/src/features/topic/presentation/widgets/config/`). The header progress tile stays
  messages-only (existing condition).
- Toolbar: Refresh (`IconButton` + tooltip), toggle (`FilterChip`/`Switch` with text label, whose label changes
  between single and comparison mode), "Compare…" / "Close comparison", "Copy as text". All controls come from
  `package:material_ui/material_ui.dart`, and every icon-only control has a tooltip plus semantics label.
- Table: `ListView.builder` (virtualized) with fixed columns. Single mode has name, value, source, default marker.
  Comparison mode has name, left value, left source, right value, right source, status. Each status is an icon plus
  a localized text, never colour alone. Colours come from the `colorScheme`. Long values are ellipsized with a
  tooltip and selectable. Placeholders (localized): "no value", "hidden (sensitive)", "unknown".
- Side header: profile name, `EnvironmentTagChip` when it has a label, `InsecureTlsBadge(compact: true)` when
  `tlsVerification == disabled`, topic name, availability state with retry. Unreadable texts: NotAuthorized →
  "Not readable — missing DescribeConfigs permission?". TopicNotFound → "Topic not found". Failed → "Could not read
  configuration: {message}".
- `TopicConfigCompareDialog`: a profile `DropdownMenu` (current profile first, each entry with environment tag and
  insecure badge) and a topic `Autocomplete` text field prefilled with the open topic name. Suggestions come only from
  `TopicController.getTopics(profile)` when it is already cached. It never fetches a topic list for a non-active
  profile, because populating that cache would make a later `connect()` skip validation. A missing topic surfaces as
  "Topic not found" on that side.

### D7 — Copy as text

A pure Dart function `formatTopicConfigText` (`lib/src/features/topic/domain/topic_config_text.dart`) takes the
visible rows (after filter), the side labels and an `AppLocalizations`. It produces a header with
`profile / topic` per side, a localized column header line, then one tab-separated line per row. Placeholders are the
same localized strings as the UI. An unreadable side contributes a line with its reason. The result goes to the
clipboard via `Clipboard.setData` with a confirmation SnackBar. There is no file export (proposal Non-Goals).

### D8 — Edge cases

- Missing `DescribeConfigs` ACL: per-resource `TopicAuthorizationFailed` → NotAuthorized state. Never an empty list.
- Unreachable broker, TLS rejection, SASL failure: request-level error → `Failed(message)` within ~10 s.
  librdkafka texts contain host:port and no credentials (same as `restore-tls-verification` D4).
- Old brokers (< 1.1): source `Unknown`, shown as unknown. `is_default` still drives the filters.
- Kafka version differences between clusters: version-specific keys show as only-left/only-right. This is intended.
- Topics of any size, compacted or transactional: irrelevant; no records are consumed and no offsets are read.
- Empty entry list in an `Ok` response: shown as "no configuration entries reported", not as an error and not as
  defaults.

## Risks / Trade-offs

- [Error codes differ from the assumed mapping (e.g. missing topic reported as `InvalidRequest` or as an empty `Ok`)]
  → spike task 1.1 checks this against the docker-compose broker (`localhost:9094`, cp-kafka 7.6, no authorizer)
  before the mapping is written. The local broker cannot produce the authorization case, so that code comes from the
  Kafka protocol docs and is covered by a unit test only. The mapping is a pure function, and anything unmapped still
  falls back to `Failed(message)`.
- [Users read "non-default" as "topic override", while static broker settings also count] → the source column and
  the toggle tooltip name the sources included.
- [Parallel 5.33 defines different type names] → D2 ownership rule. The bridge DTOs isolate Dart from the
  renaming.
- [Reading a PROD profile that is not the active connection] → this is an explicit user selection, and the
  environment label plus insecure badge are shown on that side. It is still a describe-only call (L1).
- [Fresh `AdminClient` per side costs a connection handshake (~hundreds of ms)] → acceptable for an on-demand view.
  There is no pooling (YAGNI).
- [Cached topic names exist only for profiles visited in this session] → the topic field accepts free text, and the
  same-name default covers the common case.

## Migration Plan

Additive only: a new module, new bridge functions and a new view mode. No stored data changes. Rollback = remove the
mode button and the bridge module. Without 5.33, `fetch_topics` keeps working unchanged.

## Open Questions

- Exact librdkafka error code for a non-existent topic and for a denied topic in `DescribeConfigs` (spike 1.1). Only
  the mapping table changes, not the spec.
- Final type and module names if 5.33 lands first (D2). Only references in tasks change.
