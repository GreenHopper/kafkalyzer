# Design: message-export-fidelity

## Context

See `proposal.md` (Why, What Changes) for motivation and the code locations that were verified. Requirements are in
`specs/message-csv-export/spec.md`. Relevant current state:

- `MessagesView` is shared by the topic view, consumer-lag messages view and script run views; it owns the export
  menu (`PopupMenuButton<ExportFormat>`, `messages_view.dart:857-935`) and already knows the displayed order:
  `_activeOrderedMessages` returns the table's reported visual order (`onVisualOrderChanged`, which reflects column
  filters and column sort) in table view and `_cachedSortedMessages` otherwise (`messages_view.dart:477-482`).
- `_updateFilters` decides per message whether it matches the in-memory search; with `_showNonMatches` it keeps the
  non-matches in the list and the table/timeline dim them.
- After `fix-result-view-defects` the export handler shows success only for a non-null path, the menu is disabled for
  an empty list, and all sorts use topic/partition/offset as tie-breakers.
- `MessageExportService` is Dart-only; `ListToCsvConverter` (`csv` 6.0.0) writes `null` as the text `null` unless
  `convertNullTo` is set and has no way to quote a single empty field. `csv` has no other importer.
- `KafkaMessage` (generated, `lib/src/rust/api/kafka_consumer.dart`) already carries `headers`
  (`List<KafkaHeader>?`, value is UTF-8 text or `0x<hex>` for binary) and `keySchema` / `valueSchema`
  (`MessageSchema{schemaId, subject?, version?}`). No bridge change is needed.
- `search_results_*.json` are written by `MultiSearchController` through `SearchJsonSerializer.serializeMessage`
  (numeric `offset` / `timestamp`) and read back by `ScriptRunner.loadRunResults` via `deserializeMessage`, which maps
  into `ScriptResultMessage` (no headers/schema constructor parameters today).

## Goals / Non-Goals

**Goals:**
- One place computes the export scope (view), one place serializes (service); formats share one object shape.
- Old readers of JSON exports, CSV defaults and saved result files keep working.

**Non-Goals:**
- Moving serialization to Rust: there is a single caller and the data is already in Dart. If the MCP server
  (§5.17) later needs the same object shape it can be re-homed in `kafkalyzer-core` then.
- Background-isolate or streamed serialization (existing behaviour, see Risks).

## Decisions

### D1 Export scope computed in `MessagesView`
New private getter `_exportScope` returns the list handed to the service:
1. base = `_activeOrderedMessages` (copied, so a live stream cannot mutate it during export);
2. unless `_exportIncludeNonMatches`, drop messages that `_updateFilters` classified as non-matches — tracked as an
   identity set `_cachedNonMatches` filled in the same loop (no second predicate that could drift);
3. if `_exportSelectedOnly`, keep only messages in the view's selection (identity), preserving step 1 order.

Selection source: whatever `MessagesView` holds as selection — today `_selectedMessage` (0 or 1), after
`message-selection-copy-and-display` its multi-selection set. The implementation reads the selection through one
getter (`_selectedMessagesForExport`) so the 5.27 merge only changes that getter.
The option flags are per-view state, reset to off when the selection becomes empty or the search is cleared; they are
not persisted.
*Alternative:* let the table export its own rows — rejected: timeline/diff views would need a second path, and the
table already reports its visual order.
*Known gap:* the table dims using a slightly wider match (also projected values, `messages_table_view.dart:943-957`)
than `_updateFilters`. Export follows `_updateFilters`; aligning the predicates belongs to 5.27's quick-filter work.

### D2 Menu: `MenuAnchor` instead of `PopupMenuButton`
The export button becomes a `MenuAnchor` (pattern already used for the column menu, `messages_view.dart:759`) with
`CheckboxMenuButton(closeOnActivate: false)` entries for the applicable options (spec: *Options shown only when they
apply*), a divider, then three `MenuItemButton`s JSON / NDJSON / CSV that close the menu and start the export. The
icon button keeps `Icons.download`, the existing tooltip and gains a semantic label. Widgets come from
`package:material_ui/material_ui.dart`.
*Alternative:* an options dialog after choosing the format — rejected: an extra click for every export, and the
spec forbids extra persistent toolbar space only, so an inline menu is the smaller change.

