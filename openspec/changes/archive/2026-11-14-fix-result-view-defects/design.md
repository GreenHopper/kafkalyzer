# Design: fix-result-view-defects

## Context

See proposal.md (Why, What Changes) for the defects and their code locations. The requirements are in
`specs/message-sort-order`, `specs/explorer-onboarding`, `specs/smart-virtual-json-tree` and
`specs/message-table-columns`. B3 and the multi-search step error are restorations of behaviour already required by
`downloaded-file-actions` and `headless-script-execution`.

Constraints that shape the approach:

- All defects are in Dart view state and presentation. No second caller (MCP, headless) needs new shared logic, so
  nothing moves into `kafkalyzer-core` and no bridge signature changes (L2, L3).
- Controllers are global `getIt` singletons keyed by cluster name (`TopicController`, `SchemaController`) or per tab
  (`MessageStreamController`, held by `ActiveConnectionController`). Error state follows the same keying.
- The message stream is throttled (60 ms UI batches); errors must not add per-message work.
- Dart's `List.sort` is not stable, so a primary key alone gives a run-dependent order for equal keys.
- `fetch_subjects` throws `No Schema Registry URL provided` for clusters without a registry; today this is hidden by
  the catch-all and must not turn into a visible error.
- Errors from `consume_with_filter` (`Result<()>` with a `StreamSink`) arrive on the Dart stream as stream errors;
  `MessageStreamController` already listens with `onError`, so only state is missing.

## Goals / Non-Goals

**Goals:**
- One error representation per controller (`String?` cause), cleared on the next attempt, rendered by existing
  widgets with a retry callback that re-invokes the existing fetch.
- One shared tie-breaker comparator used by every message sort.
- Regression test per defect, written first.

**Non-Goals:**
- Error classification (auth vs. network vs. ACL), error codes from Rust, or rewording of raw causes.
- Error indicators on tabs, in the cluster list or in the script editor's topic picker.
- Changing `MessageExportService`'s return contract or the Content column's sort key.

## Decisions

### D1 Export result handling (B3)
`messages_view.dart` shows `showExportSuccessSnackBar` only when the returned path is non-null; the `else` branch with
the plain success SnackBar is deleted. The export `PopupMenuButton` gets `enabled: _cachedFilteredMessages.isNotEmpty`,
because the service also returns `null` for an empty list and a silent no-op would be the next confusing state.
*Alternative:* return a result enum (`saved/cancelled/empty`) from the service — rejected: larger API change for the
same visible behaviour, and the other callers already treat `null` as "cancelled".

### D2 Error state in controllers (B4)
- `MessageStreamController`: field `String? _error` + getter `error`; set in `onError` and in the start `catch`
  (`e.toString()`), reset to `null` in `startStreaming` before the stream is opened, then `notifyListeners()`.
  The `onError` handler also flushes the pending throttled update so the error and the last batch render together.
- `TopicController`, `SchemaController`: `Map<String, String> _errors` keyed by cluster name, `String? errorFor(cluster)`;
  cleared when a fetch starts, set in `catch`. `debugPrint` is replaced by the `logger` package (project rule).
  The existing cached list is kept on a failed `force` refresh, but the error is still exposed; the sidebar shows
  the error state only when there is no cached list, otherwise an inline notice above the list.
- `SchemaController.fetchSchemas` short-circuits for a profile without `schemaRegistryUrl` (null or blank): caches
  `[]`, no error, no bridge call. This also removes a pointless failing call per connect.
- `MultiSearchController`: `Map<SearchTarget, String> _errors` with getter `errors`, set next to
  `SearchStatus.error`, removed in `_startSubscription`. `ScriptRunner._runSearchForTopic` throws
  `StateError(errors[target])` when the final status is `error`; the existing `.catchError` already sets
  `StepStatus.error` and `_stepErrorMessages`, so no new UI is needed.
*Alternative:* a generic `AsyncValue`/`LoadState` type across controllers — rejected for an S-size fix; it would
touch every reader of `getTopics`/`getSchemas` (script editor, cluster dropdown, schema dialogs).

### D3 Error rendering (B4)
- `ActionableTopicEmptyState` gets optional `errorMessage`; when set and not streaming it renders an error card
  (error icon and colours from `colorScheme.error*`, localized title, the cause as selectable text, "Retry" button
  bound to `onFetch`). `MessagesView` gets an optional `errorMessage` it passes through in its empty branch; this
  also routes to the actionable card when `onFetchLatest` is null but an error is present.
