# Proposal: fix-result-view-defects

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.23 (change id `fix-result-view-defects`, size S),
motivated by the code-review findings B3, B4, B5 and B6 in §2.4, under the guardrails of §1 (L1, L5). Phase 0b
("correctness") in §6.

## Why

The result views show wrong or misleading results. A cancelled export reports success, a failed fetch looks like
"no messages" or "no topics", copying an object node from the tree yields Dart `toString()` output instead of JSON,
messages with equal sort keys jump between live updates, and the table's Content filter only matches the first
300 characters of a pruned preview. Users draw wrong conclusions from these views against production clusters, so
the defects are fixed before new result-view features land.

## What Changes

- **Cancelled export (B3):** `MessagesView` shows a success SnackBar when `MessageExportService.exportMessages`
  returns `null` (save dialog cancelled, `messages_view.dart:871-884`). A `null` result now shows nothing, and the
  export menu is disabled while there is nothing to export (the service also returns `null` for an empty list). The
  other export call sites (topic analysis, script export, run archive, schema markdown, cluster and configuration
  export) were checked and already handle `null` correctly. **Fix without spec delta:** `downloaded-file-actions`
  *Save Dialog Cancellation Handling* already requires this behaviour.
- **Swallowed load and stream errors (B4):**
  - `MessageStreamController` keeps the error from `onError` and from a failed stream start
    (`message_stream_controller.dart:148-162`) and clears it on the next start. The topic message view shows an error
    state with the cause and a "Retry" action instead of the "no messages loaded" card; when some messages arrived
    before the failure, an inline error banner is shown above them.
  - `TopicController.fetchTopics` and `SchemaController.fetchSchemas` (`topic_controller.dart:27-33`,
    `schema_controller.dart:30-36`) keep the error per cluster instead of `debugPrint` only. The explorer sidebar
    shows a topic-list error state with cause and "Retry" instead of an empty list with count `0`, and a subject load
    failure as an inline notice with "Retry"; a cluster without Schema Registry URL is not an error. The topic schema
    inspector shows the subject load error instead of "no schema".
  - `MultiSearchController` keeps the error message per target (`multi_search_controller.dart:376-395`); the script
    runner marks that topic step as failed with the message instead of "completed" with zero hits. **Fix without
    spec delta:** `headless-script-execution` already requires step failures to be reported.
- **Tree copy (B5):** the row copy action of `SmartVirtualJsonTree` (`smart_virtual_json_tree.dart:304`) copies
  object and array nodes as pretty-printed JSON; primitives keep their plain value.
- **Deterministic sort (B6):** every message sort uses topic, partition and offset as tie-breakers after the
  primary key: `MessagesView._compareMessages` (`messages_view.dart:397-409`, including a custom `sortComparator`
  such as the script run view), the table's column-header sort (`messages_table_view.dart:460-516`) and the
  aggregated multi-search list (`multi_search_controller.dart:179`).
- **Table column filter:** the Content column filter matches the full payload instead of the truncated,
  null-pruned preview (`messages_table_view.dart:434-436`, `text_preview_utils.dart:35-38`). When the active column
  filters hide every row, the table shows an empty state with a "Reset filters" action.

Read-only impact: no new Kafka or Schema Registry calls. "Retry" repeats the existing read-only fetch
(`fetch_topics`, `fetch_subjects`, `consume_with_filter`). `scripts/check_read_only.sh` must pass unchanged.

Prerequisites: none. Layers: Dart only; no Rust or bridge change.

Non-goals:
- Export content or format changes, exporting the table's filtered/sorted view, NDJSON (`message-export-fidelity`,
  §5.28).
- Topic-list scaling, list age, ACL "not readable" markers, invented metadata for unknown topics
  (`topic-list-scale-and-organisation`, §5.33).
- Localizing the remaining hard-coded texts (connection error box, table filter dialog, run archive SnackBar) and
  closable/copyable error boxes (`accessibility-and-l10n-sweep`, §5.32).
- Halting later script steps after a failure, step expectations (`script-robustness-and-ci-expectations`, §5.39).
- Error indicators on topic tabs, changing the Content column sort key, new sort fields.

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `message-sort-order`: MODIFIED *Ordering of displayed messages by selected field* (topic, partition, offset as
  tie-breakers for every sort, including table column headers and custom view comparators).
- `explorer-onboarding`: MODIFIED *Actionable Empty State in Topic Message View* (not shown after a failed fetch);
  ADDED *Load Failure Error States in Explorer* (consumption, topic list and subject failures shown with cause and
  retry, distinct from empty states).
- `smart-virtual-json-tree`: ADDED *Copy Tree Node Value as JSON*.
- `message-table-columns`: ADDED *Column Filters Match Full Values with Empty Filter State*.

Fixed without spec delta: `downloaded-file-actions` (B3), `headless-script-execution` (multi-search step error).

## Impact

- `lib/src/ui/messages/messages_view.dart` — export result handling, export menu enabled state, tie-breaker in
  `_compareMessages`, error state pass-through to the empty state.
- `lib/src/ui/messages/views/messages_table_view.dart` — Content filter on full payload, tie-breaker in column sort,
  empty filter state with reset.
- `lib/src/ui/messages/widgets/actionable_topic_empty_state.dart` — error variant with retry.
- `lib/src/features/topic/presentation/controllers/message_stream_controller.dart`,
  `lib/src/features/topic/presentation/controllers/topic_controller.dart`,
  `lib/src/features/schema/presentation/controllers/schema_controller.dart`,
  `lib/src/features/search/presentation/controllers/multi_search_controller.dart`,
  `lib/src/features/scripting/presentation/controllers/script_runner.dart` — error state.
- `lib/src/features/topic/topic_detail_view.dart`, `lib/src/features/explorer/presentation/explorer_view.dart`,
  `lib/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart` — error rendering and retry.
- `lib/src/ui/smart_tree/smart_virtual_json_tree.dart` — JSON copy.
- New shared message comparator helper (Dart), `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`, tests.
