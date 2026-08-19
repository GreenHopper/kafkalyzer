# topic-search-tabs Specification

## Purpose

Enables users to open, manage, and run multiple independent search and inspection sessions for the same Kafka topic concurrently within the Explorer view.

## ADDED Requirements

### Requirement: Opening Multiple Search Tabs for the Same Topic

The Explorer view SHALL allow users to open multiple concurrent, independent tab sessions for the same topic on the same cluster.

#### Scenario: Opening initial topic tab

- **WHEN** the user selects a topic from the sidebar topic list that has no open tabs
- **THEN** the system SHALL open a new search tab for that topic and activate it

#### Scenario: Opening an additional search tab for an already open topic

- **WHEN** the user requests to open a new tab for a topic that is already open (e.g. via an "Open in New Tab" context action on the topic or a "Duplicate / New Tab" action)
- **THEN** the system SHALL create a new distinct tab session for the topic on that cluster without modifying or clearing existing open tabs for that topic
- **AND** the system SHALL switch active focus to the newly created tab session

### Requirement: Independent Tab State and Search Execution

Each open topic tab session SHALL maintain an independent lifecycle, including its own search filter criteria, start and end conditions, partition filters, result limits, and streaming message buffer.

#### Scenario: Running concurrent searches with different filters

- **WHEN** the user configures and runs a search with specific filters in one tab
- **AND** configures and runs a search with different filters or offset conditions in another tab for the same topic
- **THEN** each tab SHALL execute its search independently and display only its own matching messages
- **AND** streaming progress, pauses, and cancellations in one tab SHALL NOT affect the execution state or message buffer of any other tab

#### Scenario: Clearing search results in a single tab

- **WHEN** the user clears results or resets the search configuration in an active tab
- **THEN** only that specific tab session SHALL be cleared
- **AND** all other tabs for the same topic SHALL retain their results and state

### Requirement: Distinct Tab Identification in Tab Bar

The Explorer tab bar SHALL display all open tab sessions and visually distinguish between multiple tabs opened for the same topic on the same cluster.

#### Scenario: Displaying multiple tabs for the same topic

- **WHEN** two or more tabs are open for the same topic and cluster
- **THEN** the tab bar SHALL display each tab with its topic name, cluster name, and a distinct instance identifier (e.g. numbered index)
- **AND** each tab SHALL display its individual live streaming progress, status, and message count

#### Scenario: Switching between open tabs

- **WHEN** the user clicks on a tab in the tab bar
- **THEN** the Explorer view SHALL display that specific tab session's search view and results while preserving the state of all background tabs

### Requirement: Independent Tab Closure and Resource Cleanup

The system SHALL allow closing individual topic tab sessions independently, disposing only the closed tab's streaming resources while keeping other open tabs intact.

#### Scenario: Closing one of multiple tabs for the same topic

- **WHEN** the user clicks the close button on a tab that has sibling tabs open for the same topic
- **THEN** the system SHALL terminate that tab's streaming controller and remove only that tab from the tab bar
- **AND** remaining tabs for the same topic SHALL continue running and retain their state
- **AND** the system SHALL activate the next appropriate remaining tab

#### Scenario: Closing the last open tab

- **WHEN** the user closes the only remaining open tab in the Explorer view
- **THEN** the system SHALL dispose that tab's resources and display the empty "no topic selected" state
