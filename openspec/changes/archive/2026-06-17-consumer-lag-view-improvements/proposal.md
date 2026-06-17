## Why

Several usability and performance enhancements are necessary to make the consumer lag view more intuitive, scannable, and developer-friendly:
1. **Scannability**: A card-based layout is hard to scan. A tabular layout with sortable columns allows users to instantly identify groups with the largest lag or active members.
2. **First-Glance Stats**: Knowing the number of active consumers (members) and topics consumed at a glance helps identify group topology.
3. **Better Filter Visibility**: Displaying the number of matched consumer groups helps track large lists.
4. **Custom Auto-Refresh**: Users need control over the polling interval depending on network speed and cluster size.
5. **Decluttered Detail View**: Consumer groups subscribing to many partitions/topics clutter the UI. Grouping by topic first, then lazily expanding partitions, makes the detail view digestible.

## What Changes

- **Tabular Main Layout**:
  - Replace the card list with a table-like layout representing consumer group records.
  - Add columns for: Group ID, State, Protocol, Active Members (Consumers), Topics Count, and Total Lag.
  - Make headers clickable to toggle sorting.
- **Match Count indicator**:
  - Show a label "Found X of Y consumer groups" when searching/filtering.
- **Status Filter**:
  - Add a dropdown filter for Group State/Status (e.g., All, Stable,
    Empty, Dead) next to the search input, allowing users to quickly
    filter and isolate non-running groups.
- **Interval Control**:
  - Replace the auto-refresh switch with a dropdown or input selector
    enabling users to customize the refresh interval (e.g., 5s, 15s, 30s,
    60s).
- **Group Detail Tree**:
  - Within each group's expanded details, group partitions by Topic first.
  - Display a sub-table or list of topics. The topic list/table must be
    sortable both alphabetically (by topic name) and by lag size (total lag
    of the topic).
  - Clicking on a topic expands to show its partition offsets and lags.
  - Make partition sub-table columns sortable.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `consumer-lag-monitoring`: Enhanced with tabular layout, customizable refresh intervals, column sorting, and nested topic grouping.

## Impact

- **Frontend (Dart/Flutter)**:
  - Re-design `ConsumerLagView` and its list builder to render a table.
  - Implement sorting states and handlers in `_ConsumerLagViewState`.
  - Add refresh interval state and timer updates.
  - Redesign partition detail table to support expandable topic groups and detail sorting.
