# Tasks

Dart only: `rust/` and `rust/src/api/` stay untouched, so no `cargo` steps, no `flutter_rust_bridge_codegen generate`
and no mock regeneration. Start only after `fix-result-view-defects` is merged (export handler, disabled empty menu,
tie-breaker sort). Every group writes its tests first, runs them and records the failure (RED), then implements until
they pass (GREEN).

## 1. JSON / NDJSON object shape (service)

- [ ] 1.1 Extend `test/src/services/message_export_service_test.dart`: JSON export of a message with headers,
      `valueSchema` (subject/version/id), `keySchema` `null` and timestamp `1700000000000` contains the existing
      fields unchanged (`offset`/`timestamp` as strings) plus `timestampIso: 2023-11-14T22:13:20.000Z`, `headers`
      list and schema maps; timestamp `0` → `timestampIso: null`; headers `null` → `[]`; tombstone/null key → `null`;
      payload text `null` and `''` stay strings; NDJSON single topic writes a `.ndjson` file with exactly one compact
      object per line; NDJSON multi-topic writes a ZIP with `<topic>.ndjson` entries in input order; verify RED
- [ ] 1.2 In `lib/src/services/message_export_service.dart` add `ExportFormat.ndjson`, a shared `_messageToJson`
      (design D4) with a `MessageSchema` ↔ map helper reusable by the serializer, and generalise the JSON branch over
      format and extension (design D3); verify 1.1 and all existing service tests pass

## 2. CSV fidelity (service)

- [ ] 2.1 Add service tests: null key/payload → empty unquoted field, `''` key/payload → `""`; missing projected value
      still unquoted-empty; a value with a lone `\n` is quoted; `includeHeadersColumn: true` appends a last `Headers`
      column with `[{"key":…,"value":…}]` (duplicate keys kept, `[]` without headers); without the flag the header
      row and cells equal the current output for the existing fixtures; Step cell holds `stepName` for a
      `ScriptResultMessage` and `Global` otherwise; verify RED
- [ ] 2.2 Replace `ListToCsvConverter` with the local RFC 4180 field encoder (design D5, `\r\n` rows), add the
      `includeHeadersColumn` parameter to `exportMessages`, `exportMessagesCsv` and `generateCsvContent`, fix the Step
      value (D6); remove `csv` from `pubspec.yaml` after confirming `grep -r "package:csv" lib test bin` is empty and
      `flutter pub get` succeeds; verify 2.1 and existing CSV tests pass
- [ ] 2.3 Add the new named parameter to the four `FakeMessageExportService` doubles
      (`test/src/ui/messages/messages_view_test.dart`, `messages_view_stepper_test.dart`,
      `messages_view_split_test.dart`, `test/src/features/scripting/presentation/widgets/script_run_details_view_test.dart`);
      verify `flutter analyze test` reports no override errors

## 3. Result files keep metadata

- [ ] 3.1 Add `test/src/features/search/domain/search_json_serializer_test.dart`: `serializeMessage` →
      `jsonEncode` → `jsonDecode` → `deserializeMessage` preserves headers, key/value schema and numeric
      offset/timestamp and writes `timestampIso`; a map without the new keys (old file) and one with wrongly typed
      `headers` deserialize with `headers`/schemas `null` and no exception; verify RED
- [ ] 3.2 Extend `SearchJsonSerializer` (design D7), add `super.headers`, `super.keySchema`, `super.valueSchema` to
      `ScriptResultMessage` and pass them in `ScriptRunner.loadRunResults`; extend
      `test/src/features/scripting/presentation/controllers/script_runner_test.dart` with a run directory containing
      one new-format and one old-format `search_results_*.json` plus one malformed file: both valid files load, the
      new one with headers and schema, the malformed one is skipped; verify GREEN

## 4. Localization (en + de)

- [ ] 4.1 Add keys to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: `exportAsNdjson` ("NDJSON (One Message per
      Line)" / "NDJSON (eine Nachricht pro Zeile)"), `exportSelectedOnly` with `{count}` placeholder,
      `exportIncludeDimmedNonMatches`, `exportAddHeadersColumn`, `exportOptionsSection`, `exportFormatSection`; run
      `flutter gen-l10n` and verify the getters exist in `lib/l10n/app_localizations.dart`

## 5. Export menu and scope (MessagesView)

- [ ] 5.1 Extend `test/src/ui/messages/messages_view_test.dart` (fake records the list and flags): menu shows JSON,
      NDJSON, CSV; the headers-column option is present; the selection option is absent without a selection and
      shows the count with one; the dimmed-non-matches option appears only with active search + "show non-matches";
      toggling an option keeps the menu open and does not call the service; with search + "show non-matches" the
      export contains only matches unless the option is on; with a table column filter and column sort the exported
      list equals the table's visual order; "only selected" exports only the selected message; NDJSON passes
      `ExportFormat.ndjson`; adapt the two existing menu tests to the new entries; verify RED
- [ ] 5.2 Track `_cachedNonMatches` in `_updateFilters`, add `_selectedMessagesForExport`, the option flags (reset when
      selection or search is cleared) and `_exportScope` (design D1) in `lib/src/ui/messages/messages_view.dart`;
      verify `flutter analyze lib/src/ui/messages` is clean and the scope cases of 5.1 pass once 5.3 wires the menu
- [ ] 5.3 Replace the export `PopupMenuButton<ExportFormat>` with a `MenuAnchor` (design D2): conditional
      `CheckboxMenuButton(closeOnActivate: false)` options, divider, JSON / NDJSON / CSV items, tooltip and semantic
      label on the icon button, all strings from `AppLocalizations`; pass `_exportScope` and `includeHeadersColumn`;
      verify 5.1 passes, plus the prerequisite's cancelled-export and disabled-menu tests still pass
- [ ] 5.4 If `message-selection-copy-and-display` is merged, point `_selectedMessagesForExport` at its multi-selection
      and add a test exporting three selected messages in displayed order; otherwise keep the single-selection getter
      and note in the implementation report that 5.27 must switch this one getter

## 6. Final verification

- [ ] 6.1 `dart format --set-exit-if-changed lib test`, `flutter analyze` (no new issues), `flutter test` (all green)
- [ ] 6.2 `scripts/check_read_only.sh` passes unchanged
- [ ] 6.3 Manual check on a desktop build: export a filtered/sorted table as JSON, NDJSON and CSV (with Headers
      column), a multi-topic script run as ZIP, and reopen an older script run; confirm the files open in the
      completion notification's "Open" action and the content matches the displayed rows
