<!-- markdownlint-disable MD041 -->
## Why

A topic content analysis on large topics is expensive: it scans every partition end-to-end and can take many minutes. Today the resulting `TopicAnalysisReport` exists **only in memory** (`TopicAnalysisController._report`) — once the user closes the topic detail view, switches topics, or restarts the app, the analysis is gone and must be re-run from scratch. This makes it impossible to revisit a finished analysis, compare a topic over time, or hand the results to a colleague who has no access to the same cluster (or wants to avoid the cost of re-scanning).

## What Changes

- **Export analysis report**: Add an "Export" action in the Topic Analysis view that serializes the current `TopicAnalysisReport` to a single, portable, self-describing JSON file (a versioned envelope wrapping the report plus export metadata such as cluster name and export timestamp). The user picks the destination via the standard save-file dialog, consistent with existing message/profile exports.
- **Import analysis report**: Add an "Import" action that opens a JSON analysis file, validates its format/version, deserializes it, and renders the report in the **same analysis dashboard** (summary cards, hourly chart, partition balance, key/field distributions) **without re-running the scan**.
- **Share by file**: The exported JSON is a single portable artifact that a user can send to a colleague, who imports it in their own Kafkalyzer instance and views the full dashboard — no cluster access required.
- **Source-of-truth indicator**: When a report is displayed, the UI SHALL distinguish an **imported** report from a **live** one (e.g. a subtle "Imported" badge with the original cluster name and export timestamp), so a stale/imported analysis is not mistaken for a fresh scan.
- **Graceful handling**: Malformed, truncated, or incompatible-version files SHALL be rejected with a clear user-facing message (SnackBar/dialog) rather than failing silently; a valid report SHALL be importable regardless of whether that topic still exists on any reachable cluster.
- **Localization**: All new user-facing strings (button labels, badges, success/error messages, file-type filters) added to `app_en.arb` and `app_de.arb` via `AppLocalizations`.

Non-goals (assumed, kept for scope): an in-app persistent "saved reports" history/library, multi-report bundles, or server-based sharing — the portable file **is** the persistence and sharing unit. See design.md for the reasoning.

## Capabilities

### New Capabilities

- `topic-analysis-export-import`: Export a completed topic content analysis report to a portable, versioned JSON file; import such a file to re-render the full analysis dashboard without re-running the scan; and share the file with another user or instance.

### Modified Capabilities

<!-- None. `topic-content-analysis` (running the scan and presenting live results) keeps its existing requirements unchanged; this change only adds the ability to persist, restore, and share a finished report. -->

## Impact

- **Frontend (Flutter/Dart)**:
  - New service (e.g. `TopicAnalysisExportService`) for serializing/deserializing the report envelope and picking/reading/writing files, reusing the established `file_picker` + `archive` patterns from `MessageExportService` / `SettingsService`.
  - `TopicAnalysisController` (or the view) gains the ability to hold a **static imported report** alongside the live report and to expose "is imported" + provenance metadata; the existing presentational dashboard widgets (`TopicAnalysisSummaryCards`, `HourlyProductionChart`, `PartitionBalanceView`, `KeyAndFieldDistributionView`) already accept a report and are reused unchanged.
  - `TopicAnalysisView` controls bar gains Export/Import actions, an imported-report indicator, and error feedback via SnackBar.
  - New DI registration in `dependency_injection.dart` (get_it).
- **Backend (Rust)**: No new Rust API is strictly required — the report types already derive `Serialize`/`Deserialize` and are surfaced through the bridge. Export/import is a pure Dart-side (de)serialization of the already-generated report types. (If an envelope type is desired on the Rust side it is optional; see design.md alternatives.)
- **Localization**: `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- **Dependencies**: No new packages expected — `file_picker` and `archive` are already used; JSON handled by core `dart:convert`.
