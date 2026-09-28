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
The system SHALL persist active projected column paths for each topic in local storage (`SharedPreferences`) and automatically restore them when the user views that topic.

#### Scenario: Automatic preset saving
- **WHEN** a user adds or removes a projected column while viewing a specific topic
- **THEN** the updated list of projected column paths SHALL be saved to `SharedPreferences` under a topic-specific key
- **AND** existing standard columns (Timestamp, Partition, Offset, Key, Content) SHALL remain available

#### Scenario: Preset restoration upon topic opening
- **WHEN** a user navigates to or streams a topic that has saved projected column configurations
- **THEN** the saved projected columns SHALL be automatically loaded from `SharedPreferences` and applied to the table view

#### Scenario: Reset columns to default
- **WHEN** the user selects the reset/clear columns action
- **THEN** all custom projected columns SHALL be removed for the current topic
- **AND** the persisted preset in `SharedPreferences` SHALL be cleared
