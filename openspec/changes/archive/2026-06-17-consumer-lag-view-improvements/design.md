## Context

The initial `ConsumerLagView` successfully fetches and displays consumer group details lazily. However, administrators need a more scannable, interactive, and customizable monitoring view. They require a tabular representation, customizeable update frequencies, column-based sorting on all tables, and grouping of partitions under their respective topics to keep the detail view clean.

## Goals / Non-Goals

**Goals:**
- Present consumer group data in a clean, scrollable grid/table layout.
- Include column stats (active members count and topics count) in the overview table.
- Display a matched-count indicator for group filters.
- Allow sorting of both main group table and details partition tables by clicking column headers.
- Allow customization of the auto-refresh interval (5s, 15s, 30s, 60s, or Disabled).
- In details view, group partitions by Topic and make partition lags visible only upon expanding a topic.

**Non-Goals:**
- Graphing historical lag metrics (this remains an instant snapshot view).

## Architecture & Data Design

### Rust API Updates
We will add `members_count` and `topics_count` fields to the `ConsumerGroupLag` struct in the Rust backend and the API bridge.
- `members_count`: Count of active consumers within the group.
- `topics_count`: Count of unique topics the group has member subscriptions or partition assignments for.

### Dart Model Update
The Flutter code-generator will translate these fields into the `ConsumerGroupLag` Dart class.

## UI Components & State Flow

### 1. Main Tabular View
- Replace the list of cards with a custom styled `DataTable` or `Table` widget.
- Columns:
  - Group ID (sortable)
  - State (sortable)
  - Protocol Type (sortable)
  - Consumers (sortable)
  - Topics Count (sortable)
  - Total Lag (sortable)
- Maintain `_sortColumnIndex` and `_sortAscending` in `_ConsumerLagViewState`.
- Re-sort `filteredLags` on build based on the selected column.

### 2. Search matched count
- Display a small subtitle/badge text next to the search input:
  - German: `X von Y Gruppen gefunden`
  - English: `Found X of Y groups`

### 3. Status/State Filter
- Render a DropdownButton next to the search filter, containing:
  - All (All states)
  - Stable
  - Empty
  - Dead
- Maintain `_statusFilter` in `_ConsumerLagViewState`. When filtering the groups
  list, check both `_filterText` and `_statusFilter` to determine if a group
  matches.

### 4. Customizable Refresh Interval
- Replace Switch with a Dropdown selector containing:
  - Off (Disabled)
  - 5 seconds
  - 15 seconds
  - 30 seconds
  - 60 seconds
- Maintain `_refreshIntervalSeconds` state. When changed, restart the timer.

### 4. Nested Topic Partition Details
- When a group table row is expanded:
  - Group partition lags by topic name: `Map<String, List<TopicPartitionLag>>`.
  - Display a table or list of Topics inside the group details view.
  - The topics table/list shows Topic name and Total Lag, and allows sorting
    alphabetically or by lag size (ascending/descending).
  - Render each Topic as a nested `ExpansionTile` or collapsible row.
  - Expanding a topic renders a `TopicPartitionTable` widget.
  - `TopicPartitionTable` is a nested `StatefulWidget` managing its own
    column-based sorting state (`_sortColumnIndex`, `_sortAscending`) for
    partition details.
