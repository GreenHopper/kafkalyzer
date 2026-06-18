## 1. Startup & Settings Initialization

-[x] 1.1 Implement `initializeSettings` in `SettingsService` to set a platform-appropriate Documents subdirectory on startup.
-[x] 1.2 Call `initializeSettings` in the app's `main` entry point.

## 2. Multi Search Directory Unification

-[x] 2.1 Update `MultiSearchController` to load the settings default directory instead of `multi_search_output_dir`.
-[x] 2.2 Remove the directory picker button from the `MultiSearchView` layout.
-[x] 2.3 Update `SettingsView` to reload the `MultiSearchController` directory when settings change.

## 3. Script Handling Simplification

-[x] 3.1 Remove the Output Directory configuration field from the `ScriptEditor` view.
-[x] 3.2 Update `ScriptRunner` to dynamically derive script execution output directories under the global default directory.
-[x] 3.3 Update `ScriptRunner` run cleanup history to scan and clean script subdirectories correctly.

## 4. Verification

-[x] 4.1 Run existing tests to ensure no regressions are introduced.
-[x] 4.2 Run `dart format` to format all modified Dart files.
