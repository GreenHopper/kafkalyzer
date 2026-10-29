# Tasks

## 1. File Opening Service & Localization

- [x] 1.1 Add localized strings for "Open", "Show in Folder", "Failed to open file", and "Failed to open folder" to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify `flutter gen-l10n` updates localization files.
- [x] 1.2 Implement `FileOpenerService` in `lib/src/services/file_opener_service.dart` with `openFile(String filePath)` and `showInFolder(String filePath)` supporting Linux, macOS, and Windows with proper error logging and safety checks.
- [x] 1.3 Register `FileOpenerService` in `lib/src/dependency_injection.dart` and implement a reusable `showExportSuccessSnackBar(BuildContext context, ...)` method providing "Open" and "Show in Folder" buttons.
- [x] 1.4 Write unit tests for `FileOpenerService` covering missing file handling, directory resolution, and command dispatch fallback in `test/src/services/file_opener_service_test.dart`.

## 2. Export Services Updates & Cancellation Safety

- [x] 2.1 Update `MessageExportService.exportMessages` and `exportMessagesCsv` in `lib/src/services/message_export_service.dart` to return `Future<String?>` (the saved file path, or `null` if cancelled by user).
- [x] 2.2 Update existing tests in `test/src/services/message_export_service_test.dart` to verify returned file paths and cancellation behavior.

## 3. UI Integration Across Export Entry Points

- [x] 3.1 Update `lib/src/ui/messages/messages_view.dart` to check for non-null output path from `exportMessages` and show the export success notification with "Open" and "Show in Folder" actions.
- [x] 3.2 Update `lib/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart` to display "Open" and "Show in Folder" actions when topic analysis reports are exported.
- [x] 3.3 Update `lib/src/features/settings/presentation/settings_view.dart` to display "Open" and "Show in Folder" actions when cluster profiles or settings configurations are exported.
- [x] 3.4 Update `lib/src/features/scripting/presentation/script_manager_view.dart`, `script_history_list.dart`, and `script_schemas_view.dart` to display "Open" and "Show in Folder" actions when scripts, run archives, or schemas are exported.

## 4. Verification & Quality Assurance

- [x] 4.1 Run widget and unit tests using `flutter test` and verify all export and file-opener tests pass.
- [x] 4.2 Run `dart analyze` to ensure code conforms to lint rules and analysis options without warnings or errors.
