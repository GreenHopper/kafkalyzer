## Why

Currently, the embedded dockable split-screen inspector (`MessageInspectorPanel`) is only integrated into the Topic Explorer feature (`TopicDetailView` via `MessagesView`). When running a script and investigating message results in `ScriptRunDetailsView`, tapping a message in Table, Timeline, or Diff view opens the old modal `MessageDetailsDialog`, covering 85% of the screen.

This creates a jarring, inconsistent UI/UX across Kafkalyzer: users in the scripting feature lose their stream context, cannot dock message details to the side or bottom, cannot use sequential stepper navigation (`J`/`K`/arrow keys or `<`/`>` buttons) with auto-scrolling, and cannot toggle Focus Mode (`F`). Furthermore, maintaining the legacy `MessageDetailsDialog` (578 lines of duplicate code) introduces maintenance overhead and visual discrepancy. Migrating script execution results and single-message inspection to `MessageInspectorPanel` enables the complete removal of `MessageDetailsDialog` from the codebase.

## What Changes

- **Replace Modal Dialog with Integrated Inspector in Script Runs**: Refactor `ScriptRunDetailsView` to render message results using `MessagesView` instead of directly building standalone `MessagesTableView`, `MessagesTimelineView`, and `MessagesDiffView` with `showDialog(MessageDetailsDialog)`.
- **Streamline Script Run Header**: Clean up `ScriptRunHeader` by moving redundant message view controls (`ViewModeSwitcher` and `MessageSearchBar`) to `MessagesView`, keeping `ScriptRunHeader` focused on run context (back navigation, run timestamp, and script-specific timeline modes like `byTopic`, `chronological`, `groupedByStep`).
- **Custom Schema View Integration**: Enhance `MessagesView` to accept an optional `schemaViewBuilder` so `ScriptSchemasView` is seamlessly rendered when the schema view tab is selected in script results.
- **Script-Specific Sorting & Extraction Support**: Ensure `MessagesView` properly honors script timeline ordering (e.g. chronological, grouped by topic, grouped by step) via custom sort comparators, and forwards `stepExtractions`, `showTopic`, and `showStep` to the underlying views.
- **Consistent Keyboard & Stepper Navigation**: Enable sequential stepping (`J`/`K`/arrows), Focus Mode (`F`/maximize), dock switching (side/bottom), and active row/card selection auto-scrolling when investigating script execution results.
- **Migrate Consumer Lag Inspection**: Update `TopicPartitionTable` to use `MessageInspectorPanel` when inspecting lagging partition messages.
- **Remove `MessageDetailsDialog` Completely**: Delete `lib/src/ui/message_details_dialog.dart` and its test file `test/src/ui/message_details_dialog_test.dart`, removing all dead code and fallback invocations in `MessagesTableView`.

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `message-inspector-shell`: Extend requirement `Embedded Dockable Split-Screen Inspector` and `Sequential Message Stepper` so that script execution results (`ScriptRunDetailsView`) embed the dockable inspector and support sequential message navigation, selection highlighting, and docking layouts identically to Topic Explorer, and deprecate/remove `MessageDetailsDialog`.

## Impact

- **Affected Code**:
  - `lib/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart`: Switch message rendering to `MessagesView` with `stepExtractions`, `showTopic`, `showStep`, and embedded inspector.
  - `lib/src/features/scripting/presentation/widgets/script_history/script_run_header.dart`: Clean up duplicate search and view-mode controls, retaining run metadata and timeline grouping segment controls.
  - `lib/src/ui/messages/messages_view.dart`: Add `schemaViewBuilder` and optional `sortComparator` to allow seamless embedding in scripting contexts.
  - `lib/src/features/consumer/presentation/topic_partition_table.dart`: Replace `MessageDetailsDialog` with `MessageInspectorPanel` for single-message lagging inspection.
  - `lib/src/ui/messages/views/messages_table_view.dart`: Remove legacy `_showMessageDetails` fallback to `MessageDetailsDialog`.
  - `lib/src/ui/message_details_dialog.dart`: Delete file completely.
  - `test/src/ui/message_details_dialog_test.dart`: Delete file completely.
  - `test/src/features/consumer/presentation/topic_partition_table_test.dart`: Update assertions to check for `MessageInspectorPanel`.
  - `test/src/ui/kafka_message_table_test.dart`: Remove assertion for `MessageDetailsDialog`.
- **Dependencies**: No external dependencies added.
- **APIs & Breaking Changes**: `MessageDetailsDialog` is deleted. Any callers now utilize `MessageInspectorPanel`.
