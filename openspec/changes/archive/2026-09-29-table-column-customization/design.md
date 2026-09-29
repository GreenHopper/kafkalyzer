## Context

The message table view in `MessagesTableView` renders Kafka messages with standard fixed columns (Timestamp, Step, Topic, Partition, Offset, Key, Content) and dynamic JSON-projected columns using `two_dimensional_scrollables` (`TableView.builder`). Currently, column spans are hardcoded with fixed or fractional widths, and only dynamic projected columns have a remove action. Fixed columns cannot be hidden or removed, and column widths cannot be resized by the user, leading to truncated data when viewing wide values (e.g. nested JSON keys, long offsets, or short partition numbers wasting space).

## Goals / Non-Goals

**Goals:**
- Provide interactive column resizing by dragging column borders in table headers for both standard and projected columns.
- Provide double-click auto-fit on the right column border to resize the column to fit its header and visible content.
- Support hiding and showing any standard column (Timestamp, Partition, Offset, Key, Content, Step, Topic) via a dedicated column selector menu and header context action.
- Prevent invalid empty table states by requiring at least one column to remain visible.
- Persist per-topic column configurations (visible columns, custom column widths, and projected columns) in `SharedPreferences`, seamlessly backward-compatible with existing preset JSON.
- Provide a clear "Reset columns" action to restore default visibility and default widths.

**Non-Goals:**
- Arbitrary drag-and-drop column reordering across arbitrary positions (columns remain organized by their logical grouping: standard prefix columns -> projected columns -> content, or standard order).
- Modifying underlying message consumption or backend Rust APIs.

## Decisions

### 1. Unified Column Configuration Model (`TableColumnConfig`)
**Decision:** Create a cohesive configuration model `TableColumnConfig` (or extend presets) containing:
- `hiddenColumns`: `Set<String>` of column IDs that the user has chosen to hide.
- `columnWidths`: `Map<String, double>` of custom column widths in logical pixels.
- `projectedColumns`: `List<ProjectedColumn>` representing active dynamic JSON projections.

Standard column IDs: `timestamp`, `step`, `topic`, `partition`, `offset`, `key`, `content`.
Projected column IDs: prefixed or normalized by their path (e.g., `proj:customer.id`).

*Alternatives considered:*
- Separate independent `SharedPreferences` keys for widths and visibility: Rejected because managing 3 separate keys per topic leads to synchronization issues and messy reset handling.
- Retaining legacy list format: Upgrading the topic preset JSON to an object `{ "version": 2, "projectedColumns": [...], "hiddenColumns": [...], "columnWidths": {...} }` with backward compatibility for legacy `List<dynamic>` parses cleanly without data loss.

### 2. Header Resize Gesture with `MouseRegion` and `GestureDetector`
**Decision:** Embed an interactive resize handle on the right boundary of each column header cell.
- The resize handle is a 6-pixel wide hit-test area aligned to `Alignment.centerRight`.
- Displays `SystemMouseCursors.resizeColumn` on hover.
- Captures `onHorizontalDragUpdate` to adjust the column width in real-time (`(currentWidth + delta.dx).clamp(minWidth, maxWidth)`).
- Default minimum width constraint: 60.0 px; default maximum width constraint: 800.0 px.
- During drag, local state in `MessagesTableView` immediately updates the column span without re-evaluating the underlying `_cachedData` rows.
- On `onHorizontalDragEnd`, triggers callback to notify parent and persist preferences to `SharedPreferences`.

*Alternatives considered:*
- Using an external table package or rewriting to `DataTable2`: `DataTable2` does not handle 2D virtualized scrolling with dynamic column projection and large message counts as efficiently as `two_dimensional_scrollables` with custom cell recycling.
- Dedicated modal dialog for entering numeric pixel widths: Much worse user experience compared to direct manipulation dragging on header boundaries.

### 3. Column Visibility Management UI
**Decision:**
- Add a "Columns" (`Spalten`) menu anchor button in the table toolbar (using Material UI `MenuAnchor` / `PopupMenuButton`).
- The menu lists standard columns with checkboxes, plus clear labels for pinned projected columns.
- Toggling a checkbox immediately updates column visibility. If only 1 column is visible, disabling its checkbox is blocked or disabled.
- Standard column headers also provide a quick "Hide column" option (either in a header context menu or via header actions).

*Alternatives considered:*
- Only allow hiding via right-click header menu: Hard to discover and impossible to unhide a column that is already hidden. A persistent toolbar menu allows both hiding and restoring columns.

### 4. Spans Calculation in `MessagesTableView`
**Decision:** Convert all columns to explicit pixel widths managed via `columnWidths` map (falling back to sensible default widths: Timestamp: 180, Step: 120, Topic: 150, Partition: 90, Offset: 110, Key: 240, Content: 360, Projected: 150).
- Using explicit pixel widths for all columns makes horizontal scrolling predictable and enables column resizing for Key and Content without unpredictable fractional layout jumps during dragging.

### 5. Auto-Fit Width Calculation on Double-Click
**Decision:** Handle `onDoubleTap` in the resize handle's `GestureDetector`.
- When triggered for a column:
  - Header width: Measure header title text using `TextPainter` with header font style, adding space for filter/sort icons and padding (~56px).
  - Cell content width: Measure text across the current `_cachedData` rows (capped at 100 rows for high throughput performance) using `TextPainter` with monospace font style, adding cell padding (32px).
  - Calculated optimal width = `max(headerWidth, maxCellWidth)`.
  - Clamp between minimum (60.0 px) and maximum (800.0 px).
  - Immediately update column width and invoke persistence callback.

## Risks / Trade-offs

- **[Risk]** User resizes all columns to be very wide, causing extreme horizontal scroll overflow.
  - *Mitigation:* `TableView` natively supports horizontal scrolling via `TwoDimensionalScrollable`. Clamp column widths to a sensible maximum (e.g. 800px) and provide a one-click "Reset columns" button.
- **[Risk]** User hides all columns, leaving an empty table.
  - *Mitigation:* Enforce a minimum of 1 visible column; disable the hide toggle for the last remaining active column.
- **[Risk]** Existing saved topic presets in user environments could fail to decode.
  - *Mitigation:* In `_loadProjectedColumnsPreference()`, detect if the JSON is a `List` (legacy format) or a `Map` (new format). Migrate legacy lists gracefully without errors.
- **[Risk]** Frequent persistence calls during dragging degrade UI performance.
  - *Mitigation:* Update visual widths in local `setState` during `onHorizontalDragUpdate`; only trigger asynchronous `SharedPreferences` write in `onHorizontalDragEnd`.
