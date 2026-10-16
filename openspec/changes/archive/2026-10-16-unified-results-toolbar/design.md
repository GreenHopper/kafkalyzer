# Design

## Context

In `MessagesView`, loaded messages are displayed in one of three view modes: Table (`table`), Timeline (`timeline`), or Diff (`diff`), with optional Schema view (`schema`).
The results toolbar above the message view controls:
1. Sort field (`_sortField`) and sort direction (`_sortAscending`) via `PopupMenuButton` and `IconButton`.
2. View mode switching via `ViewModeSwitcher`.
3. In-memory message filtering via `MessageSearchBar`.
4. Table column configuration via `MenuAnchor` (when in `table` view).

Currently:
- `MessageSearchBar` displays a static hint `searchResults` ("Search results..."). Users often confuse this with the server-side Kafka search configuration in `TopicDetailView`.
- In `table` view, `MessagesTableView` implements its own interactive sorting by clicking column headers (`_sortColumnIndex`, `_sortAscending`). The toolbar's `message_sort_field_selector` dropdown sits directly above the table headers, creating duplicate and unsynchronized sort controls.
- `ViewModeSwitcher` renders only icon glyphs in `ToggleButtons` without descriptive text.

## Goals / Non-Goals

**Goals:**
- Provide clear visual distinction between in-memory message filtering and server-side Kafka querying by embedding the total loaded count into `MessageSearchBar` (e.g. `Filter in 200 loaded messages...`).
- Display live match status (e.g., `14 of 200 matches` when filtered, or `200 loaded messages` when unfiltered) in the toolbar.
- Hide toolbar sort controls (`message_sort_field_selector` and `message_sort_order_toggle`) when `_activeView == 'table'`, delegating sorting entirely to table column headers.
- Keep toolbar sort controls visible when `_activeView == 'timeline'` or `_activeView == 'diff'`.
- Add localized text labels to `ViewModeSwitcher` segments while preserving compact desktop layout.
- Maintain full localization in English and German via `AppLocalizations`.

**Non-Goals:**
- Unifying or synchronizing the underlying sorting engine between `MessagesTableView` and `MessagesView` (table sorting operates on projected table columns including JSON paths, whereas toolbar sorting operates on top-level Kafka message properties).
- Redesigning `TopicDetailView`'s server-side search configuration (handled in a separate capability).

## Decisions

### 1. In-Memory Search Placeholder & Counter in `MessageSearchBar`

**Design:**
Pass `totalCount: widget.messages.length` into `MessageSearchBar`.
In `MessageSearchBar`:
- When search phrase is empty:
  - Hint text: `l10n.filterInLoadedMessages(widget.totalCount)` -> "Filter in {count} loaded messages..." / "In {count} geladenen Nachrichten filtern...".
  - If desired, render a subtle count badge or text next to the search bar indicating total loaded messages (e.g. `200 messages`).
- When search phrase is non-empty:
  - Display `l10n.matchesOfTotal(widget.matchCount, widget.totalCount)` -> "{matchCount} of {totalCount} matches" / "{matchCount} von {totalCount} Treffern".

*Alternatives considered:*
- Static placeholder "In-memory filter...": Rejected because showing the concrete loaded message count immediately reinforces that it operates solely on the already fetched batch.

### 2. Context-Aware Conditional Rendering of Sort Controls

**Design:**
In `MessagesView.build()`:
```dart
if (_activeView != 'table') ...[
  Tooltip(
    message: l10n.sortFieldTooltip,
    child: PopupMenuButton<String>(
      key: const Key('message_sort_field_selector'),
      initialValue: _sortField,
      onSelected: _onSortFieldChanged,
      ...
    ),
  ),
  Tooltip(
    message: _sortAscending ? l10n.sortOrderAscending : l10n.sortOrderDescending,
    child: IconButton(
      key: const Key('message_sort_order_toggle'),
      icon: Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
      onPressed: _toggleSortOrder,
    ),
  ),
  const SizedBox(width: 8),
],
```
When `_activeView == 'table'`, these two widgets are simply omitted from the toolbar. The table's column headers (`MessagesTableView`) serve as the authoritative sort UI.
When switching back to `timeline` or `diff`, the dropdown and toggle reappear automatically.

### 3. Labeled `ViewModeSwitcher`

**Design:**
Update `ViewModeSwitcher` to render a row with icon and text in each segment:
```dart
children: [
  _buildSegment(
    context,
    icon: Icons.table_chart,
    label: l10n.viewModeTable,
    tooltip: l10n.viewModeTableTooltip,
  ),
  _buildSegment(
    context,
    icon: Icons.view_list,
    label: l10n.viewModeTimeline,
    tooltip: l10n.viewModeTimelineTooltip,
  ),
  _buildSegment(
    context,
    icon: Icons.difference,
    label: l10n.viewModeDiff,
    tooltip: l10n.viewModeDiffTooltip,
  ),
  if (showSchemaView)
    _buildSegment(
      context,
      icon: Icons.data_object,
      label: l10n.viewModeSchema,
      tooltip: l10n.viewModeSchemaTooltip,
    ),
]
```
Helper `_buildSegment`:
```dart
Widget _buildSegment(BuildContext context, {required IconData icon, required String label, required String tooltip}) {
  return Tooltip(
    message: tooltip,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}
```
Set `constraints: const BoxConstraints(minHeight: 32)`.

### 4. Localization Strings

In `app_en.arb` and `app_de.arb`:
- `viewModeTable`: "Table" / "Tabelle"
- `viewModeTimeline`: "Timeline" / "Zeitverlauf"
- `viewModeDiff`: "Diff" / "Vergleich"
- `viewModeSchema`: "Schema" / "Schema"
- `filterInLoadedMessages`: "Filter in {count} loaded messages..." / "In {count} geladenen Nachrichten filtern..."
- `matchesOfTotal`: "{matchCount} of {totalCount} matches" / "{matchCount} von {totalCount} Treffern"
- `loadedMessagesCount`: "{count} loaded messages" / "{count} geladene Nachrichten"

## Risks / Trade-offs

- **Toolbar Width on Narrow Windows**: Adding text labels to view mode buttons expands the width of `ViewModeSwitcher` from ~160px to ~300px. On desktop monitors (min width 1024px), this fits comfortably alongside the 300px search bar. In responsive scenarios or narrow split panels, `IntrinsicWidth` and `Flexible` prevent overflows.