- `topic_detail_view.dart` passes `streamController.error` and, when messages are non-empty and an error exists,
  shows a compact inline error row (cause + "Retry") between the search bar and `MessagesView`.
- `explorer_view.dart` `_buildSidebarTopicList`: when `topicController.errorFor(profile)` is set and no cached topics
  exist, render an error state (icon, localized title, cause, "Retry" → `fetchTopics(force: true)`) instead of the
  `ListView`. Subject failure: one inline notice row under the topic controls with "Retry" →
  `fetchSchemas(force: true)`.
- `TopicSchemaInspectorView` already has an `_error` state; after `fetchSchemas` it copies
  `controller.errorFor(profile)` into `_error` instead of continuing with "no schema".
The existing "Error:" box for connection failures stays as is (its localization belongs to §5.32).

### D4 Tree copy (B5)
The row copy handler encodes `node.value` with `JsonEncoder.withIndent('  ')` when it is a `Map` or `List`, falls
back to `toString()` only if encoding throws, and keeps `toString()` for primitives (strings unquoted, `null` →
`'null'`). `node.value` holds the full decoded subtree for object/array rows, so collapsed or context-windowed
children are included. This mirrors `SmartCompositeBadge._copyFullObject`; a small top-level helper
`copyableNodeText(Object? value)` in the smart_tree folder is shared by both so the rule is unit-testable without
a widget.

### D5 Deterministic ordering (B6)
A top-level function `compareMessageIdentity(KafkaMessage a, KafkaMessage b)` (topic, then partition, then offset,
ascending) in `lib/src/ui/messages/` is applied after the primary comparison when it returns 0:
- `MessagesView._compareMessages`: primary field compare → identity if 0 → apply direction (tie-breaker follows the
  active direction, so descending timestamp shows the higher offset first within a partition).
- custom `sortComparator`: `cmp != 0 ? cmp : compareMessageIdentity(a, b)` (ascending; custom comparators have no
  direction toggle).
- `MessagesTableView` column sort: same pattern inside the existing comparator, direction-aware.
- `MultiSearchController.getMessagesFor(null)`: descending timestamp, then descending identity.
Cost: one extra string compare only on ties. *Alternative:* a stable merge sort — rejected: still order-dependent on
input arrival across partitions, and the spec wants a total order.

### D6 Content column filter and empty filter state
In `_filterAndSortMessages` case 4 the filter value becomes `data.message.payload ?? ''` instead of
`data.contentPreview`; lowercasing happens per row as today. The preview stays for display and sort.
When `_cachedData` is empty, `widget.messages` is not, and `_columnFilters` is non-empty, `build` wraps the table in
a `Column`: the `TableView` with only the header row (fixed header height) plus a centered empty state below with a
localized message and a "Reset filters" button that clears `_columnFilters` and rebuilds rows. Keeping the header
lets users still edit an individual filter.

### Layers and dependencies
Dart only. No new packages; `logger`, `material_ui` and `dart:convert` are already used. New ARB keys (en + de):
`messageFetchFailedTitle`, `topicsLoadFailedTitle`, `subjectsLoadFailed` (with `{error}`), `columnFiltersNoMatch`,
`resetColumnFilters`; `retry` already exists.

## Risks / Trade-offs

- [Raw error strings from Rust can be long or technical] → shown as selectable text, max lines with ellipsis in the
  sidebar; classification is out of scope.
- [Full-payload filtering on very large payloads costs more per keystroke] → it is the same `contains` on a string
  already in memory; the row count is bounded by the result limit. If it becomes visible, debounce the filter
  dialog (not planned).
- [Subject error notice on clusters with ACL-restricted registries appears on every connect] → it is the truth
  (§1 "failed must not look empty"); retry is user-triggered, no automatic polling.
- [Throwing from `_runSearchForTopic` changes script run status from "completed" to "error" for failed topics] →
  intended per `headless-script-execution`; the run manifest status already handles `error`.
- [Unreachable broker during a live stream produces an error after partial results] → partial results stay visible
  with the inline notice (spec scenario), no data is discarded.
- [Compacted/transactional topics, empty topics] → unaffected: ordering uses offsets only as tie-breakers and never
  infers gaps; an empty topic still ends with `__EOF__` and no error, so the normal empty state remains.

## Migration Plan

No persisted data changes. Sort preferences, column presets and run manifests keep their format. Rollback is a
plain revert.
