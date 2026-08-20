<!-- markdownlint-disable MD041 -->
<!-- No Rust or flutter_rust_bridge work is required for this change (design D1: serialization is authored in Dart on the already-generated report types). Work therefore starts directly with the Dart model. -->

## 1. File model & (de)serialization

- [x] 1.1 Create `TopicAnalysisReportFile` model holding the envelope (`kafkalyzer` identifier, `version`, `exportedAt`, optional `clusterName`) plus the `TopicAnalysisReport` payload; declare the supported-version set `{1}`
- [x] 1.2 Implement `toMap()` / `toJson()` producing the canonical snake_case shape from design D1, converting `PlatformInt64` to plain `int` so the map is `json.encode`-safe
- [x] 1.3 Implement `fromMap()` / `fromJson()` reconstructing the report and nested lists (`PartitionAnalysis`, `HourlyCount`, `KeyOccurrence`, `TypeOccurrence`, `FieldOccurrence`, `FieldValueOccurrence`) and wrapping ints back into `PlatformInt64`
- [x] 1.4 Add typed validation that throws distinct errors for: wrong/missing identifier (`notAnAnalysisFile`), unsupported version (`unsupportedVersion`, carrying the found version), and malformed/missing report fields (`malformed`)
- [x] 1.5 Add a unit test round-tripping an empty and a fully populated report (all sub-lists incl. `top_values`) through `toJson` → `fromJson` and asserting field equality; add tests for each validation error path

## 2. Export / import service (file IO)

- [x] 2.1 Create `TopicAnalysisExportService.export(TopicAnalysisReportFile)` using `FilePicker.saveFile(allowedExtensions: ['json'])` with default filename `<topic>_analysis_<yyyyMMdd_HHmmss>.json`; return the written path or `null` on cancel; catch and surface IO write errors
- [x] 2.2 Add `TopicAnalysisExportService.importFile()` using `FilePicker.pickFiles` (single file, `.json`, `withData: true`), read bytes, decode, validate, and return `TopicAnalysisReportFile` or throw the typed import error
- [x] 2.3 Register the service in `dependency_injection.dart` via `get_it`
- [x] 2.4 Add service unit tests covering the success path and each error type by exercising the pure decode/encode path (no real dialogs)

## 3. Controller state (source + provenance)

- [x] 3.1 Add `enum TopicAnalysisSource { live, imported }`, a `_reportSource` field, and an `isImported` getter to `TopicAnalysisController`
- [x] 3.2 Add provenance fields `reportClusterName` and `reportExportedAt` with getters
- [x] 3.3 Add `exportReport({String? clusterName})` and `importReport()` orchestrators that call the service, update `_report` / `_reportSource` / provenance, `notifyListeners()`, and map typed import errors to a user-facing result
- [x] 3.4 Ensure `startAnalysis(...)` resets source to `live` and clears imported provenance, and `clear()` resets to defaults so a fresh scan is never mistaken for an import
- [x] 3.5 Add controller unit tests for import/export state transitions, provenance population, and the live-scan reset behavior

## 4. UI integration (material_ui)

- [x] 4.1 In `TopicAnalysisView`'s controls bar, add an **Import** button (always enabled) and an **Export** button (enabled only when a report is available) using `package:material_ui`
- [x] 4.2 Add loading feedback (disabled button + `CircularProgressIndicator`) during import/export and confirm the dashboard renders from an imported report when none was previously shown
- [x] 4.3 Add a localized "Imported" indicator `Chip` showing `clusterName` and the export time when `controller.isImported`; ensure a live report shows no such indicator
- [x] 4.4 Surface success and errors via `SnackBar`, and keep the empty-state behavior correct when importing with no current report
- [x] 4.5 Add a widget test: importing a report renders the dashboard widgets and the imported indicator; export is enabled only when a report exists

## 5. Localization

- [x] 5.1 Add all new strings to `app_en.arb`: import/export labels, the imported-indicator text, success messages, and the error messages (`not a valid analysis file`, `unsupported version`, `malformed`, `could not export`)
- [x] 5.2 Add the corresponding German strings to `app_de.arb`
- [x] 5.3 Regenerate l10n and confirm no hardcoded user-facing strings remain in the new code

## 6. Verification

- [x] 6.1 `dart format` and `flutter analyze` are clean
- [x] 6.2 `flutter test` passes (model, service, controller, and widget tests)
- [ ] 6.3 Manual smoke test (live environment): run an analysis → export → close/reopen the topic → import the file → confirm the dashboard renders and the imported indicator shows; then import a malformed file, a wrong-version file, and a non-analysis file and confirm each is rejected with a clear localized message. (Each of these behaviors is covered by the automated tests in 6.2; only the live-cluster end-to-end GUI pass needs a real environment.)
- [x] 6.4 `openspec validate topic-analysis-export-import` passes and every spec scenario is covered by a test or the manual smoke test
