## 1. Dependencies & Core Service

- [x] 1.1 Add `velopack_flutter: ^0.3.2` to `pubspec.yaml` and verify dependency resolution via `flutter pub get`
- [x] 1.2 Create `UpdateService` (`lib/src/services/update_service.dart`) with methods for `initialize()`, `isUpdateAvailable()`, `getLatestUpdateInfo()`, `downloadWithProgress()`, and `applyAndRestart()`
- [x] 1.3 Implement graceful error handling in `UpdateService` to protect against debug/unpackaged execution exceptions

## 2. Dependency Injection & App Startup

- [x] 2.1 Register `UpdateService` in `lib/src/dependency_injection.dart`
- [x] 2.2 Call `UpdateService.initialize()` in `lib/main.dart` during app startup
- [x] 2.3 Add non-blocking background update check on startup in `lib/main.dart`

## 3. UI Components & Settings Integration

- [x] 3.1 Create `UpdateDialog` (`lib/src/features/settings/presentation/widgets/update_dialog.dart`) supporting checking state, update details, progress bar, and restart button
- [x] 3.2 Update `lib/src/features/settings/presentation/settings_view.dart` to add a "Check for Updates" action next to the app version footer

## 4. Localization

- [x] 4.1 Add update-related localization strings to `lib/l10n/app_en.arb` (e.g. check for updates, downloading, restart now, up to date, error checking updates)
- [x] 4.2 Add corresponding German translations to `lib/l10n/app_de.arb`
- [x] 4.3 Run `flutter gen-l10n` to update generated localization classes

## 5. Verification & Testing

- [x] 5.1 Run `flutter test` to ensure existing and new tests pass without regressions
- [x] 5.2 Verify debug app startup to ensure no crash occurs in unpacked development environment
- [x] 5.3 Verify Settings UI layout and manual check trigger
