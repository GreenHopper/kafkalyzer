## Context

See `proposal.md` for the motivation and UX screenshots. Kafkalyzer runs primarily as a desktop application on Linux, macOS, and Windows. On laptop screens (typically 1366x768 to 1920x1080 with 125%–150% display scaling), effective viewport width is frequently between 1100px and 1400px.

Currently, several views feature fixed-width sidebars that cannot be hidden or collapsed:
1. `ExplorerView`: Fixed 360px sidebar for cluster profiles and topic trees.
2. `ScriptManagerView`: Fixed 300px sidebar for the script catalog.
3. `ScriptRunDetailsView`: Fixed 300px sidebar for run statistics, step/topic filters, and parameter search filters.
4. `MessageInspectorPanel`: Docked either on the bottom or on the right (300px–600px width).

When a user opens script results or topic messages and docks the inspector to the right, up to five columns compete for horizontal space: Navigation rail (72px) + Script catalog (300px) + Run sidebar (300px) + Content timeline (remaining space) + Message inspector (350px+). This compresses the message timeline down to ~200px–300px, causing extensive horizontal scrolling, wrapped JSON keys, and cluttered visual presentation.

## Goals / Non-Goals

**Goals:**
- Provide 1-click and keyboard (`Ctrl+B` / `Cmd+B`) collapse and expand controls for the Topic Explorer sidebar (`ExplorerView`).
- Provide 1-click and keyboard (`Ctrl+B` / `Cmd+B`) collapse and expand controls for the Script catalog sidebar (`ScriptManagerView`).
- Provide an overview/filter toggle button in `ScriptRunHeader` to collapse and expand `ScriptRunSidebar` in `ScriptRunDetailsView`.
- Maintain a clear, accessible UI affordance (e.g., header toggle button or slim collapsed rail) so users can effortlessly re-expand collapsed panels with the mouse without knowing keyboard shortcuts.
- Persist the collapsed/expanded states in `SharedPreferences` so the user's preferred layout is remembered across navigation and application restarts.
- Animate sidebar transitions cleanly (e.g. 200ms duration) to avoid abrupt visual pops.
- Full internationalization (English and German) for tooltips, accessibility semantics, and labels.

**Non-Goals:**
- Changing the existing navigation rail (72px global app bar on the left).
- Replacing fixed sidebar layouts with fully arbitrary multi-window floating window systems.
- Modifying the internal logic of `TopicController` or `ScriptRunner`.

## Decisions

### 1. Toggle Button UI Placement & Collapsed Affordances
- **Explorer Sidebar (`ExplorerView`)**:
  - *Expanded state*: Place a toggle button (`Icons.view_sidebar_outlined` or `Icons.menu_open`) in `_buildSidebarHeader` next to the "Clusters" title.
  - *Collapsed state*: Instead of disappearing with 0 affordance, display a compact vertical strip (40px width) or an expand icon button at the start of the topic tab bar / content header. To maintain consistency regardless of whether topic tabs are currently open or empty, a slim vertical strip or dedicated leading button in the content header will be provided with tooltip `Expand sidebar (Ctrl+B)`.
  - *Alternative considered*: Completely zeroing width without any collapsed strip. Rejected because users without knowledge of the `Ctrl+B` shortcut would be trapped without an obvious visual way to restore the topic list.
- **Script Catalog Sidebar (`ScriptManagerView`)**:
  - *Expanded state*: Place a collapse button in `_buildSidebarHeader` beside the "Skripte" title and add button.
  - *Collapsed state*: Render a slim 40px vertical strip containing an expand icon button (`Icons.view_sidebar_outlined`) with tooltip `Expand script catalog (Ctrl+B)`.
- **Script Run Overview Sidebar (`ScriptRunDetailsView`)**:
  - *Header placement*: Add an `IconButton` in `ScriptRunHeader` right after the back button and run timestamp with icon `Icons.view_sidebar_outlined` (or `Icons.tune_outlined`) and tooltip `Toggle run overview`.
  - *State*: When toggled off, `ScriptRunSidebar` collapses completely (`SizedBox.shrink()`), allowing `MessagesView` (timeline/table and docked inspector) to occupy 100% of the horizontal space under the header.
  - *Alternative considered*: Embedding the toggle inside `ScriptRunSidebar` itself. Rejected because once collapsed to 0px, the button inside the sidebar would disappear, requiring an external toggle in the header anyway.

