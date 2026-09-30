## Context

Kafkalyzer uses Velopack for desktop packaging and updates across Linux, macOS, and Windows. In CI, artifacts (such as `releases.linux.json`, `Kafkalyzer-*-linux-full.nupkg`, and `Kafkalyzer.AppImage`) are uploaded to GitHub Releases under `https://github.com/GreenHopper/kafkalyzer/releases`.

However, the in-app updater currently:
1. Always fails the check because `velopack_flutter` hardcodes `HttpSource`, looking for static web server paths instead of using the GitHub Releases API.
2. Swallows all check errors in `UpdateService` and returns `false`, causing the UI to falsely report "up to date".
3. Lacks any startup/background checking mechanism to notify users of new versions automatically.
4. Doesn't distinguish between unpackaged/developer execution (e.g. local Linux GTK run without AppImage) and live packaged installations.

## Goals / Non-Goals

**Goals:**
- Enable functional update checks against GitHub Releases by utilizing Velopack's `AutoSource`.
- Deliver robust error reporting in `UpdateService` and `UpdateDialog` so check failures are surfaced with clear diagnostic messages.
- Implement a non-blocking background update check on application startup that alerts users via a non-intrusive prompt (e.g. `SnackBar` or banner) with a direct action to open the update dialog.
- Detect unpackaged / development environments (e.g. Linux without `$APPIMAGE`) and provide a fallback link to manually view/download releases from GitHub in the system browser.
- Ensure all user-facing strings are localized in English and German via `package:material_ui/material_ui.dart`.

**Non-Goals:**
- Changing release packaging pipelines in `.github/workflows/build.yml`.
- Supporting in-place auto-updates during unpacked `flutter run` sessions (native binary swapping requires a packaged installation).
- Interrupting startup with blocking modal dialogs.

## Decisions

### 1. Update Source: Upgrade `velopack_flutter` to `AutoSource`
- **Context:** Velopack provides `sources::AutoSource::new(&config.url)`. If the provided URL matches `github.com`, `AutoSource` delegates to `GithubSource`, which properly queries `api.github.com/repos/<owner>/<repo>/releases` and locates the release assets (`releases.<channel>.json`).
- **Implementation:** In the `velopack_flutter` dependency (forked at `https://github.com/skillsgo/velopack_flutter.git`), update `rust/src/api/velopack.rs`:
  ```rust
  fn get_update_manager(...) -> Result<UpdateManager, Error> {
      ...
      let source = sources::AutoSource::new(&config.url);
      UpdateManager::new_boxed(Box::new(source), Some(options), None)
  }
  ```
- **Rationale:** `AutoSource` handles GitHub API pagination, headers, and asset resolution natively without changing the Dart-facing API.

### 2. Typed Update Check Results & Error Propagation
- **Context:** Returning a bare `bool` from `isUpdateAvailable()` forced the service to choose between throwing or swallowing errors. Swallowing caused false "up-to-date" screens.
- **Implementation:**
  Introduce an explicit result model in `lib/src/services/update_service.dart`:
  ```dart
  enum UpdateCheckStatus {
    upToDate,
    updateAvailable,
    unsupportedEnvironment,
    failed,
  }

  class UpdateCheckResult {
    final UpdateCheckStatus status;
    final UpdateInfo? updateInfo;
    final String? errorMessage;
    final bool canAutoApply;

    const UpdateCheckResult({
      required this.status,
      this.updateInfo,
      this.errorMessage,
      this.canAutoApply = true,
    });
  }
  ```
  `UpdateService.checkForUpdates()` returns `UpdateCheckResult`, retaining backward compatibility for `isUpdateAvailable()` while giving `UpdateDialog` and background workers complete context.

### 3. Non-Blocking Startup Background Check
- **Context:** Users expect auto-updating apps to notify them when an update is ready rather than requiring manual trips to Settings.
- **Implementation:**
  - In `UpdateService`, add `Future<void> runBackgroundCheck()` and a `ValueNotifier<UpdateInfo?> availableUpdateNotifier`.
  - In `main.dart` or during initial application mount, schedule `runBackgroundCheck()` with a short delay (e.g. 3-5 seconds after startup) to avoid competing with database/cluster initialization.
  - In the root navigation layout (`MainLayout`), listen to `availableUpdateNotifier`. When an update is detected:
    - Display a `SnackBar` with `SnackBarBehavior.floating`:
      - Label: *"A new version of Kafkalyzer (vX.Y.Z) is available."*
      - Action: *"Update"* -> triggers `UpdateDialog.show(context)`.
  - Background check errors are quietly logged to avoid bothering users if they are offline or on restricted networks.

### 4. Environment Awareness & Developer Experience
- **Context:** On Linux, Velopack requires the app to execute from an AppImage (`$APPIMAGE` environment variable and `/usr/bin/UpdateNix`). In local development or unpackaged builds, Velopack throws `NotInstalled`.
- **Implementation:**
  - Add `UpdateService.isEnvironmentSupported`:
    - Checks whether `_isInitialized` succeeded and, on Linux, whether `$APPIMAGE` is present in `Platform.environment`.
  - In `UpdateDialog`, if `status == UpdateCheckStatus.unsupportedEnvironment`:
    - Display an informational card explaining that automatic in-place updates require a packaged installation (AppImage / installer).
    - Provide an action button *"Open GitHub Releases"* using `url_launcher` to navigate to `https://github.com/GreenHopper/kafkalyzer/releases`.

## UI / State Machine in UpdateDialog

```
             [Open Dialog / Check Started]
                           │
                           ▼
                     [checking]
                           │
       ┌───────────────────┼───────────────────┬───────────────────┐
       ▼                   ▼                   ▼                   ▼
  [upToDate]          [available]       [unsupported]           [failed]
  "Latest version"    Release Notes     "Packaged build req"    Error details
  [Close]             [Download]        [Open GitHub]           [Close / Retry]
                           │
                           ▼
                     [downloading] (0% - 100%)
                           │
                           ▼
                   [readyToRestart]
                   [Restart Now]
```

## Risks & Mitigations

- **Risk:** GitHub API rate limiting (60 requests/hr unauthenticated per IP).
  - **Mitigation:** The startup check runs only once per app session. `UpdateService` can optionally cache the last check timestamp in `shared_preferences` and throttle background checks (e.g. minimum 4 hours between automatic checks).
- **Risk:** Network disconnection during startup check.
  - **Mitigation:** Background checks silently handle `SocketException` / network timeouts without disturbing the user or UI.
