## MODIFIED Requirements

### Requirement: Kafka Metadata and Context Header
The inspector panel header SHALL display essential Kafka message metadata, including partition, offset, formatted timestamp with millisecond precision, and message key summary, each equipped with copy affordances. The key summary SHALL distinguish a `null` key ("no key") from an empty key ("empty"), and a tombstone message SHALL be marked as tombstone in the header and in the Payload tab.

#### Scenario: Display and copy metadata in inspector
- **WHEN** a message is inspected in the inspector panel
- **THEN** the header SHALL display the message partition number, offset, and formatted timestamp
- **AND** activating the copy action for metadata SHALL copy the partition, offset, and timestamp text to the clipboard
- **AND** the copied timestamp SHALL be ISO-8601 with milliseconds and zone, not a locale-formatted date

#### Scenario: Null key and empty key in the header
- **WHEN** the inspected message has a `null` key
- **THEN** the key summary SHALL show a localized "no key" marker
- **WHEN** the inspected message has an empty-string key
- **THEN** the key summary SHALL show a localized "empty" marker that differs from the "no key" marker

#### Scenario: Tombstone in the inspector
- **WHEN** the inspected message has a `null` value
- **THEN** the header SHALL show a tombstone marker
- **AND** the Payload tab SHALL show a tombstone notice instead of an empty viewer

### Requirement: Global Keyboard Shortcuts for Stream Inspection
The message view SHALL support single-key and modifier keyboard shortcuts for rapid navigation and control, with or without an open inspector. Shortcuts SHALL act only on the result view that is currently visible, and every control with a shortcut SHALL name it in its tooltip.

#### Scenario: Navigation shortcuts
- **WHEN** an inspector panel is open and no text input field has keyboard focus
- **AND** the user presses `J` or `ArrowDown`
- **THEN** the system SHALL step to the next message
- **WHEN** the user presses `K` or `ArrowUp`
- **THEN** the system SHALL step to the previous message
- **AND** these shortcuts SHALL work even when keyboard focus is outside the messages view (for example on the explorer topic list) or on non-text chrome such as search-bar icon buttons

#### Scenario: Navigation without open inspector
- **WHEN** the inspector is closed, keyboard focus is inside the result view and no text input field has focus
- **AND** the user presses `ArrowDown`, `ArrowUp`, `J` or `K`
- **THEN** the selection SHALL move to the next or previous message in the displayed order without opening the inspector
- **AND** the selected row SHALL be scrolled into view
- **WHEN** the user presses `Enter`
- **THEN** the inspector SHALL open for the selected message

#### Scenario: Jump and page shortcuts
- **WHEN** keyboard focus is inside the result view or the inspector is open, and no text input field has focus
- **AND** the user presses `Home` or `End`
- **THEN** the first or last message in the displayed order SHALL be selected and scrolled into view
- **WHEN** the user presses `PageDown` or `PageUp`
- **THEN** the selection SHALL move forward or back by one page of visible rows, clamped to the first and last message

#### Scenario: Focus the quick filter
- **WHEN** the result view is visible and the user presses `Ctrl`+`F` (`Cmd`+`F` on macOS)
- **THEN** the in-memory quick filter field SHALL receive keyboard focus with its text selected

#### Scenario: Copy the selection
- **WHEN** one or more messages are selected and no text input or selectable text has focus
- **AND** the user presses `Ctrl`+`C` (`Cmd`+`C` on macOS)
- **THEN** the selected message SHALL be copied in the message JSON format, or a JSON array in displayed order when several are selected
- **WHEN** a text input or selectable text has focus
- **THEN** `Ctrl`+`C` SHALL keep its normal text copy behaviour

#### Scenario: Shortcuts act only in the visible view
- **WHEN** several topic tabs are open and each has an open inspector
- **AND** the user presses `J`
- **THEN** only the message view of the visible tab SHALL step to the next message

#### Scenario: Shortcuts named in tooltips
- **WHEN** the user hovers the quick filter field, the previous or next message button, the maximize button, the close button or the copy-message button
- **THEN** the tooltip SHALL name the keyboard shortcut of that action in the platform's notation

#### Scenario: Dismissal and exit shortcuts
- **WHEN** the inspector is open and maximized (Focus Mode)
- **AND** the user presses `Escape` while no text input field has focus
- **THEN** the system SHALL exit maximized mode and restore the split layout
- **WHEN** the inspector is in a standard split layout (not maximized)
- **AND** the user presses `Escape` while no text input field has focus
- **THEN** the system SHALL close the inspector panel
- **WHEN** the inspector is closed and several messages are selected
- **AND** the user presses `Escape` while no text input field has focus
- **THEN** the selection SHALL be reduced to the most recently clicked message

#### Scenario: Text field isolation
- **WHEN** the user has keyboard focus within any text input field across the application (including sidebar topic filter, message search bar, in-inspector search bar, and table column filter inputs)
- **THEN** pressing `J`, `K`, or `F` (or their uppercase equivalents) SHALL insert those characters into the focused text field without being intercepted or swallowed
- **AND** pressing `J`, `K`, or `F` SHALL NOT trigger message stepping or toggle Focus Mode
- **AND** pressing `Escape` SHALL unfocus the active text input field without closing the inspector or exiting Focus Mode on that press
- **AND** pressing `ArrowUp` or `ArrowDown` SHALL still step messages
- **AND** pressing `Home`, `End`, `PageUp` or `PageDown` SHALL keep their text editing behaviour
