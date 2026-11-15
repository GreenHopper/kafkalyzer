# Tasks

Order: spikes → `kafkalyzer-kafka` → bridge + codegen → Dart. Run the named tests after every task. Before group 5,
rebase onto `accessibility-and-l10n-sweep` or check what it left in `explorer_view.dart`, `topic_list_item.dart` and
`cluster_overview_view.dart`. Every new user-facing text goes into `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`
(then `flutter gen-l10n`). The guard `test/l10n/hardcoded_strings_guard_test.dart` and
`test/l10n/arb_consistency_test.dart` must stay green.

## 1. Spikes

- [x] 1.1 Spike on `docker compose up kafka` (localhost:9094). Create 1 000 test topics with `kafka-topics.sh` inside
      the container (fixture only, not app code). In an `#[ignore]` test in `kafka_metadata.rs`:
      (a) call `describe_configs` for `[existing, "does-not-exist-<uuid>"]` and record whether the missing topic
      comes back as `Ok` with empty entries or as `Err`;
      (b) measure one `describe_configs` for 100 and for 500 topics;
      (c) call `fetch_metadata(Some("does-not-exist-<uuid>"))` and record the topic error code, then confirm with
      `kafka-topics.sh --list` that the topic was not created.
      Verify: the findings are written into design D1/D2 (keep `CONFIG_CHUNK_SIZE = 100` unless one 100-topic chunk
      takes > 2 s), and the classification in D2 matches (a).

## 2. kafkalyzer-kafka

- [x] 2.1 Add `TopicMetadataError`/`TopicMetadataErrorKind` and `metadata_error` to `kafka_metadata::TopicMetadata`.
      Extract `topic_metadata_from` (D1), make `fetch_topics` metadata-only, keep topics with errors, and remove the
      `AdminClient`/`Runtime` from it. Unit tests on a helper `classify_topic_error(RDKafkaRespErr)`: authorization →
      `NotAuthorized`, unknown topic → `NotFound`, leader not available → `Other` with its text. Verify:
      `cargo test -p kafkalyzer-kafka`.
- [x] 2.2 Add `fetch_topic_metadata(profile, topic)` (D1). Add an `#[ignore]` integration test against the local
      broker: an existing topic returns a partition count > 0, a random name returns `NotFound`, and the name is not
      created. Verify: `cargo test -p kafkalyzer-kafka -- --ignored fetch_topic_metadata` with the compose stack up.
- [x] 2.3 Add `TopicConfigSource`, `TopicConfigEntry`, `TopicConfigOutcome`, `TopicConfigResult` and
      `describe_topic_configs(profile, topics)` with de-duplication, chunking, timeouts and the pure
      `classify_chunk` (D2). Unit tests for `classify_chunk`:
      - request-level `TopicAuthorizationFailed` and `ClusterAuthorizationFailed` → `NotReadable` for every chunk
        topic;
      - `OperationTimedOut` → `Failed`;
      - empty entries → `NotReadable`;
      - topic missing from the response → `Failed`;
      - sensitive entry → `value == None`;
      - results in input order.

      Verify: `cargo test -p kafkalyzer-kafka`. An `#[ignore]` integration test returns `Available` with
      `cleanup.policy` for an existing topic.
- [x] 2.4 Analyzer (D9): replace the inline `describe_configs` in `kafka_analyzer.rs` with `describe_topic_configs`.
      Add `cleanup_policy_unknown` to the domain report and accumulator. Unit test: a `NotReadable` outcome gives
      `cleanup_policy_unknown = true`, `is_compacted = false`; `Available` with `compact,delete` gives
      `is_compacted = true`. Verify: `cargo test -p kafkalyzer-kafka`. `grep -n "describe_configs"
      rust/kafkalyzer-kafka/src` shows only `describe_topic_configs`'s call.

## 3. Bridge crate and code generation

