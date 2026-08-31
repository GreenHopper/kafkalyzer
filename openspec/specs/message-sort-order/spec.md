# message-sort-order Specification

## Purpose

Lets users choose and persist chronological ascending or descending order for Kafka messages shown in the shared results UI, per view type, defaulting to newest-first.

## Requirements

### Requirement: Sort order control in results toolbar
The message results toolbar SHALL include a control that displays the current ascending or descending sort order for the active view type and allows the user to switch between the two orders. The direction applies to the currently selected sort field.

#### Scenario: Toggle from descending to ascending
- **WHEN** the message results are shown with descending sort order
- **AND** the user activates the sort order control
- **THEN** the system SHALL switch to ascending order for the selected sort field
- **AND** the control SHALL indicate ascending order

#### Scenario: Toggle from ascending to descending
- **WHEN** the message results are shown with ascending sort order
- **AND** the user activates the sort order control
- **THEN** the system SHALL switch to descending order for the selected sort field
- **AND** the control SHALL indicate descending order

### Requirement: Ordering of displayed messages by selected field
Displayed messages SHALL be ordered by the selected sort field according to the selected ascending or descending order. Supported fields are timestamp, partition, offset, key, and value (payload). Ascending MUST place smaller/earlier values first. Descending MUST place larger/later values first. Null or missing key/value fields MUST sort consistently (treated as empty for comparison).

#### Scenario: Descending order shows newest first
- **WHEN** sort field is timestamp and sort order is descending
- **AND** multiple messages with different timestamps are displayed
- **THEN** the first visible message SHALL be the one with the newest timestamp

#### Scenario: Ascending order shows oldest first
- **WHEN** sort field is timestamp and sort order is ascending
- **AND** multiple messages with different timestamps are displayed
- **THEN** the first visible message SHALL be the one with the oldest timestamp

#### Scenario: Ascending offset shows lowest offset first
- **WHEN** sort field is offset and sort order is ascending
- **AND** multiple messages with different offsets are displayed
- **THEN** the first visible message SHALL be the one with the lowest offset

#### Scenario: Descending key sorts keys reverse lexicographically
- **WHEN** sort field is key and sort order is descending
- **AND** multiple messages with different keys are displayed
- **THEN** the first visible message SHALL be the one whose key is last in lexicographic order among those keys

### Requirement: Default sort order is descending
When no persisted sort-order (direction) preference exists for the active view type, the system SHALL use descending order as the default for the selected sort field.

#### Scenario: First-time user sees newest messages first
- **WHEN** a user opens message results for a view type and no sort-order preference has been stored for that view type
- **AND** the active sort field is timestamp (the default field)
- **THEN** the messages SHALL be displayed in descending chronological order
- **AND** the sort order control SHALL indicate descending order

#### Scenario: First-time user sees descending order for non-timestamp field
- **WHEN** a user opens message results for a view type with no sort-order preference stored
- **AND** the active sort field is not timestamp
- **THEN** the messages SHALL be displayed in descending order for that field
- **AND** the sort order control SHALL indicate descending order

### Requirement: Persist sort order preference per view type
The selected sort order (ascending or descending) SHALL be stored in user preferences scoped to the active view type (e.g. timeline, table, diff, schema) and restored when that view type is shown again in a later session. Changing the sort order for one view type MUST NOT change the stored sort order of other view types.

#### Scenario: Preference survives app restart for the same view type
- **WHEN** the user selects ascending sort order while in timeline view
- **AND** the application is restarted
- **AND** the user opens message results in timeline view again
- **THEN** the messages SHALL be displayed in ascending order for that view's sort field
- **AND** the sort order control SHALL indicate ascending order

#### Scenario: Preference update on toggle applies only to active view
- **WHEN** the user is in table view with descending sort order
- **AND** the user switches the sort order via the results toolbar control
- **THEN** the system SHALL persist the new sort order for table view only
- **AND** other view types SHALL retain their previously stored sort orders

#### Scenario: Switching view type restores that view's sort order
- **WHEN** timeline view is set to ascending and table view is set to descending
- **AND** the user switches from timeline to table view
- **THEN** the messages SHALL be displayed in descending order for table view's sort field
- **AND** the sort order control SHALL indicate descending order

### Requirement: Sort field selection in results toolbar
The message results toolbar SHALL include a control that displays the current sort field and allows the user to select among timestamp, partition, offset, key, and value (message payload).

#### Scenario: Select partition as sort field
- **WHEN** the user opens the sort field control
- **AND** chooses partition
- **THEN** the system SHALL sort displayed messages by partition according to the active ascending/descending order
- **AND** the control SHALL indicate partition as the selected field

#### Scenario: Select value as sort field
- **WHEN** the user selects value as the sort field
- **THEN** the system SHALL sort displayed messages by payload string according to the active ascending/descending order

### Requirement: Default sort field is timestamp
When no persisted sort-field preference exists for the active view type, the system SHALL use timestamp as the sort field.

#### Scenario: First-time user sorts by timestamp
- **WHEN** a user opens message results for a view type and no sort-field preference has been stored for that view type
- **THEN** the messages SHALL be sorted by timestamp
- **AND** the sort field control SHALL indicate timestamp

### Requirement: Persist sort field preference per view type
The selected sort field SHALL be stored in user preferences scoped to the active view type and restored when that view type is shown again. Changing the sort field for one view type MUST NOT change the stored sort field of other view types.

#### Scenario: Field preference survives app restart for the same view type
- **WHEN** the user selects offset as the sort field while in timeline view
- **AND** the application is restarted
- **AND** the user opens message results in timeline view again
- **THEN** the messages SHALL be sorted by offset
- **AND** the sort field control SHALL indicate offset

#### Scenario: Switching view type restores that view's sort field
- **WHEN** timeline view is set to sort by key and table view is set to sort by timestamp
- **AND** the user switches from timeline to table view
- **THEN** the messages SHALL be sorted by timestamp
- **AND** the sort field control SHALL indicate timestamp

### Requirement: Sort controls precede view mode controls
In the message results toolbar, the sort field control and the ascending/descending sort order control SHALL appear before the message view-type controls (table, timeline, diff, and schema when available).

#### Scenario: Toolbar order places sorting before view type
- **WHEN** the message results toolbar is shown
- **THEN** the sort field control and sort order control SHALL be positioned before the view-type switcher
