# Proposal

## Why

In the current scripting workspace, two major usability and safety issues impact daily workflows:
1. **Accidental Deletion Risk**: In `ScriptManagerView`, each script item in the sidebar features a prominent trash icon (`Icons.delete`) that executes `controller.deleteScript(script.id)` immediately on click with zero confirmation dialog or undo safeguard.
2. **Disconnected and Unbounded Execution Form**: In `ScriptRunView`, parameter inputs stretch up to 1,400px across widescreen displays with raw type suffixes like `(string)` rather than contextual badges, while the primary "Run" button is disconnected in the top-right toolbar.
3. **Missing Pipeline Context**: Users selecting a multi-step script have no visibility into what topics the script consumes, how filters are structured, or what downstream variables are extracted without switching back and forth into the edit tab.
4. **Script Discoverability**: As users accumulate scripts, `ScriptManagerView` lacks an inline search/filter input, requiring manual scrolling through lists.

Redesigning the workspace creates a safer, self-documenting, and ergonomic script execution experience.

## What Changes

- **Confirmation Guard for Script Deletion**: Require explicit user confirmation via an `AlertDialog` before deleting any script from `ScriptManagerView`.
- **Script Catalog Filter**: Add an inline search field to the `ScriptManagerView` sidebar header to rapidly filter scripts by name.
- **Two-Column Ergonomic `ScriptRunView`**:
  - **Left Column (constrained <= 560px)**: "Parameters & Execution" card housing target cluster selection, typed variable input fields with clean type badges (`Text`, `Timestamp`, `Numeric`), and a prominent primary `[ ► Run Script (<N> Steps) ]` button situated directly below the input fields.
  - **Right Column**: "Pipeline Preview" card presenting a read-only visual timeline of the script's steps, including step name/order, target Kafka topic(s), filter template preview, and variable extractions linking steps.
- **Responsive Layout**: Automatically adapt the two-column layout to single-column stacking on narrow window widths (< 900px).
- **Comprehensive Localization**: Ensure all user-facing labels and tooltips in `ScriptManagerView` and `ScriptRunView` are fully localized in English and German.

## Capabilities

### New Capabilities
- `ergonomic-script-workspace`: Provides deletion confirmation guards, script catalog search, constrained parameter execution forms, and read-only pipeline step preview in the scripting workspace.

### Modified Capabilities
<!-- None -->

## Impact

- **UI & Presentation**:
  - `lib/src/features/scripting/presentation/script_manager_view.dart`
  - `lib/src/features/scripting/presentation/widgets/script_run_view.dart`
- **Localization**:
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_de.arb`
  - `lib/l10n/app_localizations*.dart`
- **Tests**:
  - `test/src/features/scripting/presentation/script_manager_view_test.dart`
  - `test/src/features/scripting/presentation/widgets/script_run_view_test.dart`
