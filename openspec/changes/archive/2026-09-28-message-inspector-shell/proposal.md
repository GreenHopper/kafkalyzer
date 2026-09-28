## Why

Currently, inspecting a Kafka message forces the user into a modal dialog (`MessageDetailsDialog`) that covers 85% of the screen. In standard Kafka investigation workflows—such as tracing a message flow, verifying status transitions across multiple records, or comparing offsets—the user must constantly open the dialog, inspect, close it, click the next message, and open another dialog. This "Modal Break" halts productivity, disrupts mental focus, and makes sequential comparison clumsy.

Furthermore, message details currently default to `JsonCardViewer` (`_viewMode = 2`). Because `JsonCardViewer` renders unvirtualized nested card widgets inside a single scrollable container and uses a rigid 3-column masonry layout, realistic payloads with nested arrays (such as transport milestones or items) suffer from severe visual squeezing in the first column, leave over 70% of the screen as unused whitespace, and trigger noticeable UI frame drops when opening large messages.

Phase 1 of the Kafka Message UI Optimization concept resolves these issues by introducing an integrated, dockable Split-Screen Inspector shell in `MessagesView` that completely eliminates the modal interruption and immediately defaults to high-performance tree and raw inspection.

## What Changes

- **Dockable Split-Screen Inspector**: Replace the modal dialog invocation with an embedded `MessageInspectorPanel` inside `MessagesView`. Selecting a message in the master stream (table or timeline) opens the inspector alongside or below the stream without blocking navigation.
- **Laptop-First Ergonomic Docking**:
  - Support **Bottom-Docking** (horizontal split) as the default layout, allowing the message table above to retain 100% horizontal width so no columns are truncated on 13–15" laptop screens.
  - Support **Side-Docking** (vertical split) for wider multi-monitor workstations.
  - Provide a toggle button in the inspector header to switch docking positions seamlessly, and a close button (`Esc`) to restore full stream view.
- **Preserve Complete Kafka Message Context**:
  - **Metadata Header**: Partition, Offset, formatted Timestamp (with millisecond precision and copy affordance), and Message Key summary.
  - **Tabs**:
    - `Payload`: Content viewer with search, line jumping, and copy functionality.
    - `Key & Headers`: Dedicated key inspection alongside a structured list of Kafka headers with a count badge and quick-copy buttons.
    - `Raw JSON`: Pre-formatted full-message JSON representation for quick clipboard export.
- **Active Selection Highlight**: Visually highlight the currently selected row in `MessagesTableView` and timeline cards so the user always maintains visual orientation in the stream.
- **Default View Mode Performance Optimization**: Switch `JsonOrStringViewer`'s default view mode away from the unvirtualized Cards mode (`_viewMode = 2`) to Tree mode (`_viewMode = 1`), eliminating UI freezes while preparing for the full removal of `JsonCardViewer`.

## Capabilities

### New Capabilities
- `message-inspector-shell`: Embedded dockable split-screen message inspector within `MessagesView` supporting bottom and side docking, metadata headers, multi-tab inspection (Payload, Key & Headers, Raw JSON), and active row selection.

### Modified Capabilities
- `message-headers-inspection`: Message headers and key information are now rendered directly within the persistent dockable inspector in addition to fallback dialog contexts.

## Impact

- **Affected Code**:
  - `lib/src/ui/messages/messages_view.dart`: Host the inspector panel layout, selection state, and dock orientation state.
  - `lib/src/ui/messages/widgets/message_inspector_panel.dart` [NEW]: Reusable inspector component containing header controls, docking toggles, and inspection tabs.
  - `lib/src/ui/messages/views/messages_table_view.dart`: Receive selected message index from `MessagesView`, highlight the active row, and forward row selections without forcing a dialog.
  - `lib/src/ui/messages/views/messages_timeline_view.dart`: Receive selection callback and render active state on selected message card.
  - `lib/src/ui/json_or_string_viewer.dart`: Update default view mode from Cards (`2`) to Tree (`1`).
  - `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: Localized labels for docking actions, inspector tabs, and tooltips.
  - `lib/src/features/topic/topic_detail_view.dart` & `lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart`: Transition from manual `showDialog` to the integrated inspector in `MessagesView`.
- **Dependencies**: No external dependencies added; utilizes `package:material_ui/material_ui.dart` and Flutter's built-in flex layout widgets.
- **APIs**: No Rust/bridge or Kafka consumer API modifications; entirely a presentation and interaction architecture enhancement.
