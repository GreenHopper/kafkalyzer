# Proposal

## Why

When users export messages, topic analysis reports, scripts, run archives, or cluster configurations in Kafkalyzer, they currently receive only a static SnackBar notification confirming the export without any path link or quick action. Users must then manually switch to their operating system's file manager and navigate their directory tree to find and open the saved file or folder, creating unnecessary friction in analytical workflows.

## What Changes

- Introduce a reusable, cross-platform file opening and revealing service (`FileOpenerService`) supporting Linux (`xdg-open`), macOS (`open`, `open -R`), and Windows (`explorer.exe`, `explorer.exe /select,`).
- Introduce an interactive completion notification affordance (e.g. SnackBar or banner with action buttons) after file downloads/exports that provides:
  - An **"Open File"** action to launch the exported file with the system's default application.
  - An **"Open Folder"** / **"Show in Folder"** action to reveal or open the containing directory in the native file explorer.
- Update `MessageExportService` to return the saved file path (or `null` if cancelled by the user) and suppress false-positive success notifications when the save dialog is cancelled.
- Integrate the file/folder open affordance across all file download/export entry points:
  - Message export (JSON, CSV, and multi-topic ZIP archives).
  - Topic content analysis report export.
  - Cluster profile and application settings exports.
  - Script definitions, script execution run archives, and schema exports.
- Provide graceful error feedback if opening a file or folder fails or if the target path is no longer accessible.

## Capabilities

### New Capabilities
- `downloaded-file-actions`: Cross-platform affordances and system integration allowing users to open downloaded/exported files in their default application or reveal their containing folder in the desktop file manager upon completion.

### Modified Capabilities
*(None)*

## Impact

- **Frontend / UI**:
  - `lib/src/ui/messages/messages_view.dart`: Toolbar export handler displays completion actions with "Open" and "Show in Folder".
  - `lib/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart`: Analysis report export confirmation includes file/folder open actions.
  - `lib/src/features/settings/presentation/settings_view.dart`: Cluster and configuration export notifications include file/folder open actions.
  - `lib/src/features/scripting/presentation/script_manager_view.dart`, `script_history_list.dart`, and `script_schemas_view.dart`: Script, archive, and schema export notifications include file/folder open actions.
  - `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: Localized strings for actions ("Open", "Show in Folder", "Failed to open file", "Failed to open folder").
- **Services**:
  - New service `lib/src/services/file_opener_service.dart` registered in `get_it`.
  - `lib/src/services/message_export_service.dart`: Return exported file path `String?` from `exportMessages` and `exportMessagesCsv`.
  - `lib/src/services/topic_analysis_export_service.dart`: Return exported file path `String?`.
- **Dependencies**: Uses Dart's `dart:io` (`Process.run`, `Platform`) and/or existing `url_launcher`. No new external pub dependencies required.
