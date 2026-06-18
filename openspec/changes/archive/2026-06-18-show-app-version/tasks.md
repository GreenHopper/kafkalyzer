## 1. Setup

- [x] 1.1 Add `package_info_plus` to `pubspec.yaml`
- [x] 1.2 Run `flutter pub get` to fetch dependencies

## 2. Core Implementation

- [x] 2.1 Update `AppVersionHelper` to have a static `init()` method that calls `PackageInfo.fromPlatform()`
- [x] 2.2 Update `AppVersionHelper.version` getter to return the version string from `PackageInfo` (e.g. `1.0.0+1`), with a fallback to `'DEV'` on failure.
- [x] 2.3 Call `AppVersionHelper.init()` in `main.dart` before `runApp()` is called

## 3. UI Updates & Verification

- [x] 3.1 Verify `settings_view.dart` displays the correctly fetched version format.
- [x] 3.2 Fix any unit tests that expect `AppVersionHelper.version` to be synchronously available without `init()`.
- [x] 3.3 Ensure the app builds and runs successfully.
- [x] 3.4 Run the full test suite (`flutter test`) and ensure all unit tests pass.
