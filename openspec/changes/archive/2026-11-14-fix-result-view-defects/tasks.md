# Tasks

Dart only; `rust/` and `rust/src/api/` stay untouched, so no bridge or mock regeneration. Every group writes its
regression test first, runs it and records the failure (RED), then implements the fix until it passes (GREEN).

## 1. Localization keys

- [x] 1.1 Add `messageFetchFailedTitle`, `topicsLoadFailedTitle`, `subjectsLoadFailed` (placeholder `{error}`),
      `columnFiltersNoMatch` and `resetColumnFilters` to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` (reuse the
      existing `retry` key); run `flutter gen-l10n` and verify the getters exist in
      `lib/l10n/app_localizations.dart` and `flutter analyze lib/l10n` reports no issues

## 2. Cancelled export reports no success (B3, no spec delta)

- [x] 2.1 Write a widget test in `test/src/ui/messages/messages_view_test.dart` with a mocked `MessageExportService`
      returning `null`: selecting an export format shows no SnackBar; returning a path still shows the success
      SnackBar with Open / Show in Folder; verify the `null` case fails before the fix
- [x] 2.2 In `lib/src/ui/messages/messages_view.dart` remove the `else` success SnackBar after `exportMessages` and
      disable the export menu while the filtered message list is empty (design D1); verify the tests from 2.1 pass,
      plus a case asserting the export button is disabled when the in-memory filter matches nothing

## 3. Load and stream errors are shown, not swallowed (B4)

- [x] 3.1 Extend `test/src/features/topic/presentation/controllers/message_stream_controller_test.dart`: a stream
      error sets `error` with the cause and `isStreaming == false`; a factory that throws sets `error`; a new
      `startStreaming` clears it; verify RED, then add the `error` state to `MessageStreamController` (design D2) and
      verify GREEN
- [x] 3.2 Add `test/src/features/topic/presentation/controllers/topic_controller_test.dart` (mocked
      `KafkaMetadataService` via `getIt`): a failing `fetchTopics` exposes `errorFor(cluster)`, a later successful
      fetch clears it, a failed forced refresh keeps the cached list; verify RED, then implement per D2 replacing
      `debugPrint` with `logger`, and verify GREEN
- [x] 3.3 Extend `test/src/features/schema/presentation/controllers/schema_controller_test.dart`: a failing
      `fetchSubjects` exposes `errorFor(cluster)`; a profile without Schema Registry URL caches `[]`, sets no error
      and never calls the service; verify RED, then implement per D2 and verify GREEN
- [x] 3.4 Add a `MultiSearchController` test (new file under `test/src/features/search/presentation/controllers/`)
      that a stream error stores the message in `errors[target]` and a restart clears it, and extend
      `test/src/features/scripting/presentation/controllers/script_runner_test.dart` so a failing target marks the
      topic step as error with that message instead of completed; verify RED, implement per D2, verify GREEN
- [x] 3.5 Extend `test/src/ui/messages/widgets/actionable_topic_empty_state_test.dart` and
      `test/src/ui/messages/messages_view_test.dart`: with `errorMessage` set and not streaming, the error title, the
      cause and "Retry" are shown, "No messages loaded yet" is not, and "Retry" calls `onFetch`; verify RED, then
      implement the error variant in `ActionableTopicEmptyState` and the `errorMessage` pass-through in
      `MessagesView` (design D3), verify GREEN
- [x] 3.6 Wire `streamController.error` into `lib/src/features/topic/topic_detail_view.dart`, including the inline
      error row with "Retry" above non-empty results; verify with a widget test (or the existing topic detail test
      harness) that partial results stay visible together with the error row
- [x] 3.7 Add to `test/src/features/explorer/presentation/explorer_view_test.dart`: topic-list error without cache
      shows the error state with cause and "Retry" (not an empty list, not count 0) and "Retry" calls
      `fetchTopics(force: true)`; a subject error shows the inline notice with "Retry"; verify RED, then implement in
      `explorer_view.dart` (design D3), verify GREEN
- [x] 3.8 Make `TopicSchemaInspectorView` show the subject load error instead of "no schema"; verify with a widget
      test using a `SchemaController` whose `fetchSubjects` fails

## 4. Tree copy yields JSON (B5)

- [x] 4.1 Add unit tests for `copyableNodeText` (object and array → `jsonDecode` round-trips to the original value
      including nested and windowed items; string → unquoted; `null` → `null`) and a widget test in
      `test/src/ui/smart_tree/smart_virtual_json_tree_test.dart` that tapping the row copy icon on an object row puts
      valid JSON on the mocked clipboard; verify RED
- [x] 4.2 Implement `copyableNodeText` in `lib/src/ui/smart_tree/`, use it in the row copy action of
      `smart_virtual_json_tree.dart` and in `SmartCompositeBadge._copyFullObject` (design D4); verify the tests from
      4.1 and the existing `smart_composite_badge_test.dart` pass

## 5. Deterministic message order (B6)

- [x] 5.1 Add unit tests for `compareMessageIdentity` (topic, partition, offset ascending) and widget tests in
      `test/src/ui/messages/messages_view_test.dart`: messages with equal timestamps in shuffled input order render in
      the same topic/partition/offset order for descending and ascending timestamp sort, and with a custom
      `sortComparator` that returns 0; verify RED
- [x] 5.2 Implement `compareMessageIdentity` and apply it in `MessagesView._compareMessages` (direction-aware) and
      after custom comparators (design D5); verify 5.1 GREEN
- [x] 5.3 Add a test in `test/src/ui/messages/views/messages_table_view_customization_test.dart` that a column-header
      sort on a column with equal values orders rows by topic/partition/offset in the column's direction, and a
      `MultiSearchController.getMessagesFor(null)` test for equal timestamps; verify RED, apply the tie-breaker in
      `messages_table_view.dart` and `multi_search_controller.dart`, verify GREEN

## 6. Content column filter and empty filter state

- [x] 6.1 Add tests in `test/src/ui/messages/views/messages_table_view_customization_test.dart`: a Content filter
      for text beyond the 300-character preview keeps the row; a filter for a null-valued JSON field name keeps the
      row; verify RED, then filter on the full payload (design D6) and verify GREEN
- [x] 6.2 Add a test that column filters matching no row show the header, the localized "no rows match" text and
      "Reset filters", and that tapping it restores all rows; verify RED, implement the empty filter state in
      `messages_table_view.dart` (design D6), verify GREEN

## 7. Final verification

- [x] 7.1 Run `dart format --set-exit-if-changed lib test` and verify exit code 0
- [ ] 7.2 Run `flutter analyze` and verify "No issues found"
- [x] 7.3 Run `flutter test` and verify all tests pass
- [x] 7.4 Run `scripts/check_read_only.sh` and verify it passes unchanged; confirm `git diff --stat rust/` is empty,
      so the cargo fmt / clippy / test steps are not required for this change
- [ ] 7.5 Manually check against a local broker: stop the broker and fetch a topic (error state with Retry), cancel
      a message export (no SnackBar), copy an object node (valid JSON), filter Content beyond the preview
