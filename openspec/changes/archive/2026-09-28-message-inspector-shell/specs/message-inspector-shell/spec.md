## Purpose

Provides an integrated, dockable split-screen inspector within the Kafka message view that replaces modal dialogs, allows seamless sequential message inspection in place, and preserves complete message context including payload, key, headers, and metadata across bottom and side docking layouts.

## ADDED Requirements

### Requirement: Embedded Dockable Split-Screen Inspector
The message results view (`MessagesView`) SHALL embed an inspector panel that displays the details of the selected Kafka message without opening a modal dialog.

#### Scenario: Inspect message on selection
- **WHEN** a user taps or selects a Kafka message in the table or timeline view
- **THEN** the system SHALL open the inspector panel embedded within the current view
- **AND** the master message stream SHALL remain visible and interactive
- **AND** the inspector panel SHALL display the details of the selected message

#### Scenario: Close inspector restores full master view
- **WHEN** the inspector panel is open
- **AND** the user activates the close control in the inspector header
- **THEN** the system SHALL close the inspector panel
- **AND** the master message stream SHALL expand to occupy the entire results area

### Requirement: Ergonomic Docking Positions
The inspector panel SHALL support two docking layouts: bottom-docking (horizontal split) and side-docking (vertical split). The user SHALL be able to switch between docking positions via a dedicated toggle in the inspector header.

#### Scenario: Default docking on laptops
- **WHEN** the inspector panel is opened and no docking preference has been set
- **THEN** the inspector SHALL dock to the bottom of the message stream
- **AND** the master stream above SHALL maintain its full horizontal width

#### Scenario: Switch from bottom to side docking
- **WHEN** the inspector panel is docked at the bottom
- **AND** the user activates the dock-position toggle
- **THEN** the inspector SHALL switch to side-docking on the right-hand side of the stream
- **AND** the system SHALL persist the chosen docking position

#### Scenario: Switch from side to bottom docking
- **WHEN** the inspector panel is docked on the side
- **AND** the user activates the dock-position toggle
- **THEN** the inspector SHALL switch to bottom-docking below the stream
- **AND** the system SHALL persist the chosen docking position

### Requirement: Kafka Metadata and Context Header
The inspector panel header SHALL display essential Kafka message metadata, including partition, offset, formatted timestamp with millisecond precision, and message key summary, each equipped with copy affordances.

#### Scenario: Display and copy metadata in inspector
- **WHEN** a message is inspected in the inspector panel
- **THEN** the header SHALL display the message partition number, offset, and formatted timestamp
- **AND** activating the copy action for metadata SHALL copy the partition, offset, and timestamp text to the clipboard

### Requirement: Structured Multi-Tab Inspection
The inspector panel SHALL organize detailed message contents into tabs:
1. `Payload`: displays the message payload with search, formatting, and copy controls.
2. `Key & Headers`: displays the full message key and a structured list of all Kafka headers with an item count badge.
3. `Raw JSON`: displays the serialized representation of the complete message for export.

#### Scenario: Inspect Kafka headers in dedicated tab
- **WHEN** the user selects the `Key & Headers` tab for a message containing 3 headers
- **THEN** the tab label SHALL display a badge with the count `3`
- **AND** the panel body SHALL list all 3 headers with their keys and decoded values
- **AND** each header SHALL provide a copy button for its value

#### Scenario: Inspect and copy raw message JSON
- **WHEN** the user selects the `Raw JSON` tab
- **THEN** the panel SHALL display the full message structure (topic, partition, offset, timestamp, key, payload, headers) in indented JSON
- **AND** the user SHALL be able to copy the entire JSON to the clipboard

### Requirement: Master Stream Selection Highlighting
When a message is selected and being inspected, the corresponding row in the table view or card in the timeline view SHALL be visually highlighted to maintain context.

#### Scenario: Table row active highlight
- **WHEN** a message is currently selected in the inspector
- **THEN** the corresponding row in `MessagesTableView` SHALL display an active selection background color

#### Scenario: Selecting a different message updates the inspector
- **WHEN** the inspector is open for message A
- **AND** the user selects message B in the master stream
- **THEN** message B SHALL become the actively highlighted message
- **AND** the inspector panel SHALL immediately update its contents to reflect message B

### Requirement: Default Viewer Mode Performance
When viewing JSON payloads in `JsonOrStringViewer`, the system SHALL default to Tree mode (`_viewMode = 1`) rather than Cards mode (`_viewMode = 2`) to ensure responsive UI performance on complex payloads.

#### Scenario: Initial view mode for valid JSON
- **WHEN** a message containing valid JSON is rendered in `JsonOrStringViewer` without a previously saved preference
- **THEN** the viewer SHALL display the Tree view
- **AND** the viewer SHALL NOT default to the unvirtualized Cards view
