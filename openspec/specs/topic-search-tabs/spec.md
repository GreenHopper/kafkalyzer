# topic-search-tabs Specification

## Purpose

Enables users to open, manage, and run multiple independent search and inspection sessions for the same Kafka topic concurrently within the Explorer view.

## Requirements

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

#### Scenario: Tab bar progress indicator during active search

- **WHEN** a search stream is actively running in a tab
- **THEN** the tab bar SHALL display a linear progress indicator showing the scan progress ratio and a remaining time estimate alongside the tab title

#### Scenario: Tab bar progress indicator during active analysis

- **WHEN** a topic analysis scan is actively running in a tab
- **THEN** the tab bar SHALL display a linear progress indicator showing the analysis progress ratio and a remaining time estimate alongside the tab title
- **AND** the progress indicator SHALL use the same visual style and layout as the search streaming progress indicator

### Requirement: Independent Tab Closure and Resource Cleanup

The system SHALL allow closing individual topic tab sessions independently, disposing only the closed tab's streaming and analysis resources while keeping other open tabs intact. When a tab has an active search stream or an active analysis scan, the system SHALL require explicit user confirmation before closing.

#### Scenario: Closing a tab with no active operations

- **WHEN** the user clicks the close button on a tab that has no active search stream and no active analysis scan
- **THEN** the system SHALL close the tab immediately without showing a confirmation dialog
- **AND** the system SHALL terminate that tab's streaming and analysis controllers and remove the tab from the tab bar

#### Scenario: Closing a tab with an active search or analysis

- **WHEN** the user clicks the close button on a tab that has an active search stream or an active analysis scan
- **THEN** the system SHALL display an alert dialog informing the user that a search or analysis is still running
- **AND** the dialog SHALL offer the user the choice to confirm closing (which cancels the operation and closes the tab) or to cancel the close action (which keeps the tab open and the operation running)
- **AND** if the user confirms, the system SHALL stop the running operation, dispose the tab's controllers, and remove the tab from the tab bar
- **AND** if the user cancels, the tab SHALL remain open and the operation SHALL continue running

#### Scenario: Closing one of multiple tabs for the same topic

- **WHEN** the user clicks the close button on a tab that has sibling tabs open for the same topic and confirms closure
- **THEN** the system SHALL terminate that tab's streaming controller and remove only that tab from the tab bar
- **AND** remaining tabs for the same topic SHALL continue running and retain their state
- **AND** the system SHALL activate the next appropriate remaining tab

#### Scenario: Closing the last open tab

- **WHEN** the user closes the only remaining open tab in the Explorer view (with confirmation if an operation is running)
- **THEN** the system SHALL dispose that tab's resources and display the empty "no topic selected" state

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

