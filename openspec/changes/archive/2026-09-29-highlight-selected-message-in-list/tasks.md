## 1. Table View Selection Highlighting & Viewport Auto-Scroll

- [x] 1.1 Attach a vertical `ScrollController` to `TableView.builder` in `MessagesTableView` via `verticalDetails` and implement programmatic auto-scrolling in `didUpdateWidget` / `initState` so that when `selectedMessage` changes, the row automatically scrolls into view. Verify by writing a widget test ensuring that selecting an off-screen message scrolls the table viewport.
- [x] 1.2 Upgrade the row selection styling in `_buildCell` of `MessagesTableView` to include a prominent background tint, top and bottom selection borders across all cells, and text emphasis, ensuring visual clarity regardless of horizontal scroll position. Verify with widget tests inspecting the cell decorations and borders.
- [x] 1.3 Synchronize interactive column sorting in `MessagesTableView` with `MessagesView`'s active sort order so sequential stepping (`J`/`K`, arrows, `<`/`>` buttons) navigates according to the displayed table order. Verify with a widget test that sorts by a column and steps to the next visual row.

## 2. Timeline and Diff Views Controllers & Selection Auto-Scroll

- [x] 2.1 Convert `MessagesTimelineView` to a `StatefulWidget`, instantiate a dedicated `ScrollController` passed to `Timeline.tileBuilder(controller: ...)`, and implement programmatic viewport auto-scrolling when `selectedMessage` changes. Verify with a widget test that stepping through messages keeps the selected timeline card visible.
- [x] 2.2 Add `selectedMessage` parameter to `MessagesDiffView`, pass `isSelected: widget.selectedMessage == current` to `TimelineMessageCard`, attach a dedicated `ScrollController` to `Timeline.tileBuilder(controller: ...)`, and implement viewport auto-scrolling on selection change. Verify with a widget test ensuring the active message diff card receives selection styling and scrolls into view.
- [x] 2.3 Wire `selectedMessage: _selectedMessage` from `MessagesView` to `MessagesDiffView` and verify theme contrast on active timeline and diff cards.

## 3. Verification & Regression Testing

- [x] 3.1 Expand `test/src/ui/messages/messages_view_stepper_test.dart` to verify that repeated stepping via keyboard (`J`/`K`/`ArrowDown`/`ArrowUp`) and stepper buttons maintains the active selection highlight and keeps the selected item visible in table, timeline, and diff views.
- [x] 3.2 Run `flutter test test/src/ui/messages/` and `dart analyze` to confirm all tests pass cleanly without lint or compilation warnings.
