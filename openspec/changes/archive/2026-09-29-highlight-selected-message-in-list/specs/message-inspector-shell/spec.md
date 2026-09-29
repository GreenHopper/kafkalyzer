## MODIFIED Requirements

### Requirement: Master Stream Selection Highlighting
When a message is selected and being inspected, the corresponding row in the table view or card in the timeline or diff view SHALL be prominently and visibly highlighted to maintain clear context, and the view SHALL automatically scroll to keep the active message within the visible viewport.

#### Scenario: Table row active highlight
- **WHEN** a message is currently selected in the inspector
- **THEN** the corresponding row in `MessagesTableView` SHALL display a prominent, high-contrast active selection background tint
- **AND** each cell in the row SHALL display a distinct selection outline or border that remains identifiable across light and dark themes

#### Scenario: Table auto-scroll on selection or stepping
- **WHEN** a message is selected or navigated to via stepper controls or keyboard shortcuts
- **AND** the message row is partially or entirely outside the visible viewport of `MessagesTableView`
- **THEN** `MessagesTableView` SHALL automatically scroll its vertical viewport to bring the selected message row into view

#### Scenario: Horizontal scroll resilience of table selection
- **WHEN** `MessagesTableView` is scrolled horizontally so that the first column is scrolled out of view
- **AND** a message row is selected
- **THEN** the visible cells in that row SHALL clearly indicate active selection via background coloring and row borders

#### Scenario: Timeline card active highlight and auto-scroll
- **WHEN** a message is selected while in timeline view
- **THEN** `MessagesTimelineView` SHALL render the active card with an elevated, highlighted border and selection background
- **AND** the view SHALL automatically scroll to make the selected timeline card visible

#### Scenario: Diff view active highlight and auto-scroll
- **WHEN** a message is selected while in diff view
- **THEN** `MessagesDiffView` SHALL render the active diff card with a highlighted selection outline
- **AND** the view SHALL automatically scroll to make the active diff card visible

#### Scenario: Selecting a different message updates the inspector
- **WHEN** the inspector is open for message A
- **AND** the user selects message B in the master stream
- **THEN** message B SHALL become the actively highlighted message
- **AND** the inspector panel SHALL immediately update its contents to reflect message B

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

#### Scenario: Boundary states disabled
- **WHEN** the selected message is the first message (`index == 0`)
- **THEN** the previous message control SHALL be disabled
- **WHEN** the selected message is the last message (`index == N - 1`)
- **THEN** the next message control SHALL be disabled

#### Scenario: Position badge display
- **WHEN** an inspector panel is displayed for a message at index `i` of `N` total messages
- **THEN** the stepper SHALL display a badge or text indicating `${i + 1} of ${N}`
