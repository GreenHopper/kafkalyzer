## Context

Kafkalyzer currently allows users to select output directories in three separate areas:
1. General Settings (`general_default_output_dir` in SharedPreferences)
2. Multi Stream Search View (`multi_search_output_dir` in SharedPreferences)
3. Script Editor configuration (`outputDirectory` in the Script model)

This results in a fragmented user experience, redundant folder picker UI elements, and complex logic for resolving execution directories and managing run history cleanup.

## Goals / Non-Goals

**Goals:**
- Unify output directory handling by making General Settings' default output directory the single source of truth.
- Set a platform-specific default output directory at startup if not already configured (targeting Windows, Linux, and macOS).
- Dynamically derive script-specific output directories as subfolders of the settings default directory (sanitized with the script name).
- Remove redundant output directory inputs from both `MultiSearchView` and `ScriptEditor`.
- Update history cleanup to correctly scan and purge derived script subfolders.

**Non-Goals:**
- Removing the `outputDirectory` field from the `Script` model (we keep it as deprecated/nullable to avoid deserialization breakages for existing configurations).
- Altering the core search implementation or message file format.

## Decisions

### 1. Platform-Specific Defaults at Startup
At startup, `SettingsService` will check if `general_default_output_dir` exists. If not, it will determine:
- macOS/Linux/Windows: `[Documents]/Kafkalyzer/Output`
This path will be saved to SharedPreferences and created recursively.
*Rationale:* Ensures the user always has a valid out-of-the-box location for files, without forcing them to manually configure one.

### 2. Dynamic Script Directory Derivation
Remove the script-level text input in the editor. During execution, the runner will resolve the base directory as:
```dart
final defaultGlobal = prefs.getString('general_default_output_dir') ?? (await getApplicationDocumentsDirectory()).path;
final safeName = script.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
final baseDir = p.join(defaultGlobal, safeName);
```
*Rationale:* Completely removes the need for individual script configuration, making script management simpler and directory paths uniform.

### 3. Simplify Multi-Search UI
Remove the folder icon and picker in `MultiSearchView`. Instead, the `MultiSearchController` will automatically initialize its output directory to the global settings default output directory. When settings change, the controller will reload the value.
*Rationale:* Simplifies the UI and guides all search outputs to the global default directory.

## Risks / Trade-offs

- **Risk:** Existing scripts might have custom `outputDirectory` set in their JSON.
  - *Mitigation:* We will ignore this field during execution, but keep the field in the Dart class definition so old JSON configurations still load without errors. We will also perform directory migration/reparenting during configuration import.
