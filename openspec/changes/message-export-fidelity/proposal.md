# Proposal: message-export-fidelity

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.28 (change id `message-export-fidelity`, size S–M),
motivated by finding C ("Export ohne Header und ohne Schema-Angaben, Export-Umfang weicht von der sichtbaren Tabelle
ab, Tombstone nicht von leerem Wert unterscheidbar") in §2.4, under the guardrails of §1 (L1, L5). Phase 1.

## Why

A message export is what users attach to tickets and feed into other tools, but today it differs from what they see:
it ignores the table's column filters and sort, includes greyed-out non-matches, drops headers and schema provenance,
has only a bare epoch timestamp, and writes a tombstone as an empty CSV cell. Users therefore hand over data that does
not match their analysis and lose exactly the metadata they need to diagnose producers.

## What Changes

Verified in code (deviations from the roadmap noted):

- **Export scope = what is displayed.** `MessagesView` passes `_cachedFilteredMessages` (`messages_view.dart:864`):
  unsorted, without the table's column filters (`messages_table_view.dart:415-456`) and including dimmed non-matches
  when "show non-matches" is on (`messages_view.dart:388`). The export now uses the active view's displayed order
  (`_activeOrderedMessages`: table visual order with column filters and sort, otherwise the view-sorted list) and
  leaves out dimmed non-matches unless the user opts in. When a message selection exists, "only selected messages"
  can be chosen; the option is hidden without a selection.
- **JSON gains metadata (additive).** `_serializeMessages` (`message_export_service.dart:368-382`) writes only topic,
  partition, offset, timestamp, key and payload. New fields: `timestampIso` (ISO-8601 UTC), `headers` (list of
  `{key, value}`), `keySchema` and `valueSchema` (`{schemaId, subject, version}` or `null`, from `KafkaMessage`'s
  `MessageSchema` fields — the roadmap's "MessageSchemaProvenance" type does not exist under that name). Existing
  fields keep their names and string types.
- **NDJSON** becomes a third format (one compact JSON object per line, same object shape as JSON, `.ndjson`).
- **CSV header column.** An opt-in "Headers" column (JSON array of `{key, value}`) is appended after the existing
  columns; default output is byte-compatible with today's columns.
- **Tombstones / null keys.** JSON already writes `null` for a missing key or payload; the gap is CSV, which writes
  `''` for both `null` and an empty string (`message_export_service.dart:295-300`), and JSON, which turns a payload
  whose text is `null` into JSON `null`. CSV now writes `null` as an empty unquoted field and an empty string as
  `""`; JSON keeps a non-null payload non-null.
- **CSV Step column** is exported as an empty string (`message_export_service.dart:286-287`) although the table shows
  the step name; it now carries the displayed step name.
- **Script result files keep metadata.** `SearchJsonSerializer.serializeMessage` (auto-saved `search_results_*.json`)
  drops headers and schemas; they are added. The only reader of exported/saved message JSON is
  `ScriptRunner.loadRunResults` (`script_runner.dart:577-595`) via `deserializeMessage`; it reads the new fields when
  present and still loads old files. No importer reads `MessageExportService` output (checked: run-archive import
  copies files byte-wise, shareable references are URIs, topic-analysis import uses its own format).

Read-only impact: no new Kafka or Schema Registry calls; export uses only messages already in memory.
`scripts/check_read_only.sh` must pass unchanged. Layers: Dart only; no Rust or bridge change.

Prerequisites (implemented first):
- `fix-result-view-defects` (§5.23): cancelled export no longer reports success, export menu disabled when empty,
  deterministic tie-breaker sort. This change builds on that export handler and does not repeat it.
- Soft dependency on `message-selection-copy-and-display` (§5.27): it introduces multi-selection. "Only selected" uses
  whatever selection `MessagesView` holds — the single selected message before 5.27, the multi-selection after it.

Non-goals:
- Selection model, copy actions, local/UTC display setting (§5.27); export timestamps are always UTC.
- Changing existing JSON field names/types or the default CSV columns; ISO timestamps in CSV.
- Streaming exports to disk for very large result sets; a single-file multi-topic NDJSON.
- Distinguishing a `null` header value from an empty one (Rust maps both to `""`, `kafka_consumer.rs:923-927`).
- Leftover hard-coded strings such as the save-dialog titles (§5.32); any write access to Kafka (L1).

## Capabilities

### New Capabilities
- none

### Modified Capabilities
- `message-csv-export`: MODIFIED *Integrated Message Export Format Selection* (NDJSON, scope and option entries),
  *RFC 4180 Compliant CSV Generation* (displayed rows and order, null vs. empty, optional Headers column),
  *Multi-Topic CSV Export Bundling* (all formats); ADDED *Export Scope Matches The Displayed Messages*,
  *JSON And NDJSON Export Content*, *Script Result Files Preserve Message Metadata*.

Fixed without spec delta: none (`downloaded-file-actions` cancellation is handled by `fix-result-view-defects`).

## Impact

- `lib/src/services/message_export_service.dart` — `ExportFormat.ndjson`, JSON object shape, CSV null/empty handling,
  Headers column option, Step value; local RFC 4180 field encoder replaces `ListToCsvConverter` (which cannot quote
  an empty string), so the `csv` dependency is dropped from `pubspec.yaml`.
- `lib/src/ui/messages/messages_view.dart` — export menu (`MenuAnchor` with format entries and option checkboxes),
  export scope computation.
- `lib/src/features/search/domain/search_json_serializer.dart`,
  `lib/src/features/scripting/domain/script_result_message.dart`,
  `lib/src/features/scripting/presentation/controllers/script_runner.dart` — additive fields and round trip.
- `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`; tests and the four `FakeMessageExportService` doubles in
  `test/src/ui/messages/` and `test/src/features/scripting/`.
