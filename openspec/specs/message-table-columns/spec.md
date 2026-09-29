# message-table-columns Specification

## Purpose

Controls when Step and Topic columns appear in the shared Kafka message table so explorer stays focused and scripting keeps multi-step context.

## Requirements

### Requirement: Hide Step and Topic columns in topic explorer table
When the user views Kafka messages in the topic explorer using table view, the system SHALL NOT display the Step column or the Topic column.

#### Scenario: Explorer table omits script-oriented columns
- **WHEN** the user opens a topic in the topic explorer feature
- **AND** the message results are shown in table view
- **THEN** the table SHALL NOT include a Step column
- **AND** the table SHALL NOT include a Topic column

### Requirement: Show Step and Topic columns in scripting message tables
When the user views Kafka messages from the scripting feature in table view, the system SHALL display the Step column and the Topic column.

#### Scenario: Script run details table includes Step and Topic
- **WHEN** the user views message results from a script run in table view
- **THEN** the table SHALL include a Step column
- **AND** the table SHALL include a Topic column

### Requirement: Dynamic Projected Columns in Message Table View
The message table view SHALL support user-defined dynamic projected columns extracted from JSON message payloads based on JSON paths (supporting nested object dot-notation and array indices, e.g. `customer.id`, `address.city`, `leistungen[0].transportId`).

#### Scenario: Rendering projected column cells
- **WHEN** the message table is configured with one or more projected column paths
- **THEN** the table SHALL extract the corresponding value from each row's payload using the JSON path
- **AND** the extracted value SHALL be rendered in a dedicated column cell
- **AND** extracted cell values SHALL be cached per table row to prevent redundant JSON decoding or string traversal during scroll

#### Scenario: Sorting and filtering projected columns
- **WHEN** a user clicks the header of a projected column
- **THEN** the table SHALL sort rows ascending or descending based on the extracted values
- **AND** when a user clicks the filter icon on a projected column header, a filter dialog SHALL open allowing substring filtering

#### Scenario: Removing a projected column
- **WHEN** a user clicks the remove action (e.g. close icon) on a projected column header
- **THEN** the projected column SHALL be removed from the active table columns
- **AND** the table layout SHALL immediately adjust to reflect the remaining columns

### Requirement: Per-Topic Column Presets Persistence
The system SHALL persist active projected column paths, standard column visibility settings, and custom column widths for each topic in local storage (`SharedPreferences`) and automatically restore them when the user views that topic.

#### Scenario: Automatic preset saving
- **WHEN** a user adds or removes a projected column, changes a column's width, or toggles visibility of any standard column while viewing a specific topic
- **THEN** the updated configuration (projected columns, visible standard columns, and custom column widths) SHALL be saved to `SharedPreferences` under a topic-specific key

#### Scenario: Preset restoration upon topic opening
- **WHEN** a user navigates to or streams a topic that has saved column configurations
- **THEN** the saved projected columns, column visibility preferences, and custom column widths SHALL be automatically loaded from `SharedPreferences` and applied to the table view

#### Scenario: Reset columns to default
- **WHEN** the user selects the reset/clear columns action
- **THEN** all custom projected columns SHALL be removed for the current topic
- **AND** all standard columns SHALL be restored to visible with their default widths
- **AND** the persisted preset in `SharedPreferences` SHALL be cleared

### Requirement: Configurable Standard Column Visibility
The system SHALL allow users to customize the visibility of standard fixed columns (Timestamp, Partition, Offset, Key, Content, as well as Step and Topic when active), enabling any standard column to be hidden or shown.

#### Scenario: Toggling standard column visibility from column menu
- **WHEN** the user opens the column configuration menu and toggles off the visibility checkbox for a standard column (e.g., Partition or Offset)
- **THEN** that column SHALL immediately be removed from the rendered table view
- **AND** the table layout SHALL recompute spans for the remaining visible columns

#### Scenario: Quick-hide action on column header
- **WHEN** the user triggers the hide/remove action on a visible standard column header
- **THEN** the target standard column SHALL be hidden from the table view
- **AND** the column menu SHALL reflect that the column is unchecked

#### Scenario: Minimum visible column safeguard
- **WHEN** only one column remains visible in the table
- **THEN** the system SHALL disable hiding that last remaining column to ensure the table never becomes completely blank

### Requirement: Interactive Column Resizing
The message table view SHALL allow users to resize the width of any visible column (both standard fixed columns and dynamic projected columns) by dragging column dividers in the table header.

#### Scenario: Dragging header divider to adjust column width
- **WHEN** the user drags the right-edge resize handle of a table column header
- **THEN** the column's width SHALL interactively adjust during the drag gesture
- **AND** the new width SHALL be applied to all cells in that column without rebuilding the underlying row data

#### Scenario: Column width boundary constraints
- **WHEN** the user attempts to shrink a column width below the minimum allowed width (e.g. 60 pixels)
- **THEN** the column width SHALL clamp to the minimum allowed width

#### Scenario: Double-clicking divider to auto-fit column width
- **WHEN** the user double-clicks the right-edge resize handle of a table column header
- **THEN** the system SHALL compute the optimal width based on the header label and the column's cell contents (including padding and icons)
- **AND** the column width SHALL adjust to fit the computed width clamped between the minimum and maximum width limits
- **AND** the updated column width SHALL be persisted in the active topic's column configuration preset

#### Scenario: Persisting column width adjustment
- **WHEN** the user completes a column resize gesture
- **THEN** the updated column width SHALL be persisted in the active topic's column configuration preset
