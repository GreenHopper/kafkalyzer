# Tasks

## 1. Dependencies and Localization Setup

- [x] 1.1 Add `csv` and `flutter_secure_storage` dependencies to `pubspec.yaml` and verify dependency resolution succeeds via `flutter pub get`
- [x] 1.2 Add localized strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for export format options, search presets, session restoration settings, CLI command copying, and keyring security indicators, and verify `flutter gen-l10n` runs without errors

## 2. B6: Projected Column CSV Message Export

- [x] 2.1 Implement CSV serialization logic in `MessageExportService` to output RFC 4180 compliant CSV using visible standard columns and dynamic JSONPath projected columns, verifying with unit tests in `test/src/services/message_export_service_test.dart`
- [x] 2.2 Add multi-topic CSV export support bundling individual topic CSVs into a single `.zip` archive, verifying with unit tests for multi-topic message collections
- [x] 2.3 Update `MessagesView` toolbar export action from a single download button to a compact `PopupMenuButton<ExportFormat>` offering JSON and CSV formats without altering toolbar layout, and verify via widget test in `test/src/ui/messages/messages_view_test.dart`

## 3. B7: Reusable Topic Search Presets

- [x] 3.1 Create `SavedSearchesService` and `TopicSearchPreset` domain model to persist named search configurations in `SharedPreferences` scoped by cluster and topic, verifying with unit tests in `test/src/services/saved_searches_service_test.dart`
- [x] 3.2 Integrate compact preset selector and "Save Search" dialog into `SearchStreamConfiguration`, verifying that selecting a preset populates all filter and scan inputs via widget tests
- [x] 3.3 Add preset deletion and update capabilities in `SavedSearchesService` and verify preset lifecycle in unit and widget tests

## 4. B8: Workspace Tab Session Persistence

- [x] 4.1 Create `SessionRestoreService` to save open tab topic names and the active tab selection per cluster in `SharedPreferences`, verifying with unit tests in `test/src/services/session_restore_service_test.dart`
- [x] 4.2 Integrate session persistence and automatic tab restoration into `ActiveConnectionController` upon cluster connection, verifying with controller tests
- [x] 4.3 Add "Restore open tabs on startup" toggle in General Settings (`SettingsView`), verifying setting persistence and bypass behavior when disabled via widget tests

## 5. B9: Headless Script Pipeline Runner

- [x] 5.1 Extract headless execution logic and parameter resolver from `ScriptRunner` so scripts can run in non-GUI Dart processes, verifying with unit tests in `test/src/features/scripting/headless_script_runner_test.dart`
- [x] 5.2 Implement the CLI entrypoint `bin/kafkalyzer_script.dart` supporting `--script`, `--cluster`, `--var`, `--params`, `--output`, semantic process exit codes, and structured JSON output, verifying with functional CLI tests
- [x] 5.3 Add "Copy CLI Command" button with confirmation feedback in `ScriptRunView` parameter workspace, verifying command string generation and clipboard integration via widget tests

## 6. B10: Secure Credential Storage in OS Keyring

- [x] 6.1 Implement `SecureStorageService` wrapping `flutter_secure_storage` with cluster-scoped key management and graceful headless fallback, verifying with unit tests in `test/src/services/secure_storage_service_test.dart`
- [x] 6.2 Update `ClusterService` to store sensitive credential fields in `SecureStorageService` and sanitize plaintext profiles in `SharedPreferences`, verifying with profile save/load round-trip tests
- [x] 6.3 Implement automatic one-time migration of existing plaintext cluster profiles to the OS keyring on app startup, verifying with migration unit tests in `test/src/services/cluster_service_test.dart`
- [x] 6.4 Update `SettingsService` profile export to sanitize sensitive credentials by default with an explicit opt-in confirmation dialog for including passwords, verifying with export tests
- [x] 6.5 Add subtle "Protected by OS Keyring" lock indicator and tooltip to credential fields in `ClusterConfigDialog`, verifying layout and tooltip display via widget tests

## 7. Integration Verification and Quality Assurance

- [x] 7.1 Run full suite of Dart unit and widget tests (`flutter test`) to verify all new features and ensure zero regressions across existing functionality
- [x] 7.2 Run `dart format` and verify static analysis passes cleanly via `flutter analyze`
- [x] 7.3 Verify read-only guarantees remain intact with no write/producer/commit invocations across the codebase

## Workflow follow-up

- Present planning artifacts for review.
- Start the apply workflow upon explicit user instruction.
