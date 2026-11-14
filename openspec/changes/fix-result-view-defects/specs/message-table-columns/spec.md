## ADDED Requirements

### Requirement: Column Filters Match Full Values with Empty Filter State
A message table column filter SHALL match case-insensitively against the complete value of that column for each row; for the Content column this is the full message payload, not the shortened preview shown in the cell. When the active column filters hide every loaded row, the table SHALL keep its header and show a localized empty state stating that no rows match the column filters, with a "Reset filters" action.

#### Scenario: Content filter matches beyond the preview length
- **WHEN** a message payload contains the filter text only after the part shown in the Content cell preview
- **AND** the user applies that text as Content column filter
- **THEN** the row for that message SHALL remain visible

#### Scenario: Content filter matches fields omitted from the preview
- **WHEN** a JSON payload contains a field with a null value that the Content cell preview omits
- **AND** the user filters the Content column for that field name
- **THEN** the row for that message SHALL remain visible

#### Scenario: Column filters hide every row
- **WHEN** messages are loaded and the active column filters match none of them
- **THEN** the table SHALL show the column header and an empty state with a "Reset filters" action instead of a blank table

#### Scenario: Resetting column filters from the empty state
- **WHEN** the user activates "Reset filters" in the empty state
- **THEN** all column filters SHALL be cleared and all loaded rows SHALL be shown again
