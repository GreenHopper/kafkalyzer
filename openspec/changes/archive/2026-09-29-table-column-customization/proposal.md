## Why

In the Kafka message table view, users can project JSON payload fields as dynamic columns alongside fixed columns (Timestamp, Partition, Offset, Key, Content). However, fixed columns currently cannot be hidden or removed, cluttering the view when analyzing specific payloads. Additionally, column widths are static or fractional without any resize capability, causing text truncation for long field names, keys, and values. Adding column visibility controls and interactive column resizing solves these usability bottlenecks, allowing users to customize table density and focus directly on relevant data.

## What Changes

- **Standard Column Visibility Toggle**: Allow users to show or hide any standard/fixed column (Timestamp, Partition, Offset, Key, Content, and Step/Topic where applicable) via a column selector menu or header actions.
- **Interactive Column Resizing**: Enable users to dynamically resize column widths (for both standard columns and dynamic projected columns) by dragging header dividers or column boundaries.
- **Double-Click Auto-Fit Width**: Automatically adjust a column's width to fit its header and content when the user double-clicks the right column border.
- **Enhanced Column Presets and Persistence**: Persist column widths and visibility settings per topic (and a global fallback default) in `SharedPreferences`, restoring them seamlessly when opening a topic or restarting the application.
- **Reset Layout Action**: Allow resetting column visibility and widths back to system defaults.

## Capabilities

### New Capabilities
<!-- None: This feature directly extends table column management. -->

### Modified Capabilities
- `message-table-columns`: Adds requirements for standard column visibility configuration, interactive column resizing for both fixed and projected columns, and updated persistence format to store column visibility and widths.

## Impact

- **UI Components**:
  - `lib/src/ui/messages/views/messages_table_view.dart`: Update column rendering, replace hardcoded widths with dynamic width state, support drag-to-resize header dividers, and filter active columns based on visibility settings.
  - `lib/src/ui/messages/messages_view.dart`: Add column management menu/button in the table toolbar and manage combined column configuration state (visibility, widths, projections).
  - `lib/src/ui/messages/models/projected_column.dart`: Extend or complement model with standard column definitions, visibility, and width persistence.
- **Localization**:
  - `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: Add localized strings for column management actions, hide column labels, resize tooltips, and reset actions.
- **State & Storage**:
  - `SharedPreferences`: Update per-topic column preset schema to store column visibility flags and custom widths alongside projected column paths.
