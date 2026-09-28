# message-inspector-shell Specification

## Purpose

Provides an integrated, dockable split-screen inspector within the Kafka message view that replaces modal dialogs, allows seamless sequential message inspection in place, provides a streaming stepper toolbar with keyboard shortcuts, in-inspector search, and a maximized Focus Mode, while preserving complete message context across bottom and side docking layouts.

## Requirements

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
The inspector panel SHALL support two docking layouts: bottom-docking (horizontal split) and side-docking (vertical split), as well as a maximized Focus Mode. The user SHALL be able to switch between docking positions and maximize via controls in the inspector header.

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

#### Scenario: Docking position persistence
- **WHEN** the user toggles between bottom and side docking
- **THEN** the choice SHALL be persisted in `SharedPreferences`
- **AND** maximizing to Focus Mode SHALL NOT overwrite the underlying split dock preference

### Requirement: Kafka Metadata and Context Header
The inspector panel header SHALL display essential Kafka message metadata, including partition, offset, formatted timestamp with millisecond precision, and message key summary, each equipped with copy affordances.

#### Scenario: Display and copy metadata in inspector
- **WHEN** a message is inspected in the inspector panel
- **THEN** the header SHALL display the message partition number, offset, and formatted timestamp
- **AND** activating the copy action for metadata SHALL copy the partition, offset, and timestamp text to the clipboard

### Requirement: Structured Multi-Tab Inspection
The inspector panel SHALL organize detailed message contents into tabs:
1. `Payload`: displays the message payload using `SmartVirtualJsonTree` with progressive disclosure smart badges, in-tree search, formatting, and copy controls.
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
When viewing JSON payloads in `JsonOrStringViewer` within the inspector, the system SHALL render the payload using the virtualized `SmartVirtualJsonTree` by default, and SHALL NOT display or support the deprecated unvirtualized Cards view mode.

#### Scenario: Initial view mode for valid JSON
- **WHEN** a message containing valid JSON is rendered in `JsonOrStringViewer` without a previously saved preference
- **THEN** the viewer SHALL display the `SmartVirtualJsonTree` view
- **AND** the viewer SHALL NOT provide an option to switch to an unvirtualized Cards view

### Requirement: Sequential Message Stepper
The inspector panel SHALL provide sequential navigation controls (stepper) that allow the user to step to the previous or next message within the currently active filtered and sorted stream.

#### Scenario: Step to next message
- **WHEN** a message at index `i` is selected in a stream of `N` messages where `i < N - 1`
- **AND** the user activates the next message action (button or keyboard shortcut)
- **THEN** the system SHALL select message `i + 1`
- **AND** the inspector panel SHALL update immediately to display message `i + 1`
- **AND** the master view SHALL update its active row selection highlight

#### Scenario: Step to previous message
- **WHEN** a message at index `i` is selected where `i > 0`
- **AND** the user activates the previous message action (button or keyboard shortcut)
- **THEN** the system SHALL select message `i - 1`
- **AND** the inspector panel SHALL update immediately to display message `i - 1`
- **AND** the master view SHALL update its active row selection highlight

#### Scenario: Boundary states disabled
- **WHEN** the selected message is the first message (`index == 0`)
- **THEN** the previous message control SHALL be disabled
- **WHEN** the selected message is the last message (`index == N - 1`)
- **THEN** the next message control SHALL be disabled

#### Scenario: Position badge display
- **WHEN** an inspector panel is displayed for a message at index `i` of `N` total messages
- **THEN** the stepper SHALL display a badge or text indicating `${i + 1} of ${N}`

### Requirement: Global Keyboard Shortcuts for Stream Inspection
The message view SHALL support single-key and modifier keyboard shortcuts for rapid navigation and control.

#### Scenario: Navigation shortcuts
- **WHEN** an inspector panel is open and no text input field currently has keyboard focus
- **AND** the user presses `J` or `ArrowDown`
- **THEN** the system SHALL step to the next message
- **WHEN** the user presses `K` or `ArrowUp`
- **THEN** the system SHALL step to the previous message

#### Scenario: Dismissal and exit shortcuts
- **WHEN** the inspector is open and maximized (Focus Mode)
- **AND** the user presses `Escape`
- **THEN** the system SHALL exit maximized mode and restore the split layout
- **WHEN** the inspector is in a standard split layout (not maximized)
- **AND** the user presses `Escape`
- **THEN** the system SHALL close the inspector panel

#### Scenario: Text field isolation
- **WHEN** the user is typing into any text field (such as the stream search bar or inspector search bar)
- **THEN** pressing `J` or `K` SHALL insert those characters into the text field and SHALL NOT trigger message stepping

### Requirement: Maximized Focus Mode
The inspector panel SHALL support a maximized Focus Mode that occupies 100% of the message results viewport, providing maximum screen space on compact laptop displays while retaining full streaming stepper capabilities.

#### Scenario: Toggle Focus Mode
- **WHEN** the inspector is in split layout
- **AND** the user clicks the maximize button or presses `F`
- **THEN** the inspector SHALL expand to occupy 100% of the results view area
- **AND** the master view below/beside it SHALL be temporarily hidden from the layout
- **AND** the stepper toolbar SHALL remain visible and functional in the header

#### Scenario: Minimize Focus Mode
- **WHEN** the inspector is maximized
- **AND** the user clicks the minimize button or presses `Escape`
- **THEN** the inspector SHALL return to its previous dock position (bottom or side)
- **AND** the master stream view SHALL be restored

### Requirement: In-Inspector Value Search and Match Stepping
The inspector SHALL provide an in-inspector search interface allowing users to query strings within the active message payload and key, displaying match counts and enabling incremental jumping between matches.

#### Scenario: Search and match counting
- **WHEN** the user enters a search phrase into the in-inspector search field
- **THEN** the viewer SHALL highlight all occurrences of the phrase
- **AND** the search bar SHALL display the total number of matches found and the current match index (e.g. `1 / 5`)

#### Scenario: Jump between matches
- **WHEN** multiple matches exist for the current search phrase
- **AND** the user presses `Enter` or clicks the next match button
- **THEN** the viewer SHALL scroll and focus to the next matching node/text
- **WHEN** the user presses `Shift+Enter` or clicks the previous match button
- **THEN** the viewer SHALL scroll and focus to the previous matching node/text