### D3 Service API (additive)
`enum ExportFormat { json, ndjson, csv }`; `exportMessages(messages, {format, columnConfig, isScriptingView,
bool includeHeadersColumn = false})`; `exportMessagesCsv` / `generateCsvContent` gain the same flag. The
existing JSON/ZIP branch is generalised over format (content builder + extension), so NDJSON reuses the single-file
and per-topic ZIP paths. Callers and the four test fakes compile with one added named parameter.

### D4 One message object for JSON and NDJSON
`_messageToJson(KafkaMessage)` builds the map; JSON = `JsonEncoder.withIndent('  ')` over the list, NDJSON =
`jsonEncode` per message joined by `\n` with a trailing newline. Field rules:
- existing `offset` / `timestamp` stay strings (existing tests and readers expect `'100'`);
- `timestampIso` = `DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true).toIso8601String()`, `null` when `ts == 0`
  (Rust maps "no timestamp" to 0, `kafka_consumer.rs:938`) — UTC regardless of the 5.27 display setting so files are
  unambiguous;
- `headers` = `[{key, value}]` in broker order, `[]` when `null`; values as delivered (text or `0x…`);
- `keySchema` / `valueSchema` = `{schemaId, subject, version}` or `null`;
- `payload`: parsed JSON if it parses, else the raw string; a non-null payload whose parse result is `null`
  (payload text `null`) stays the string, so only tombstones become `null`.

### D5 CSV null vs. empty with a local field encoder
Replace `ListToCsvConverter` with a ~15-line `_csvField(Object? v)`: `null` → empty unquoted; `''` → `""`; quote when
the value contains `,`, `"`, CR or LF (doubling `"`); rows joined by `\r\n` (the converter's default EOL, kept).
Key/Payload pass `null` through. Cells that are empty today for other reasons (missing projected value, unknown
column) pass `null` too, so they stay unquoted-empty as before. Side effect: `csv` 6 quotes only on the full `\r\n`
sequence, so a value with a lone `\n` was written unquoted (an RFC 4180 violation of the existing spec); the local
encoder quotes it. Remove `csv` from `pubspec.yaml`.
*Alternatives:* upgrade to `csv` 8 (`QuoteMode.strings`) — quotes every string, changes all existing CSV bytes and
the package API; a literal `null` token — ambiguous with a key whose text is `null`; a separate "Tombstone" column —
extra column in default output.

### D6 Headers column and Step value
`includeHeadersColumn` appends a `Headers` header and per row `jsonEncode(headers ?? [])`. The Step cell uses
`msg is ScriptResultMessage ? msg.stepName : 'Global'`, the value the table renders
(`messages_table_view.dart:396`).

### D7 Result files round trip
`serializeMessage` adds `timestampIso`, `headers`, `keySchema`, `valueSchema` (same shapes as D4; `offset` and
`timestamp` stay numeric because `deserializeMessage` reads them as numbers). `deserializeMessage` reads the new keys
defensively (missing or wrongly typed → `null`). `ScriptResultMessage` forwards `super.headers`, `super.keySchema`,
`super.valueSchema`; `loadRunResults` passes them. A small shared helper converts `MessageSchema` ↔ map for both the
export service and the serializer to avoid two shapes.

## Risks / Trade-offs

- [Large result sets: whole-file string built on the UI isolate, as today] → unchanged behaviour; NDJSON makes a later
  streamed writer straightforward. Out of scope.
- [Table visual order arrives one frame after a rebuild] → export may use the previous frame's order during a live
  stream; acceptable, the stream is changing anyway. When no order was reported yet, `_activeOrderedMessages` falls
  back to the view-sorted list.
- [Spreadsheet tools treat `""` and an empty field the same] → JSON/NDJSON is the faithful format; CSV keeps the
  distinction for RFC 4180 parsers that honour quoting.
- [Compacted/transactional topics, empty topics, ACL-limited reads] → unaffected: export only serializes loaded
  messages; offset gaps are irrelevant; an empty scope keeps the menu disabled (prerequisite) and the service returns
  `null` without a dialog.
- [Header `null` vs. empty value not distinguishable] → Rust delivers `""` for both; documented as non-goal.

## Migration Plan

No stored data migrates. New JSON fields and result-file fields are additive; default CSV columns are byte-identical
except that empty strings in Key/Payload become `""` (previously indistinguishable from tombstones) and values with a
lone line feed are now quoted (D5). Rollback: revert
the change; files written by the new version remain readable by the old `deserializeMessage` (unknown keys ignored).
