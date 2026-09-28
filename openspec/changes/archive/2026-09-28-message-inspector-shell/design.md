## Context

Shared Kafka message results are rendered via [`MessagesView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/messages_view.dart) in both [`TopicDetailView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/topic/topic_detail_view.dart) and [`ScriptRunDetailsView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart). Currently, tapping a message triggers an `onMessageTap` callback that invokes `showDialog` to present [`MessageDetailsDialog`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/message_details_dialog.dart). This modal dialog blocks the underlying table/timeline and forces repeated opening and closing when reviewing multiple messages.

Additionally, [`JsonOrStringViewer`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/json_or_string_viewer.dart) defaults to `_viewMode = 2` (Cards). Because [`JsonCardViewer`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/json_card_viewer.dart) uses non-virtualized widget construction and 3-column masonry with card-in-card wrapping, complex hierarchical messages freeze the UI and compress content into a single narrow column on the left.

Phase 1 introduces an integrated, responsive split-screen inspector in `MessagesView` with bottom-docking (horizontal split) and side-docking (vertical split), complete metadata and header preservation, and an immediate default viewer mode fix.

## Goals / Non-Goals

**Goals:**
- Replace the blocking `MessageDetailsDialog` with an embedded, non-modal `MessageInspectorPanel` inside `MessagesView`.
- Support responsive **Bottom-Docking** (horizontal split, default for laptop ergonomics) and **Side-Docking** (vertical split for ultra-wide monitors), switchable via a header toggle.
- Preserve full Kafka message context: Partition, Offset, Timestamp (with ms precision), Key summary, dedicated Headers tab with count badge, Payload viewer, and Raw JSON export.
- Highlight the selected message row in `MessagesTableView` and timeline cards.
- Change the default view mode in `JsonOrStringViewer` from Cards (`2`) to Tree (`1`).
- Persist inspector dock position preference in `SharedPreferences`.

**Non-Goals:**
- Removing `MessageDetailsDialog` entirely in Phase 1 (keep it as a fallback/standalone dialog if needed).
- Full removal of `JsonCardViewer` code (will be deprecated in Phase 1 and fully removed in Phase 3).
- Implementing Smart Badges or Context Windowing (scheduled for Phase 3 and Phase 4).
- Keyboard shortcuts (`J`/`K`) and stepper controls (scheduled for Phase 2).

## Decisions

### 1. Host the Inspector Shell in `MessagesView`
**Choice:** Implement the inspector layout within [`MessagesView`](file:///home/kaufmannr/git/greenhopper/kafkalyzer/lib/src/ui/messages/messages_view.dart). `MessagesView` manages `KafkaMessage? _selectedMessage`, `bool _isInspectorOpen`, and `InspectorDockPosition _dockPosition`.

**Rationale:** `MessagesView` is already the unified container hosting `MessagesTableView`, `MessagesTimelineView`, and `MessagesDiffView`. Implementing the split-screen shell here automatically upgrades both topic message streaming and script run inspection without altering `MainLayout` or `ExplorerView`.

**Alternatives considered:**
- Global `WorkspaceScaffold` replacing `MainLayout`: Violates Kafkalyzer's multi-feature design (Explorer, Consumer Lag, Scripts, Settings) and breaks modularity.
- Local modal bottom sheet (`showModalBottomSheet`): Still acts as a modal barrier that blocks clicking the next message in the table.

### 2. Ergonomic Bottom-Docking as Default
**Choice:** Default to horizontal split (master stream on top, inspector on bottom with 320–360 px height). Provide a toggle in the inspector header to switch to side-docking (master stream left, inspector right, 50% flex).

**Rationale:** As proven in the UI optimization concept (Chapter 9), on standard 13–15" developer laptops (1080p with 125–150% scaling, leaving ~1200–1400 logical pixels), a 50/50 side split truncates table columns down to ~500 px. Bottom-docking allows the table to keep 100% horizontal width while giving the inspector 100% horizontal width for deep JSON paths.

### 3. Inspector Layout & Header Structure
**Choice:** Create a dedicated `MessageInspectorPanel` widget:
- **Header Bar:**
  - Left: Message Key summary and compact metadata chips (Partition, Offset, Timestamp with copy button).
  - Right: Dock toggle button (`Icons.dock` / `Icons.view_sidebar`), Close button (`Icons.close`).
- **Tab Bar & Body:**
  - Tab 1: `Payload`: Hosts `JsonOrStringViewer` with search, line jumping, and copy controls.
  - Tab 2: `Key & Headers`: Displays the full key viewer (top) and list of Kafka headers with count badge (bottom).
  - Tab 3: `Raw JSON`: Displays pre-formatted JSON of the full message structure with copy button.

**Rationale:** Replicates all capabilities from `MessageDetailsDialog` without modal interruption, adhering strictly to `package:material_ui/material_ui.dart`.

### 4. Row Selection State & Backward Compatibility
**Choice:**
- `MessagesTableView` receives `KafkaMessage? selectedMessage` and `ValueChanged<KafkaMessage> onMessageSelect`.
- In `MessagesTableView`, row clicks call `onMessageSelect`. If the selected row is already active and the inspector is open, tapping can either keep it active or close it.
- In `MessagesView`, if `onMessageTap` is explicitly provided by external callers who wish to maintain custom modal handling, it can be respected; otherwise, `MessagesView` defaults to opening the embedded inspector.
- Active row in `MessagesTableView` renders with `colorScheme.primaryContainer.withValues(alpha: 0.25)` or `selectedRowColor`.

### 5. Default Viewer Mode Fix
**Choice:** Change `_viewMode = widget.initialViewMode ?? 1; // Default to Tree` in `JsonOrStringViewerState._parseContentAsync()`.

**Rationale:** Solves the immediate performance lag caused by `JsonCardViewer` on complex nested messages without breaking any existing functionality.

## Architecture & Component Hierarchy

```
┌────────────────────────────────────────────────────────────────────────┐
│ MessagesView (StatefulWidget)                                          │
│  - Results Toolbar (Sort Order, View Mode Switcher, Search, Export)    │
│  - Master Content Area:                                                │
│                                                                        │
│    [When Inspector is CLOSED]                                          │
│    └── Expanded(child: MessagesTableView / MessagesTimelineView)       │
│                                                                        │
│    [When Inspector is OPEN - Bottom Dock (Default)]                    │
│    └── Column                                                          │
│        ├── Expanded(flex: 5, child: MessagesTableView / Timeline)      │
│        ├── Divider(height: 1)                                          │
│        └── SizedBox(height: 350, child: MessageInspectorPanel)         │
│                                                                        │
│    [When Inspector is OPEN - Side Dock]                                │
│    └── Row                                                             │
│        ├── Expanded(flex: 5, child: MessagesTableView / Timeline)      │
│        ├── VerticalDivider(width: 1)                                   │
│        └── Expanded(flex: 5, child: MessageInspectorPanel)             │
└────────────────────────────────────────────────────────────────────────┘
```
