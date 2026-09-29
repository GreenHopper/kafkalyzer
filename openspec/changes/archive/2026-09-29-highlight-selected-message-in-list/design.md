## Context

See `proposal.md` for motivation.

`MessagesView` provides three master message views: Table (`MessagesTableView`), Timeline (`MessagesTimelineView`), and Diff (`MessagesDiffView`), displayed alongside a dockable `MessageInspectorPanel`.

### Current State Across the Three Master Views:
1. **`MessagesTableView` (Table View)**:
   - Uses `TableView.builder` from `package:two_dimensional_scrollables` with fixed extents: 40 px header and 44 px per row.
   - Currently lacks a vertical `ScrollController` (`verticalDetails`), so it cannot programmatically scroll when the selection changes.
   - Its selection highlight is subtle (`primaryContainer` at 35% opacity), with a left border accent applied strictly to `colIdx == 0` (which disappears when scrolled horizontally).
   - Local table sorting (`_sortColumnIndex`) can diverge from `MessagesView`'s sort order, causing stepper navigation to jump out of order.

2. **`MessagesTimelineView` (Timeline View)**:
   - Uses `Timeline.tileBuilder` from `package:timelines_plus`.
   - It is currently a `StatelessWidget` and does not attach a `ScrollController` to `Timeline.tileBuilder`.
   - While `TimelineMessageCard` has an `isSelected` property, the view cannot programmatically auto-scroll when a user steps through messages, causing the active message card to quickly fall out of view.

3. **`MessagesDiffView` (Diff View)**:
   - Uses `Timeline.tileBuilder` to render `TimelineMessageCard` with JSON diffs.
   - Currently does **not** accept `selectedMessage` at all, so `isSelected` is permanently false and active messages are never highlighted in diff mode.
   - Does not attach a `ScrollController` to `Timeline.tileBuilder`, so it cannot auto-scroll to the active message.

## Goals / Non-Goals

**Goals:**
- Provide dedicated vertical scroll controllers and programmatic viewport auto-scrolling across **all three master views** (`MessagesTableView`, `MessagesTimelineView`, and `MessagesDiffView`) so that stepping through messages via the inspector or keyboard always keeps the active message visible.
- Provide clear, high-contrast visual selection styling across all three master views:
  - Table: prominent background tint, top/bottom borders across all cells, leading border accent on column 0, and bold text.
  - Timeline: elevated card with prominent outline and background tint.
  - Diff: accept `selectedMessage`, highlight the active diff card, and scroll to it.
- Synchronize sequential stepping (`J`/`K`, arrow keys, `<`/`>` buttons) with the visual sort order of the active view.

**Non-Goals:**
- Modifying Kafka message ingestion, stream throttling, or rust-lib bridge code.
- Altering internal tree nodes inside `SmartVirtualJsonTree`.

## Decisions

### Decision 1: Dedicated `ScrollController` and Viewport Auto-Scroll for Every Master View
Each of the three views will manage its own `ScrollController` to ensure independent, reliable viewport scrolling without interfering with each other's lifecycle or state.

1. **`MessagesTableView`**:
   - Attach a `ScrollController` via `verticalDetails: ScrollableDetails.vertical(controller: _verticalScrollController)`.
   - Because row heights are deterministic (40 px header + 44 px per row), row `i` starts at `40.0 + i * 44.0` and ends at `40.0 + (i + 1) * 44.0`.
   - On `didUpdateWidget` or when `selectedMessage` changes:
     - If the row is above the current viewport: scroll to bring it into view with a 44 px padding margin.
     - If the row is below the viewport: scroll to bring it to the bottom with a 44 px padding margin.
     - Use `animateTo` (150ms, `Curves.easeOutCubic`) or `jumpTo` during rapid keyboard repeats.

2. **`MessagesTimelineView`**:
   - Convert from `StatelessWidget` to `StatefulWidget`.
   - Instantiate and manage a `ScrollController` attached to `Timeline.tileBuilder(controller: _scrollController, ...)`.
   - Auto-scroll to the selected card when `selectedMessage` changes using item keys (`GlobalKey` per visible/adjacent tile with `Scrollable.ensureVisible(context, alignment: 0.5)`) or calculated offset estimation based on average tile height (~160 px), followed by fine alignment.

3. **`MessagesDiffView`**:
   - Add `final KafkaMessage? selectedMessage;` to `MessagesDiffView` and pass `widget.selectedMessage` from `MessagesView`.
   - Pass `isSelected: widget.selectedMessage == current` to `TimelineMessageCard` in `_buildDiffCard`.
   - Instantiate and manage a `ScrollController` attached to `Timeline.tileBuilder(controller: _scrollController, ...)`.
   - On `didUpdateWidget`, if `selectedMessage` changes, auto-scroll to ensure the active diff card is visible in the viewport.

### Decision 2: Multi-Column, High-Contrast Row Selection Highlighting in `MessagesTableView`
- **Background**: Increase row tint to `colorScheme.primaryContainer.withValues(alpha: 0.65)` in dark mode and high-contrast blend in light mode.
- **Borders**: Render top and bottom border lines (`colorScheme.primary.withValues(alpha: 0.8)`) across **every** cell in the selected row, ensuring selection remains obvious even if scrolled horizontally past column 0.
- **Leading Accent**: Keep a 4 px accent border on `colIdx == 0` for visual anchoring.
- **Text Emphasis**: Apply `FontWeight.w600` and `colorScheme.onPrimaryContainer` to primary text within selected cells.

### Decision 3: Card Selection Highlighting in Timeline and Diff Views
- In `TimelineMessageCard`, strengthen the active border width (2.5 px) and color (`colorScheme.primary`), with elevated shadow and `primaryContainer` tint.
- In `MessagesDiffView`, ensure `TimelineMessageCard` receives `isSelected: widget.selectedMessage == current` so it renders the same distinctive highlight.

### Decision 4: Stepping Synchronization with Table Display Sort Order
- When `MessagesTableView` sorts columns locally via header click (`_sortColumnIndex`), communicate the visual sort order to `MessagesView` or synchronize with `MessagesView._cachedSortedMessages` so that sequential stepping (`J`/`K` or stepper buttons) steps to the visually adjacent row.

## Risks / Trade-offs

- **[Variable Tile Heights in Timeline/Diff Views]** Unlike table rows, timeline cards have dynamic heights depending on JSON payloads and diff contents.
  → *Mitigation*: Use `Scrollable.ensureVisible` when the target tile is mounted, or combine an estimated offset scroll with `ensureVisible` once the child is materialized in the viewport.
- **[Rapid Stepping Jitter]** Holding down `J`/`K` or arrow keys could cause overlapping animation requests.
  → *Mitigation*: Use short animation durations (100–150ms) or `jumpTo` when stepping occurs faster than the animation duration.
- **[ScrollController Lifecycle]** Multiple views switching via `ViewModeSwitcher`.
  → *Mitigation*: Each view encapsulates and disposes its own `ScrollController` cleanly in `dispose()`.