- [x] 3.1 In `rust/src/api/kafka_metadata.rs` add `TopicMetadataError(Kind)`, `metadata_error` on `TopicMetadata`
      plus mapping, `TopicConfigStatus`, `TopicConfigSource`, `TopicConfigEntry`, `TopicConfigResult` and the
      functions `fetch_topic_metadata` and `describe_topic_configs` (D3). In `rust/src/api/kafka_types.rs` add
      `cleanup_policy_unknown` with `#[serde(default)]` to `TopicAnalysisReport` plus mapping. Unit tests in the
      bridge crate: mapping of each status/kind/source; a report JSON without the field deserialises with `false`
      (extend `report_compare.rs` fixtures if they build reports). Verify: `cargo test --workspace`.
- [x] 3.2 Run `flutter_rust_bridge_codegen generate` and `dart run build_runner build` (regenerates
      `test/src/rust/api/rust_mocks.mocks.dart`). Verify: `flutter analyze` shows no new errors. The existing
      `TopicMetadata(name:, partitionCount:, replicationFactor:)` calls in `lib/` and `test/` compile unchanged.

## 4. Dart state: TopicController, query, preferences

- [x] 4.1 `KafkaMetadataService`: add `fetchTopicMetadata` and `describeTopicConfigs`. Extend `TopicController`
      (D4): `fetchedAt`, keep the old list on a failed refresh, the name index with `findTopic`, `resolveTopic`, the
      generation counter, the chunked config loader (100 per call, one in flight), `ensureConfig`, `retryConfig`,
      `configFor` returning `TopicConfigView` (D8), and `clearCache` cancelling. Tests in `topic_controller_test.dart`
      with the mocked service:
      - 250 topics give 3 bridge calls of ≤ 100;
      - `ensureConfig` puts the topic into the next call;
      - a failing chunk marks only its topics `failed`;
      - a refresh during loading drops stale results (no config from generation 1 applied after generation 2);
      - a failed refresh keeps the list and `fetchedAt` and sets the error;
      - `resolveTopic` does not call the bridge for a listed topic.

      Verify: `flutter test test/src/features/topic/presentation/controllers/topic_controller_test.dart`.
- [x] 4.2 Create `lib/src/features/topic/domain/topic_list_query.dart` (D5). Unit tests in
      `test/src/features/topic/domain/topic_list_query_test.dart` for every scenario of *Topic Filter Modes*,
      *Hidden Topic Count*, *Topic List Sorting*, *Topic Name Prefix Grouping*, *Favourite Topics* (section, missing
      favourite row) and the stream/internal rules (`orders-topic` visible). Add the 10 000-topic performance case
      from D11 (< 100 ms, best of 3). Verify: the test file passes.
- [x] 4.3 Create `lib/src/services/topic_list_preferences_service.dart` (D6) and register it in
      `dependency_injection.dart`. Tests with `SharedPreferences.setMockInitialValues`:
      - round trip;
      - defaults for a missing key;
      - unknown enum value → default;
      - invalid JSON → `unreadable`, and `writeStoreBackup` is called before the first write;
      - a backup returning `null` → no write.

      Verify: `flutter test test/src/services/topic_list_preferences_service_test.dart`.
- [x] 4.4 `ActiveConnectionController`:
      - `_query`, the memoised `topicListView` with `viewComputations`, and the `topics` getter delegating to it;
      - setters for text, mode, switches, sort, grouping, favourites and collapsed groups, each saving through 4.3;
      - load the preferences in `connect`, expose the unreadable notice, and drop `isConnecting`'s dependency on
        topic loading;
      - `openTopicByName` (D7).

      Tests in `active_connection_controller_test.dart`:
      - preferences per cluster (scenario *Preferences restored per cluster*);
      - 10 000 reads → no recomputation, one text change → +1;
      - `openTopicByName` for a listed, a resolved-not-authorized and a failing topic (rethrow, no tab).

      Verify: the test file passes.

## 5. Dart UI

- [x] 5.1 `topic_utils.dart`: add the `TopicMetadataFacts` extension and the `RegExp? highlightPattern` in
      `buildTopicNameSpans`/`fitTopicNameToWidth` (D5). Update `topic_utils_test.dart` with regex highlighting, glob
      `null`, and unchanged substring highlighting. Verify: the test passes.
