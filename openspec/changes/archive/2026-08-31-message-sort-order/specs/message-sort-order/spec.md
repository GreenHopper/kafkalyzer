## Purpose

Lets users choose and persist chronological ascending or descending order for Kafka messages shown in the shared results UI, per view type, defaulting to newest-first.

## ADDED Requirements

### Requirement: Sort order control in results toolbar
The message results toolbar SHALL include a control that displays the current chronological sort order (ascending or descending) for the active view type and allows the user to switch between the two orders.

#### Scenario: Toggle from descending to ascending
- **WHEN** the message results are shown with descending sort order
- **AND** the user activates the sort order control
- **THEN** the system SHALL switch to ascending chronological order
- **AND** the control SHALL indicate ascending order

#### Scenario: Toggle from ascending to descending
- **WHEN** the message results are shown with ascending sort order
- **AND** the user activates the sort order control
- **THEN** the system SHALL switch to descending chronological order
- **AND** the control SHALL indicate descending order

### Requirement: Chronological ordering of displayed messages
Displayed messages SHALL be ordered by message timestamp according to the selected sort order for the active view type. Ascending MUST place oldest messages first. Descending MUST place newest messages first.

#### Scenario: Descending order shows newest first
- **WHEN** sort order is descending
- **AND** multiple messages with different timestamps are displayed
- **THEN** the first visible message SHALL be the one with the newest timestamp

#### Scenario: Ascending order shows oldest first
- **WHEN** sort order is ascending
- **AND** multiple messages with different timestamps are displayed
- **THEN** the first visible message SHALL be the one with the oldest timestamp

### Requirement: Default sort order is descending
When no persisted sort-order preference exists for the active view type, the system SHALL use descending chronological order (newest first) as the default.

#### Scenario: First-time user sees newest messages first
- **WHEN** a user opens message results for a view type and no sort-order preference has been stored for that view type
- **THEN** the messages SHALL be displayed in descending chronological order
- **AND** the sort order control SHALL indicate descending order

### Requirement: Persist sort order preference per view type
The selected sort order SHALL be stored in user preferences scoped to the active view type (e.g. timeline, table, diff, schema) and restored when that view type is shown again in a later session. Changing the sort order for one view type MUST NOT change the stored sort order of other view types.

#### Scenario: Preference survives app restart for the same view type
- **WHEN** the user selects ascending sort order while in timeline view
- **AND** the application is restarted
- **AND** the user opens message results in timeline view again
- **THEN** the messages SHALL be displayed in ascending chronological order
- **AND** the sort order control SHALL indicate ascending order

#### Scenario: Preference update on toggle applies only to active view
- **WHEN** the user is in table view with descending sort order
- **AND** the user switches the sort order via the results toolbar control
- **THEN** the system SHALL persist the new sort order for table view only
- **AND** other view types SHALL retain their previously stored sort orders

#### Scenario: Switching view type restores that view's sort order
- **WHEN** timeline view is set to ascending and table view is set to descending
- **AND** the user switches from timeline to table view
- **THEN** the messages SHALL be displayed in descending chronological order
- **AND** the sort order control SHALL indicate descending order
