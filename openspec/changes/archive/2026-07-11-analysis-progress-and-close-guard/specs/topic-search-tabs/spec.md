# topic-search-tabs Delta

## MODIFIED Requirements

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