- [x] 5.2 Sidebar in `explorer_view.dart` (D10):
      - render from `topicListView` (one `ListView.builder` over the flattened rows);
      - header with age label, sort menu, group toggle and refresh that is independent of the registry;
      - inline progress during refresh, inline refresh-error notice with Retry, and the preferences-unreadable notice;
      - filter mode menu with `errorText`, hidden-count chip with "Show all", collapsible group headers and a
        favourites section.

      Add ARB keys (en + de) with plurals for the age and the hidden count. Widget tests in `explorer_view_test.dart`
      (German locale for at least one):
      - age text;
      - refresh enabled while the schema registry loads;
      - old list stays visible during refresh;
      - failed refresh with cached list shows notice + Retry;
      - invalid regex error;
      - hidden count + Show all;
      - group collapse;
      - favourite pinned;
      - DLQ badge still shown in a grouped list.

      Verify: the test file and the l10n guard tests pass.
- [x] 5.3 Add the D11 widget performance test (`test/src/features/explorer/presentation/topic_sidebar_scale_test.dart`):
      10 000 topics at 1280×800 → ≤ 60 `TopicListItem`, one typed character → still ≤ 60 and `viewComputations`
      +1. Verify: the test passes.
- [x] 5.4 `topic_list_item.dart`:
      - tooltip states loading / not readable / could not be loaded / metadata error / unknown values, read from
        `topicController.configFor` and `metadataKnown`;
      - warning icon for metadata errors;
      - favourite `IconButton` (24×24, tooltip, filled vs outlined icon);
      - "not in topic list" variant for missing favourites.

      Remove the English fallback branch of the tooltip if the guard flags it. Update `topic_list_item_test.dart` for
      each tooltip state. Verify: the test passes.
- [x] 5.5 `topic_detail_view.dart`:
      - read metadata through `findTopic ?? widget.topic`;
      - unknown/error tags for partitions, RF and health, and ARB texts for "N Partitions"/"RF: N";
      - config tags from `configFor` with `ensureConfig` on init and Retry for `failed`;
      - `partitionCount: null` to `TopicSearchBar` when unknown.

      Tests in `topic_detail_view_test.dart`: a not-authorized topic shows "not readable — permission?" and no
      `0 Partitions`; a config denial shows the not-readable tag; Retry re-queues. Verify: the test passes.
- [x] 5.6 Replace the placeholder `TopicMetadata` in `explorer_view.dart` (recents and cluster overview) and the
      filtered lookups in `quick_jump_dialog.dart` and `message_inspector_panel.dart` with `openTopicByName`. Show a
      localized SnackBar with Retry on failure. Tests:
      - `explorer_onboarding_view_test.dart` or `explorer_view_test.dart`: a recent topic missing from the list calls
        `fetchTopicMetadata` and the header shows the loaded partition count;
      - a failing call opens no tab;
      - a Quick Jump test: a topic hidden by the internal filter opens.

      Verify: `grep -n "partitionCount: 0" lib/src/features/explorer` is empty, and the tests pass.
- [x] 5.7 Analysis UI (D9):
      - `topic_analysis_report_file.dart` reads and writes `cleanup_policy_unknown`;
      - `topic_analysis_summary_cards.dart` shows the not-readable subtitle and `?` badge (ARB en + de).

      Tests:
      - `topic_analysis_report_file_test.dart`: an old file without the key loads with `false`, and a round trip
        keeps `true`;
      - `topic_analysis_summary_cards_test.dart`: unknown shows no `delete` badge.

      Verify: both tests pass.

## 6. Final verification

- [x] 6.1 Run, in `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets` and `cargo test --workspace`.
      Then run `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`
      (including `test/l10n/`) and `scripts/check_read_only.sh`. Verify: all exit 0. The read-only gate passes with no
      new exception.
- [x] 6.2 Manual check against the docker-compose cluster with 1 000 topics, in English and German:
      - the list appears before the configs, tooltips go from "loading" to values, and the age label advances;
      - refresh works while the registry is stopped (`docker compose stop schema-registry`);
      - glob/regex filters, sort, grouping and favourites survive reconnect and app restart;
      - a deleted recent topic opens as "topic not found".

      Verify: screenshots attached to the PR. The PR also notes the remaining `script_runner.dart` placeholder (D7) as
      a follow-up.
