## Why

On smaller laptop screens (such as 1366x768, 1440x900, or tiled desktop windows), the UI in the Topic Explorer and Script Run views becomes heavily overcrowded with horizontal panels.

In the Scripting feature, viewing execution results currently stacks up to five horizontal columns side-by-side:
1. Main Navigation Rail (~72px)
2. Script List Sidebar (fixed 300px)
3. Script Run Overview & Steps Sidebar (fixed 300px)
4. Message Stream (Table or Timeline)
5. Message Inspector Panel (docked to side, ~400px)

This leaves as little as 250px–300px for the actual message stream in the center, causing severe line wrapping, truncated table columns, and horizontal crowding. Similarly, in the Topic Explorer, the 360px cluster and topic list sidebar remains permanently visible even after a topic is selected, cramping the message table and side-docked inspector.

Introducing collapsible sidebars with intuitive toggle buttons, keyboard shortcuts (`Ctrl+B`), and persistent state gives users immediate control to maximize their message investigation space on compact displays.

## What Changes

- **Collapsible Topic Explorer Sidebar**: Add an expand/collapse toggle for the 360px cluster & topic list in `ExplorerView`, with state persisted across sessions and a quick-expand affordance when collapsed.
- **Collapsible Script List Sidebar**: Add an expand/collapse toggle for the 300px script list in `ScriptManagerView`, enabling users to hide the script catalog while editing or investigating runs.
- **Collapsible Script Run Overview Sidebar**: Add a toggle button in `ScriptRunHeader` to collapse the 300px `ScriptRunSidebar` (containing run statistics, parameters, and step tree filters), expanding the message results to full width.
- **Keyboard Shortcut (`Ctrl+B` / `Cmd+B`)**: Provide a standard keyboard shortcut to quickly toggle the primary active sidebar in Explorer and Script Manager.
- **Responsive Adaptation for Narrow Displays**: Provide smooth animations and compact headers so sidebars fold away cleanly on compact viewports without breaking layout constraints.

## Capabilities

### New Capabilities
- `collapsible-sidebars`: Covers collapsible sidebar panels across `ExplorerView`, `ScriptManagerView`, and `ScriptRunDetailsView`, including toggle buttons, keyboard shortcuts, collapsed indicators, and preference persistence.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected Code**:
  - `lib/src/features/explorer/presentation/explorer_view.dart`: Add collapse state, toggle button, animated collapse/expand, and persistence for the topic sidebar.
  - `lib/src/features/scripting/presentation/script_manager_view.dart`: Add collapse state and toggle button for the script list sidebar.
  - `lib/src/features/scripting/presentation/widgets/script_history/script_run_header.dart`: Add sidebar toggle button to control the visibility of the run overview sidebar.
  - `lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart`: Support collapsing/expanding `ScriptRunSidebar`.
  - Localization (`lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`): Add tooltip and label keys for toggling sidebars.
- **Dependencies**: No external packages required. Built using Flutter `material_ui` animated widgets (`AnimatedCrossFade`, `AnimatedSize`, or `AnimatedContainer`).
- **APIs & Breaking Changes**: None. Backwards-compatible layout enhancements.
