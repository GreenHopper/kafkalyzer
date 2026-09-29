## 1. Localization

- [x] 1.1 Add localized strings for sidebar collapse, expand, and run overview toggles to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, and verify `flutter gen-l10n` generates the new accessors.

## 2. Topic Explorer Collapsible Sidebar

- [x] 2.1 Implement `_isSidebarCollapsed` state in `ExplorerView`, wire collapse button in `_buildSidebarHeader`, render a slim 40px collapsed expand rail, and persist state in `SharedPreferences` (`explorer_sidebar_collapsed`). Verify by checking widget rendering when collapsed.
- [x] 2.2 Wrap `ExplorerView` with `CallbackShortcuts` binding `Ctrl+B` and `Cmd+B` to toggle the sidebar. Verify via widget test key simulation.
- [x] 2.3 Add widget tests in `test/src/features/explorer/presentation/explorer_view_test.dart` verifying collapsing, expanding, keyboard shortcut toggling, and preference persistence.

## 3. Script Catalog Collapsible Sidebar

- [x] 3.1 Implement `_isSidebarCollapsed` state in `ScriptManagerView`, add collapse button in `_buildSidebarHeader`, render a slim 40px collapsed expand rail, and persist state in `SharedPreferences` (`script_manager_sidebar_collapsed`). Verify by checking widget rendering when collapsed.
- [x] 3.2 Wrap `ScriptManagerView` with `CallbackShortcuts` binding `Ctrl+B` and `Cmd+B` to toggle the script catalog. Verify via widget test key simulation.
- [x] 3.3 Add widget tests in `test/src/features/scripting/presentation/script_manager_view_test.dart` verifying script catalog collapsing, expanding, keyboard shortcut, and preference persistence.

## 4. Script Run Details Overview Collapsible Sidebar

- [x] 4.1 Update `ScriptRunHeader` to accept `isSidebarVisible` and `onToggleSidebar` callback, and add an icon toggle button with tooltip. Verify with widget tests in `test/src/features/scripting/presentation/widgets/script_run_header_test.dart`.
- [x] 4.2 Update `ScriptRunDetailsView` to maintain `_isRunSidebarCollapsed` with `SharedPreferences` persistence (`script_run_sidebar_collapsed`), pass toggle callback to `ScriptRunHeader`, and collapse `ScriptRunSidebar` to allow `MessagesView` to occupy full width. Verify visual expansion when sidebar is collapsed.
- [x] 4.3 Add widget tests in `test/src/features/scripting/presentation/widgets/script_run_details_view_test.dart` verifying overview sidebar toggle behavior and state persistence.

## 5. Verification & Quality

- [x] 5.1 Run full test suite via `flutter test` and verify all tests pass without errors.
- [x] 5.2 Run `dart analyze` and verify zero errors, warnings, or linter violations.
