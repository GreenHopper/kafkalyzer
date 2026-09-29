## MODIFIED Requirements

### Requirement: Embedded Dockable Split-Screen Inspector
The message results view (`MessagesView`) SHALL embed an inspector panel that displays the details of the selected Kafka message without opening a modal dialog across all Kafka message investigation contexts, including Topic Explorer and Script Run Details. The system SHALL use `MessageInspectorPanel` for all Kafka message inspection, retiring `MessageDetailsDialog`.

#### Scenario: Inspect message on selection
- **WHEN** a user taps or selects a Kafka message in the table or timeline view
- **THEN** the system SHALL open the inspector panel embedded within the current view
- **AND** the master message stream SHALL remain visible and interactive
- **AND** the inspector panel SHALL display the details of the selected message

#### Scenario: Inspect message during script run execution results
- **WHEN** a user taps or selects a Kafka message in the script execution results view (`ScriptRunDetailsView`) in table, timeline, or diff view
- **THEN** the system SHALL open the embedded dockable inspector panel within the view without opening a modal dialog
- **AND** the script run sidebar and master message results SHALL remain visible and interactive
- **AND** the inspector panel SHALL display the details of the selected script message

#### Scenario: Single-message inspection uses MessageInspectorPanel
- **WHEN** a user requests inspection of a single Kafka message outside a full message stream (such as viewing a lagging message from consumer partition lag)
- **THEN** the system SHALL render `MessageInspectorPanel` without relying on legacy `MessageDetailsDialog`

#### Scenario: Close inspector restores full master view
- **WHEN** the inspector panel is open
- **AND** the user activates the close control in the inspector header
- **THEN** the system SHALL close the inspector panel
- **AND** the master message stream SHALL expand to occupy the entire results area

### Requirement: Sequential Message Stepper
The inspector panel SHALL provide sequential navigation controls (stepper) that allow the user to step to the previous or next message within the currently active filtered and sorted stream, keeping the selection synchronized and visible in the master view.

#### Scenario: Step to next message
- **WHEN** a message at index `i` is selected in a stream of `N` messages where `i < N - 1`
- **AND** the user activates the next message action (button or keyboard shortcut)
- **THEN** the system SHALL select message `i + 1` in the visual sort order of the current active view
- **AND** the inspector panel SHALL update immediately to display message `i + 1`
- **AND** the master view SHALL update its active row selection highlight
- **AND** the master view SHALL automatically scroll to ensure the newly selected message is within the visible viewport

#### Scenario: Step to previous message
- **WHEN** a message at index `i` is selected where `i > 0`
- **AND** the user activates the previous message action (button or keyboard shortcut)
- **THEN** the system SHALL select message `i - 1` in the visual sort order of the current active view
- **AND** the inspector panel SHALL update immediately to display message `i - 1`
- **AND** the master view SHALL update its active row selection highlight
- **AND** the master view SHALL automatically scroll to ensure the newly selected message is within the visible viewport

#### Scenario: Stepping follows active table sort order
- **WHEN** the user sorts `MessagesTableView` by a specific column
- **AND** the user steps to the next or previous message using stepper controls or keyboard shortcuts
- **THEN** the sequential navigation SHALL step according to the displayed table sort order rather than the default insertion order

#### Scenario: Stepping through script execution results
- **WHEN** inspecting a message in the script execution results view (`ScriptRunDetailsView`)
- **AND** the user activates sequential message stepping via stepper buttons or keyboard shortcuts (`J`/`K`/arrows)
- **THEN** the system SHALL step sequentially through the active filtered script results
- **AND** the active item in table, timeline, or diff view SHALL update its selection highlight and scroll into view

#### Scenario: Boundary states disabled
- **WHEN** the selected message is the first message (`index == 0`)
- **THEN** the previous message control SHALL be disabled
- **WHEN** the selected message is the last message (`index == N - 1`)
- **THEN** the next message control SHALL be disabled

#### Scenario: Position badge display
- **WHEN** an inspector panel is displayed for a message at index `i` of `N` total messages
- **THEN** the stepper SHALL display a badge or text indicating `${i + 1} of ${N}`
