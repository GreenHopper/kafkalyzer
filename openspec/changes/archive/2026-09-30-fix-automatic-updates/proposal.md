## Why

Kafkalyzer's desktop application currently fails to detect and apply updates automatically, despite releases being packaged and published to GitHub Releases (e.g. `v1.4.6`). Investigation revealed four interconnected root causes:

1. **Incorrect Update Source in `velopack_flutter`:** The native bridge in `velopack_flutter` hardcodes `sources::HttpSource::new(&config.url)`. On GitHub repository URLs (`https://github.com/GreenHopper/kafkalyzer`), `HttpSource` requests `https://github.com/GreenHopper/kafkalyzer/releases.{channel}.json` directly, which returns HTTP 404 because GitHub hosts release assets on release-specific download paths. Velopack provides `AutoSource` (and `GithubSource`), which correctly queries the GitHub Releases API (`api.github.com/repos/.../releases`).
2. **Silent Failure Masked as "Up to Date":** In `UpdateService.isUpdateAvailable()`, any thrown exception (such as the 404 from GitHub or an unpackaged environment error) is caught in a `catch` block that logs a warning and returns `false`. Consequently, `UpdateDialog` interprets `false` as "no update available" and displays the misleading message *"Kafkalyzer ist auf dem neuesten Stand"* ("You are using the latest version") instead of reporting the check failure.
3. **No Automatic Startup Check:** `lib/main.dart` only executes `await getIt<UpdateService>().initialize()` during startup. This only configures the URL in memory and never performs an actual update check. The check is only executed when a user manually navigates to Settings and clicks *"Nach Updates suchen"*.
4. **Environment & Packaging Detection:** On Linux, Velopack relies on running within an AppImage bundle (checking `$APPIMAGE` and `/usr/bin/UpdateNix`). When running locally during development or unpackaged, Velopack throws `NotInstalled`, which must be recognized and handled with informative feedback rather than confusing error messages or false "up-to-date" indicators.

## What Changes

- **Update Source Resolution:** Update `velopack_flutter` (via our dependency fork or bridge configuration) to use `sources::AutoSource` instead of `sources::HttpSource`, allowing Velopack to recognize GitHub URLs and query the GitHub Releases feed properly.
- **Accurate Error Propagation:** Refactor `UpdateService.isUpdateAvailable()` and `getLatestUpdateInfo()` so errors (network failure, rate limits, packaging missing) are propagated cleanly via typed results or exceptions rather than being swallowed and returning `false`.
- **Informative UI Error Handling:** Update `UpdateDialog` to show accurate error information when an update check fails, including specific guidance when running in an unpackaged/development environment with a direct link to GitHub Releases.
- **Automated Background Startup Check:** Introduce a non-blocking background check shortly after application startup. If an update is detected, show a non-intrusive notification banner/snackbar with a direct action to open the update dialog, without blocking app launch or interrupting the user.
- **Settings & Config:** Maintain the manual update check in Settings, and ensure the configured repository URL is correctly centralized (`https://github.com/GreenHopper/kafkalyzer`).
- **Localization:** Provide localized strings in English and German for background update notifications, dev/unpackaged environment warnings, and specific error states.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
- `auto-update`: Resolves GitHub Releases feed discovery through `AutoSource`, adds non-blocking background update checking on application startup, surfaces genuine check errors instead of masking them as "up-to-date", and provides environment-aware feedback for unpackaged builds.

### Deleted Capabilities
None.

## Impact

- **Dependencies**: `velopack_flutter` dependency updated to point to a fork/revision supporting `AutoSource`.
- **Services**: `UpdateService` API refined to clearly differentiate between "no update found", "update found", and "check failed".
- **Application Startup**: `main.dart` / `KafkalyzerApp` schedules a non-blocking background check following startup.
- **UI / Presentation**:
  - `UpdateDialog` presents actionable error details when checks fail.
  - In-app notification mechanism (banner or SnackBar) to notify users of available updates discovered in the background.
- **Localization**: Added strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
