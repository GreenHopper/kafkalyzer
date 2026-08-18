## Why

With the transition of Kafkalyzer to a cross-platform release pipeline powered by Velopack (`vpk`), users need an automated and effortless way to receive application updates directly from GitHub Releases without having to manually download and reinstall binaries. Integrating `velopack_flutter` provides seamless in-app checking, downloading with progress feedback, and atomic update-and-restart execution for desktop platforms (Linux, macOS, Windows).

## What Changes

- Add and configure the `velopack_flutter` package in `pubspec.yaml`.
- Create a dedicated `UpdateService` registered in GetIt dependency injection to manage Velopack lifecycle, update checking, downloads, and restarts.
- Initialize `UpdateService` with the GitHub repository URL (`https://github.com/Protoss78/kafkalyzer`) during application startup in `main.dart`.
- Ensure robust, graceful exception handling so local development / debug builds (which run unpacked) continue to function without errors.
- Add UI support for updates in `SettingsView`, including manual "Check for Updates" action and an `UpdateDialog` showing release version, release notes, download progress, and restart prompt.
- Add localizations for all update-related user-facing text in English and German (`app_en.arb`, `app_de.arb`).

## Capabilities

### New Capabilities
- `auto-update`: In-app checking, downloading, and applying updates via Velopack and GitHub Releases with UI status and progress reporting.

### Modified Capabilities

## Impact

- **Dependencies**: Adds `velopack_flutter` to `pubspec.yaml`.
- **Initialization**: Asynchronous initialization of Velopack bridge during application startup in `main.dart`.
- **UI & Localization**: New update controls in Settings and localized dialog for download/restart.
- **Development Experience**: Safe fallbacks in debug mode when Velopack native hooks/binaries are not active.
