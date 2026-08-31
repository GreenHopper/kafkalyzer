## Why

Message results can already toggle ascending vs descending order, but sorting is locked to timestamp. Users often need to scan by partition, offset, key, or payload value instead. Extending the toolbar sort control to choose the sort field makes the results UI flexible without relying on table-only column sorts.

## What Changes

- **Sort field selection**: Let the user choose which message field drives ordering: timestamp, partition, offset, key, or value (payload).
- **Toolbar control**: Add a field selector next to the existing ascending/descending control in the results bar so both field and direction are visible and changeable.
- **Toolbar order**: Place all sorting controls (field selector and ascending/descending toggle) **before** the message view-type controls (table/timeline/diff/schema) in the results toolbar.
- **Per-view persistence**: Remember the selected sort field per view type (alongside the existing per-view sort direction).
- **Default remains timestamp**: When no field preference exists for a view type, keep sorting by timestamp (with the existing descending default for direction).

## Capabilities

### New Capabilities
<!-- None -->

### Modified Capabilities
- `message-sort-order`: Extend sort behavior beyond timestamp-only chronological order to support selectable sort fields, update ordering requirements, and persist the chosen field per view type.

## Impact

- **Affected code**:
  - `lib/src/ui/messages/messages_view.dart`: Sort-field state, SharedPreferences load/save, comparator in `_updateFilters()`, toolbar UI.
  - Localization (`.arb`) for field labels/tooltips (and possibly more generic asc/desc tooltips).
  - Widget tests in `test/src/ui/messages/`.
  - Possibly clarify interaction with `MessagesTableView` local column sorting (base list order only).
- **Dependencies**: None.
- **APIs**: No Rust/bridge changes; presentation-only sorting.
