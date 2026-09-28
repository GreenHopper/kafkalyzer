## Purpose

Extends the embedded message inspector with a streaming stepper toolbar, full keyboard navigation (`J`/`K`, `ArrowUp`/`ArrowDown`, `Esc`, `Ctrl+F`), a 100% maximized Focus Mode for laptop displays, and in-inspector search with match counting and forward/backward match jumping.

## ADDED Requirements

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

## MODIFIED Requirements

### Requirement: Ergonomic Docking Positions
The inspector panel SHALL support two docking layouts: bottom-docking (horizontal split) and side-docking (vertical split), as well as a maximized Focus Mode. The user SHALL be able to switch between docking positions and maximize via controls in the inspector header.

#### Scenario: Docking position persistence
- **WHEN** the user toggles between bottom and side docking
- **THEN** the choice SHALL be persisted in `SharedPreferences`
- **AND** maximizing to Focus Mode SHALL NOT overwrite the underlying split dock preference
