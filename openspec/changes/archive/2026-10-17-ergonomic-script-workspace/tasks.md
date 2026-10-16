# Tasks

## 1. Localization Strings

- [x] 1.1 Add localized strings to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb` for script deletion confirmation (title, message, cancel, delete), script catalog search hint, pipeline preview headers, and run script button with step count.
- [x] 1.2 Run `flutter gen-l10n` to regenerate `AppLocalizations`.

## 2. Script Catalog Search and Deletion Guard in `ScriptManagerView`

- [x] 2.1 Add search query state and an inline search `TextField` with search and clear icon buttons in `_buildSidebarHeader` of `lib/src/features/scripting/presentation/script_manager_view.dart`.
- [x] 2.2 Filter `controller.scripts` by the search query in real time before rendering the sidebar list.
- [x] 2.3 Implement `_confirmDeleteScript` with an `AlertDialog` requiring confirmation before calling `controller.deleteScript(script.id)`.

## 3. Responsive Two-Column Layout and Constrained Parameter Form in `ScriptRunView`

- [x] 3.1 Refactor `ScriptRunView._buildForm()` to use `LayoutBuilder`, rendering a two-column row on widths >= 900px and a vertically stacked column on narrower widths (< 900px).
- [x] 3.2 Constrain the parameter card to a maximum width of 560px and enhance variable inputs with clean type indicators (`Text`, `Timestamp`, `Numeric`) instead of raw type suffixes in labels.
- [x] 3.3 Relocate the primary "Run Script" button from the top-right toolbar to directly beneath the parameter inputs inside the parameter card with dynamic label `[ ► Run Script (<N> Steps) ]`.

## 4. Read-Only Pipeline Preview in `ScriptRunView`

- [x] 4.1 Implement `_buildPipelinePreview()` card in `ScriptRunView` displaying a read-only overview of the script's execution steps.
- [x] 4.2 Display step numbers, step names, target topic chips, monospaced filter template preview, and extracted variable tags linking downstream steps.
- [x] 4.3 Display an informative empty state when a script has no configured steps yet.

## 5. Widget Tests and Verification

- [x] 5.1 Update and extend `test/src/features/scripting/presentation/script_manager_view_test.dart` to verify real-time search filtering and script deletion confirmation dialog.
- [x] 5.2 Update and extend `test/src/features/scripting/presentation/widgets/script_run_view_test.dart` to verify two-column layout, parameter card constraints, run button placement, and pipeline preview rendering.
- [x] 5.3 Run `flutter test test/src/features/scripting/` and `flutter analyze` to ensure regression-free test coverage.