### 2. Keyboard Shortcuts (`Ctrl+B` / `Cmd+B`)
- Use Flutter's standard `CallbackShortcuts` widget wrapped around `ExplorerView` and `ScriptManagerView`.
- Bind `SingleActivator(LogicalKeyboardKey.keyB, control: true)` and `SingleActivator(LogicalKeyboardKey.keyB, meta: true)` to toggle the primary view sidebar.
- Match standard IDE and developer tool conventions (VS Code, Android Studio, Slack, etc.) where `Ctrl+B` / `Cmd+B` toggles the primary navigation/file sidebar.
- *Alternative considered*: `HardwareKeyboard.instance.addHandler`. Rejected because `CallbackShortcuts` integrates natively with the widget tree and respects route focus hierarchy without manual lifecycle registration.

### 3. State Management & Persistence
- Store collapsed booleans in the local widget state (`StatefulWidget`) and initialize them asynchronously from `SharedPreferences`:
  - `explorer_sidebar_collapsed` (boolean, default: false)
  - `script_manager_sidebar_collapsed` (boolean, default: false)
  - `script_run_sidebar_collapsed` (boolean, default: false)
- When a toggle action is invoked, update state immediately with `setState` and persist to `SharedPreferences` asynchronously in the background.
- *Alternative considered*: Centralizing in a global `LayoutController`. Rejected as over-engineering: each view's sidebar state is strictly local to that screen and `SharedPreferences` already provides fast in-memory cached read/write.

### 4. Layout & Animations
- Wrap sidebars with `AnimatedSize` or `AnimatedContainer` (curve: `Curves.easeInOutCubic`, duration: `200ms`) or conditional AnimatedCrossFade to ensure smooth width contraction and expansion without jitter.
- Clip overflowing content during animation using `ClipRect` to prevent render overflow errors while the width animates down to 40px or 0px.

## Risks / Trade-offs

- **[Risk] Keyboard shortcut conflicts with text inputs**: If the user presses `Ctrl+B` inside a text field (e.g. topic filter or script search), some platforms might intercept it for bold text formatting.
  - *Mitigation*: Flutter `CallbackShortcuts` at the parent level only invokes its callback if the focused descendant does not handle it. For search fields, `Ctrl+B` will toggle the sidebar smoothly without interfering with typical alphanumeric typing.
- **[Risk] Render overflow during sidebar width animation**: Text and buttons inside the sidebar could overflow their constraints during intermediate animation frames.
  - *Mitigation*: Wrap the animating sidebar in `ClipRect` and `OverflowBox` / `SizedBox(width: targetWidth)` so children do not throw `RenderFlex overflowed` errors during tweening.
- **[Risk] Multi-level nesting in Script Run Details**: When in `ScriptRunDetailsView`, there are two sidebars on screen (Script Catalog sidebar and Script Run sidebar).
  - *Mitigation*: `Ctrl+B` in Script Manager continues to toggle the script catalog. The script run overview toggle is explicitly highlighted in the `ScriptRunHeader` with an active/inactive visual state (e.g., selected button styling or icon tint).

## Migration Plan

No database migrations, wire-format changes, or breaking API changes are needed.
1. Add new localization keys in `app_en.arb` and `app_de.arb`.
2. Update `ExplorerView` with `_isSidebarCollapsed`, `CallbackShortcuts`, header toggle button, slim collapsed rail, and persistence.
3. Update `ScriptManagerView` with `_isSidebarCollapsed`, `CallbackShortcuts`, header toggle button, slim collapsed rail, and persistence.
4. Update `ScriptRunHeader` to accept `isSidebarVisible` and `onToggleSidebar`.
5. Update `ScriptRunDetailsView` to manage `_isRunSidebarCollapsed` and pass it to `ScriptRunHeader`.
6. Add unit and widget tests verifying toggling, persistence, and shortcut behavior.

## Open Questions

None. The layout requirements and technical design are clear and contained within existing presentation widgets.
