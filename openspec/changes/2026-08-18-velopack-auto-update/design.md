## Context

Kafkalyzer uses GitHub Actions to build and package release artifacts using Velopack (`vpk pack`) for Linux, macOS, and Windows. To complete the release distribution cycle, the desktop client needs an integrated auto-update mechanism that communicates with GitHub Releases where the Velopack packages are hosted (`https://github.com/Protoss78/kafkalyzer`).

The `velopack_flutter` package wraps the native Velopack Rust library via `flutter_rust_bridge`, offering APIs to check for updates (`isUpdateAvailable`, `getLatestUpdateInfo`), stream download progress (`checkAndDownloadUpdatesWithProgress`), and restart the app applying the update (`updateAndRestart`).

## Goals / Non-Goals

**Goals:**
- Provide an `UpdateService` accessible via GetIt dependency injection.
- Initialize Velopack bridge early during app bootstrap in `main.dart`.
- Support automatic background update checks on application launch without blocking startup.
- Provide a user-facing "Check for Updates" trigger in `SettingsView`.
- Show an interactive `UpdateDialog` displaying the latest release version, release notes (markdown), interactive download progress, and a "Restart Now" button once download completes.
- Gracefully handle environments where Velopack is not active (debug mode, unpackaged runs, network errors).

**Non-Goals:**
- Custom binary hosting / S3 storage (GitHub Releases is the sole target source).
- Custom update server authentication (GitHub Releases are public).
- Modifying GitHub CI workflow packaging parameters (already configured in `.github/workflows/build.yml`).

## Decisions

1. **Encapsulate Velopack in `UpdateService`:**
   - **Rationale:** Keeps update logic, state, and platform error isolation contained in a single service instead of scattering Velopack API calls across UI widgets.
   - **Structure:**
     ```dart
     class UpdateService {
       Future<void> initialize();
       Future<bool> isUpdateAvailable();
       Future<UpdateInfo?> getLatestUpdateInfo();
       Stream<int> downloadWithProgress();
       Future<void> applyAndRestart();
     }
     ```

2. **Safe Fallback in Debug / Unpackaged Mode:**
   - **Rationale:** Velopack Rust bridge calls only succeed when running as a compiled Velopack package. Calling `isUpdateAvailable` in local `flutter run` throws an exception.
   - **Implementation:** Catch errors during `initialize()` and `isUpdateAvailable()`. In debug/non-packaged mode, log via `Logger` and return `false` / `null` without throwing to the UI, allowing normal app usage.

3. **UI Integration in Settings View:**
   - **Rationale:** Placing the update check alongside `Kafkalyzer v${AppVersionHelper.version}` in `SettingsView` gives users an intuitive and familiar location to check version info and trigger manual updates.
   - **Component:** `UpdateDialog` / `UpdateCard` with state management for checking -> available -> downloading -> restart ready.

## Risks / Trade-offs

- **Risk:** Velopack native bindings fail or throw when running on unsupported platforms or during dev builds.
  - **Mitigation:** Wrap all Velopack invocations in try-catch with structured logging and clear UI messages when user triggers a manual check.
- **Risk:** Network connection failure or GitHub API rate limits during update checks.
  - **Mitigation:** Surface meaningful error feedback in the update dialog/snackbars rather than failing silently.
