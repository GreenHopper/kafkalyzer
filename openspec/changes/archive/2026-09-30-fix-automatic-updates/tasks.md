## 1. Velopack Bridge & Source Configuration

- [x] 1.1 In `velopack_flutter` fork, update `rust/src/api/velopack.rs` to use `sources::AutoSource::new(&config.url)` (boxed into `UpdateManager::new_boxed`) instead of hardcoded `HttpSource`.
- [x] 1.2 Update `pubspec.yaml` dependency override for `velopack_flutter` to reference the patched branch/commit.
- [x] 1.3 Run `flutter pub get` and verify that the package compiles cleanly.

## 2. Core Service Refactoring (`UpdateService`)

- [x] 2.1 Define `UpdateCheckStatus` and `UpdateCheckResult` in `lib/src/services/update_service.dart` with status values for `upToDate`, `updateAvailable`, `unsupportedEnvironment`, and `failed`.
- [x] 2.2 Add `isEnvironmentSupported` getter to `UpdateService` checking initialization status and Linux `$APPIMAGE` requirement.
- [x] 2.3 Implement `Future<UpdateCheckResult> checkForUpdates()` that surfaces distinct errors instead of swallowing exceptions into `false`.
- [x] 2.4 Implement `ValueNotifier<UpdateInfo?> availableUpdateNotifier` and `Future<void> runBackgroundCheck()` with session throttling and silent error capture.
- [x] 2.5 Update and expand unit tests in `test/src/services/update_service_test.dart` to cover error bubbling, unsupported environment detection, and background check notification.

## 3. Application Startup & Non-Blocking Notification

- [x] 3.1 In `lib/main.dart` or during initial application bootstrap, trigger `runBackgroundCheck()` with a 3-second non-blocking delay after launch.
- [x] 3.2 In `lib/src/ui/main_layout.dart`, listen to `UpdateService.availableUpdateNotifier` and display a floating `SnackBar` notifying the user when an update is available with an "Update" action opening `UpdateDialog`.

## 4. UI Refinement (`UpdateDialog`)

- [x] 4.1 Update `_UpdateDialogStatus` and UI content in `lib/src/features/settings/presentation/widgets/update_dialog.dart` to handle `unsupportedEnvironment` with an explanation that auto-updates require a packaged installation.
- [x] 4.2 Add an action button in `UpdateDialog` to open `https://github.com/GreenHopper/kafkalyzer/releases` in the browser via `url_launcher` when in an unsupported environment or when check fails.
- [x] 4.3 Add a "Retry" button in `UpdateDialog` for the error state.

## 5. Localization

- [x] 5.1 Add new localization keys to `lib/l10n/app_en.arb` (background update alert, unsupported environment notice, open in browser, retry).
- [x] 5.2 Add corresponding German translations to `lib/l10n/app_de.arb`.
- [x] 5.3 Run `flutter gen-l10n` to update generated localizations.

## 6. Verification & Regression Testing

- [x] 6.1 Run `flutter test` to ensure all existing and new tests pass without regressions.
- [x] 6.2 Verify unpackaged development runs (`flutter run`) start up smoothly without false error popups or crashes.
- [x] 6.3 Verify the manual "Check for Updates" flow in Settings displays actionable feedback.
