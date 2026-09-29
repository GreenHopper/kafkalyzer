## Context

See `proposal.md` for motivation. Currently, `TopicDetailView` delegates Kafka message stream rendering and inspection to `MessagesView`, which embeds a responsive split-view `MessageInspectorPanel` dockable to the side or bottom with sequential message stepping, auto-scroll, Focus Mode, and search integration.

In contrast, `ScriptRunDetailsView` directly instantiates `MessagesTableView`, `MessagesTimelineView`, and `MessagesDiffView` within `_filteredResultsView()`, and binds `onMessageTap` to `showDialog(MessageDetailsDialog)`. Additionally, `ScriptRunHeader` duplicates the `ViewModeSwitcher` and `MessageSearchBar` widgets, while missing sorting controls, column customization menus, and message export tools present in `MessagesView`.

Finally, the codebase retains the legacy 578-line `MessageDetailsDialog` (`lib/src/ui/message_details_dialog.dart`), which is also referenced in `MessagesTableView` as a fallback and in `TopicPartitionTable` when inspecting lagging partition messages.

## Goals / Non-Goals

**Goals:**
- Replace the modal `MessageDetailsDialog` in `ScriptRunDetailsView` with the embedded `MessageInspectorPanel` via `MessagesView`.
- Provide identical UI/UX across Topic Explorer and Script Run Details: side-docking, bottom-docking, maximized Focus Mode, sequential stepping (`J`/`K`/arrows), auto-scroll to active rows/cards, and in-inspector search.
- Streamline `ScriptRunHeader` to eliminate duplicated search and view-mode controls, leaving `MessagesView` as the single source of truth for message presentation.
- Extend `MessagesView` cleanly with `schemaViewBuilder` so `ScriptSchemasView` can be seamlessly embedded into `MessagesView`'s view modes.
- Support script-specific filtering (matching `stepName` on `ScriptResultMessage`) and preserve script timeline ordering (`byTopic`, `chronological`, `groupedByStep`).
- Migrate `TopicPartitionTable` to inspect single lagging messages using `MessageInspectorPanel` (hosted in a dialog or drawer).
- Completely remove `MessageDetailsDialog` (`lib/src/ui/message_details_dialog.dart`) and its test suite from the codebase since it is no longer needed.

**Non-Goals:**
- Changing the script execution engine (`ScriptRunner`) or script persistence formats.

## Decisions

### Decision 1: Render `MessagesView` directly inside `ScriptRunDetailsView`

**Rationale:** `MessagesView` encapsulates all message inspection shell features: split layouts, side/bottom docking, keyboard shortcut handling (`J`, `K`, `F`, `Esc`), selection synchronizing, and auto-scrolling across table, timeline, and diff views. Reusing `MessagesView` in `ScriptRunDetailsView` immediately eliminates modal dialogs and gives users the exact same interface in both features.

**Alternatives considered:**
- *Embedding `MessageInspectorPanel` manually in `ScriptRunDetailsView`:* Would duplicate all split-view state, keyboard handling, stepper state, and auto-scroll logic already thoroughly tested in `MessagesView`.
- *Retaining `MessageDetailsDialog`:* Violates UI consistency and leaves users with a disruptive modal dialog.

### Decision 2: Streamline `ScriptRunHeader` and let `MessagesView` own message toolbar controls

**Rationale:** `MessagesView` already has an integrated top toolbar featuring:
- Sort field selector and ascending/descending toggle
- `ViewModeSwitcher`
- `MessageSearchBar` (with match count and show-non-matches toggle)
- Table column customization (`MenuAnchor` with column visibility and pinning)
- Reset columns button
- Message export button

In `ScriptRunDetailsView`, `ScriptRunHeader` currently renders its own `ViewModeSwitcher` and `MessageSearchBar`. By removing those duplicates from `ScriptRunHeader`, `ScriptRunHeader` remains clean and compact, containing only run context:
1. Back button (`<-`)
2. Run title and execution timestamp
3. Timeline mode `SegmentedButton` (`byTopic`, `chronological`, `groupedByStep`)

**Alternatives considered:**
- *Passing `showHeader: false` to `MessagesView`:* Would hide the duplicate search bar, but also strip script users of sort controls, table column customization, and export capabilities.

### Decision 3: Add `schemaViewBuilder` and script-aware filtering to `MessagesView`

**Rationale:**
In Topic Explorer, the `schema` tab renders `TopicSchemaView(topic: ...)`. In Script Run Details, `ScriptSchemasView` visualizes multi-topic schemas across steps. By adding an optional parameter to `MessagesView`:
```dart
final Widget Function(BuildContext context, String searchPhrase)? schemaViewBuilder;
```
`MessagesView` displays the `schema` tab whenever `schemaViewBuilder != null` (or single topic), and delegates rendering to `schemaViewBuilder!(context, _searchPhrase)`.

Furthermore, in `MessagesView._filterMessages`, when searching:
```dart
if (msg is ScriptResultMessage && msg.stepName.toLowerCase().contains(query)) {
  isMatch = true;
}
```
This ensures searching for step names in script runs highlights and filters messages correctly.

### Decision 4: Preserving Script Timeline Ordering

**Rationale:**
In script runs, users toggle between `byTopic`, `chronological`, and `groupedByStep`.
`MessagesView` can accept an optional `int Function(KafkaMessage a, KafkaMessage b)? sortComparator`. When provided, `MessagesView` applies it to order messages, ensuring the timeline and table reflect the script's active grouping.

### Decision 5: Complete Retirement and Deletion of `MessageDetailsDialog`

**Rationale:**
With `ScriptRunDetailsView` using `MessagesView`:
1. `MessagesTableView` removes its fallback `_showMessageDetails` call.
2. `TopicPartitionTable` renders `MessageInspectorPanel` inside a clean `Dialog` with `dockPosition: InspectorDockPosition.side` and `onClose: () => Navigator.of(context).pop()`.
As a result, `MessageDetailsDialog` has zero remaining callers in the entire project. Deleting `lib/src/ui/message_details_dialog.dart` and `test/src/ui/message_details_dialog_test.dart` eliminates ~600 lines of dead, duplicated code and ensures all message inspection flows through the modern, feature-rich `MessageInspectorPanel`.

## Risks / Trade-offs

- **[Risk] Screen space on compact displays:** The script results view already has a left sidebar (`ScriptRunSidebar`, 300px). Adding a side-docked inspector panel could crowd the master stream on narrow laptop viewports.
  - *Mitigation:* The inspector supports bottom-docking (vertical split), collapsible drawer sizing, and maximized Focus Mode (`F` or maximize icon) which expands the inspector to 100% of the message viewport.
- **[Risk] State reset on view switcher tabs:** Switching between Table, Timeline, Diff, and Schema could lose active selection or scroll position.
  - *Mitigation:* `MessagesView` already uses `GlobalKey`s (`_tableViewKey`, `_timelineViewKey`, `_diffViewKey`) and cached visual order to preserve active selection across view mode changes.
