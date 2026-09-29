## Why

When inspecting Kafka messages in the side panel or bottom dock, users frequently navigate sequentially through messages using keyboard shortcuts (`J`/`K` or `ArrowDown`/`ArrowUp`) or the inspector's stepper buttons. Currently, stepping through messages causes the selection in the master message list to quickly become lost or disorienting:
1. The message list does not auto-scroll to keep the active message visible, causing the selected message to move off-screen after stepping a couple of times.
2. The selection highlight in `MessagesTableView` is subtle (`primaryContainer` at 35% opacity) and places its primary visual indicator (a 3.5px border) exclusively on the first column (`Timestamp`), which disappears completely if the table is scrolled horizontally.
3. In `MessagesDiffView`, message selection is not represented at all, and in `MessagesTimelineView`, stepping does not bring the card into the viewport.

This change ensures that navigating messages in the inspector keeps the user oriented by prominently highlighting the active message across the entire row/card and automatically scrolling the message list to keep the active item within the visible viewport.

## What Changes

- **Automatic Viewport Scrolling**: When a message is selected or stepped through (via inspector stepper buttons, keyboard shortcuts, or programmatic selection), `MessagesTableView` and `MessagesTimelineView` automatically scroll the viewport smoothly so the active message remains clearly visible.
- **Prominent Row Highlighting in `MessagesTableView`**:
  - Enhance row selection styling to apply a clear, high-contrast background tint (e.g. `primaryContainer` with strong contrast or theme-adapted selection highlight).
  - Add a visible accent indicator that remains effective regardless of horizontal scroll position (such as distinct row borders, active row indicator across cells, or subtle elevation/outline).
  - Ensure projected columns and all cell contents reflect the selected row state.
- **Synchronization with Active List Order**: Ensure sequential stepping always respects the visual display order of the currently visible list, including when sorted by column headers in the table.
- **Diff View Selection Support**: Connect `selectedMessage` to `MessagesDiffView` and visually highlight the active message card or comparison node.

## Capabilities

### New Capabilities
*None.*

### Modified Capabilities
- `message-inspector-shell`: Enhances `Requirement: Master Stream Selection Highlighting` with automated viewport scrolling to keep selected messages in view, higher-contrast multi-column visual highlighting, and selection tracking across all message list views (table, timeline, diff).

## Impact

- **UI Components**:
  - `lib/src/ui/messages/views/messages_table_view.dart`: Add vertical `ScrollController` with auto-scroll-to-index logic; enhance row selection styling with high-contrast background and full-row selection indicators.
  - `lib/src/ui/messages/messages_view.dart`: Coordinate selection change events and ensure stepping reflects the active view's sorted message sequence.
  - `lib/src/ui/messages/views/messages_timeline_view.dart`: Add scroll-to-index support for the active timeline tile.
  - `lib/src/ui/messages/views/messages_diff_view.dart`: Accept `selectedMessage` and highlight active message diff card.
- **Dependencies**: Uses existing Flutter framework scroll controllers and `package:two_dimensional_scrollables` `verticalDetails` API without introducing new external dependencies.
- **Tests**: Add widget tests verifying that stepping sequentially scrolls the viewport to keep the active message visible and verifies prominent selection decoration in table and timeline views.
