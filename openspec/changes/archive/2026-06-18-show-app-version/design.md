## Context

Currently, Kafkalyzer displays an application version in the UI (e.g., the Settings view) via `AppVersionHelper.version`. However, this helper fetches the version from a compile-time string environment variable (`APP_VERSION`). If the build process doesn't explicitly inject this variable, it defaults to `'DEV'`. To ensure the UI accurately reflects the version defined in `pubspec.yaml` (which is incremented with every build), we need to read it dynamically at runtime from the native platform.

## Goals / Non-Goals

**Goals:**
- Read the application version from `pubspec.yaml` at runtime.
- Update the UI to seamlessly display this dynamically fetched version.
- Minimize asynchronous loading artifacts (like spinners) in the UI by pre-fetching the version during the app's startup sequence.

**Non-Goals:**
- Showing update prompts or fetching the latest available version from an external server.
- Modifying the underlying build scripts or deployment pipelines beyond adding the necessary Flutter dependency.

## Decisions

1. **Use `package_info_plus`:**
   - **Rationale:** It is the standard, well-maintained Flutter plugin for querying application metadata (including the version from `pubspec.yaml`) across all supported platforms (macOS, Windows, Linux, etc.).
   - **Alternatives Considered:** Parsing `pubspec.yaml` manually via asset loading. This is brittle, adds the whole file to the assets bundle unnecessarily, and is generally not recommended compared to native bindings.

2. **Pre-fetch Version at Startup:**
   - **Rationale:** The version string is needed synchronously in the UI (e.g., `AppVersionHelper.version`). By resolving `PackageInfo.fromPlatform()` in the `main()` function or DI setup before `runApp()` is called, we can populate a static variable in `AppVersionHelper` and avoid wrapping simple UI Text widgets in `FutureBuilder`s.
   - **Implementation:** Modify `AppVersionHelper` to have a static `init()` method that fetches the package info and stores the version in a static property.

## Risks / Trade-offs

- **Risk:** `package_info_plus` fails to initialize on certain Linux desktop distributions due to missing implementation or package issues.
  - **Mitigation:** Wrap the initialization in a try-catch block. If it fails, fallback gracefully to `'DEV'` or the compile-time `APP_VERSION` environment variable so the app still functions normally.
