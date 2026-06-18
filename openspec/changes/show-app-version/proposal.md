## Why

Currently, the application version is either hardcoded or requires passing build flags (`--dart-define=APP_VERSION=...`) to be displayed in the UI. We want to dynamically read the version number from the `pubspec.yaml` file (which is incremented with every build) so that the correct version is always shown in the UI without manual build configuration steps. This improves traceability and makes bug reports more accurate by guaranteeing the user sees the actual compiled version.

## What Changes

- Add the `package_info_plus` package to read version information from the native platform build (which is automatically synced with `pubspec.yaml`).
- Update `AppVersionHelper` or create a new service to fetch the version asynchronously at startup.
- Update the UI (e.g., Settings view) to display the dynamically fetched version instead of the static string from the environment.

## Capabilities

### New Capabilities
- `app-version-display`: Capability to dynamically read and display the current application version from `pubspec.yaml`.

### Modified Capabilities

## Impact

- **Dependencies**: Adds `package_info_plus` to `pubspec.yaml`.
- **Initialization**: Requires asynchronous initialization of the package info during app startup.
- **UI**: Settings screen and anywhere else `AppVersionHelper.version` is used will need to handle the version string asynchronously or read from a pre-initialized service.
