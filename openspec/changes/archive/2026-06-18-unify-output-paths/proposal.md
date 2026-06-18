## Why

Currently, Kafkalyzer has multiple overlapping options for configuring output directories (global setting, multi-search view, and individual scripts). This redundancy causes confusion and inconsistent file storage behavior. Simplifying this by deriving script directories from the global settings default output directory will make file management clean, consistent, and user-friendly.

## What Changes

- Automatically initialize the global default output directory (`general_default_output_dir` in SharedPreferences) on app startup if it is not set or invalid, using a platform-specific Documents subdirectory (`[Documents]/Kafkalyzer/Output`).
- Derive the output directory for each script execution dynamically: `[general_default_output_dir]/[script_name]`.
- Remove the redundant folder picker from the `MultiSearchView` and use the global default output directory instead.
- Remove the redundant "Output Directory" input field from the `ScriptEditor` view.
- Update history cleanup logic to clean the actual derived run directories under each script's folder.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- None

## Impact

- `lib/src/services/settings_service.dart`: Added startup initialization logic for platform-specific default output directory.
- `lib/src/features/scripting/presentation/controllers/script_runner.dart`: Updated to dynamically derive script run directories and update history cleanup.
- `lib/src/features/search/presentation/controllers/multi_search_controller.dart`: Updated to use the global settings directory and reload when settings change.
- `lib/src/features/search/multi_search_view.dart`: Removed the output directory picker button.
- `lib/src/features/scripting/presentation/widgets/script_editor.dart`: Removed the script-level output directory text field.
