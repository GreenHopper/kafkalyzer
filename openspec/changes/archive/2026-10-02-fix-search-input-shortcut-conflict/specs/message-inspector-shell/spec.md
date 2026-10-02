# Spec Delta

## MODIFIED Requirements

### Requirement: Global Keyboard Shortcuts for Stream Inspection
The message view SHALL support single-key and modifier keyboard shortcuts for rapid navigation and control.

#### Scenario: Navigation shortcuts
- **WHEN** an inspector panel is open and no text input field has keyboard focus
- **AND** the user presses `J` or `ArrowDown`
- **THEN** the system SHALL step to the next message
- **WHEN** the user presses `K` or `ArrowUp`
- **THEN** the system SHALL step to the previous message
- **AND** these shortcuts SHALL work even when keyboard focus is outside the messages view (for example on the explorer topic list) or on non-text chrome such as search-bar icon buttons

#### Scenario: Dismissal and exit shortcuts
- **WHEN** the inspector is open and maximized (Focus Mode)
- **AND** the user presses `Escape` while no text input field has focus
- **THEN** the system SHALL exit maximized mode and restore the split layout
- **WHEN** the inspector is in a standard split layout (not maximized)
- **AND** the user presses `Escape` while no text input field has focus
- **THEN** the system SHALL close the inspector panel

#### Scenario: Text field isolation
- **WHEN** the user has keyboard focus within any text input field across the application (including sidebar topic filter, message search bar, in-inspector search bar, and table column filter inputs)
- **THEN** pressing `J`, `K`, or `F` (or their uppercase equivalents) SHALL insert those characters into the focused text field without being intercepted or swallowed
- **AND** pressing `J`, `K`, or `F` SHALL NOT trigger message stepping or toggle Focus Mode
- **AND** pressing `Escape` SHALL unfocus the active text input field without closing the inspector or exiting Focus Mode on that press
- **AND** pressing `ArrowUp` or `ArrowDown` SHALL still step messages
