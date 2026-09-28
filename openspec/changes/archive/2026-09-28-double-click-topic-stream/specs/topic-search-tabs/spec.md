## ADDED Requirements

### Requirement: Quick Stream Topic on Double-Click

The Explorer view SHALL allow users to double-click on any topic in the sidebar topic list to open or focus the corresponding topic tab and immediately initiate message streaming with default search settings.

#### Scenario: Double-clicking an unopened topic in the topic list

- **WHEN** the user double-clicks on a topic in the sidebar topic list that does not have an open tab
- **THEN** the system SHALL open a new search tab for that topic and activate it
- **AND** the system SHALL immediately start message streaming for that topic using default search settings (Latest start strategy, Latest end strategy, result limit of 200 messages, FilterType.contains, SearchScope.both, and no filter terms)

#### Scenario: Double-clicking an already open topic in the topic list

- **WHEN** the user double-clicks on a topic in the sidebar topic list that already has an open tab
- **THEN** the system SHALL activate and focus the existing open tab for that topic
- **AND** the system SHALL immediately start message streaming for that topic using default search settings (loading the latest 200 messages)
- **AND** any previously buffered messages in that tab SHALL be cleared as streaming restarts

#### Scenario: Double-clicking while a stream is currently active on that topic

- **WHEN** the user double-clicks on a topic whose tab is already actively streaming messages
- **THEN** the system SHALL stop the ongoing stream and restart message streaming with the default configuration
