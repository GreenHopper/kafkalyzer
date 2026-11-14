# Spec Delta

## Purpose

Lets users select one or more loaded Kafka messages in the result views and take them out of kafkalyzer — as key,
value, JSON, coordinates or a consume-only kcat command — with `null`, empty and tombstone values kept apart, and
compare two selected messages directly.

## ADDED Requirements

### Requirement: Multi-Selection in the Message Table
The message table SHALL support selecting several loaded messages. A plain click SHALL select only the clicked row and open the inspector as before. `Ctrl`+click (`Cmd`+click on macOS) SHALL toggle the clicked row without opening a closed inspector. `Shift`+click SHALL select every row between the last clicked row and the clicked row in the displayed order.

#### Scenario: Toggle rows with Ctrl or Cmd
- **WHEN** row A is selected and the user `Ctrl`+clicks (macOS: `Cmd`+clicks) row B and then row C
- **THEN** rows A, B and C SHALL be selected
- **WHEN** the user `Ctrl`+clicks row B again
- **THEN** only rows A and C SHALL remain selected

#### Scenario: Range selection follows the displayed order
- **WHEN** the table is sorted by a column, the user clicks the row at display position 2 and `Shift`+clicks the row at display position 6
- **THEN** exactly the five rows at display positions 2 to 6 SHALL be selected, regardless of their offsets or timestamps

#### Scenario: Plain click resets the selection
- **WHEN** several rows are selected and the user clicks another row without a modifier
- **THEN** only the clicked row SHALL be selected and the inspector SHALL show it

#### Scenario: Selection follows the quick filter
- **WHEN** selected messages no longer match the quick filter after the filter text changes
- **THEN** those messages SHALL be removed from the selection

### Requirement: Selection Feedback in the Results Toolbar
While more than one message is selected, the results toolbar SHALL show the number of selected messages and a "Clear selection" action. Every selected row SHALL show a selection background and border, and the message shown in the inspector SHALL keep its stronger active highlight, so selection is not conveyed by colour alone.

#### Scenario: Selected count is shown
- **WHEN** the user selects 3 rows
- **THEN** the toolbar SHALL state that 3 messages are selected
- **AND** activating "Clear selection" SHALL leave no row selected

#### Scenario: Single selection shows no counter
- **WHEN** exactly one row is selected
- **THEN** the toolbar SHALL NOT show the selection counter

### Requirement: Message Row Context Menu
A secondary click on a table row or timeline card SHALL open a context menu with: Copy key, Copy value, Copy message as JSON, Copy coordinates, Copy kcat command, Copy shareable link. Each copy SHALL write to the clipboard and confirm with a short localized notice; a failed clipboard write SHALL show an error notice.

#### Scenario: Context menu entries on a row
- **WHEN** the user right-clicks a table row or a timeline card
- **THEN** the menu SHALL offer the six copy entries for the message under the cursor

#### Scenario: Right-click outside the current selection
- **WHEN** rows A and B are selected and the user right-clicks row C
- **THEN** only row C SHALL be selected and the menu SHALL act on row C

#### Scenario: Copy coordinates
- **WHEN** the user chooses "Copy coordinates" on the message at offset 1042 of partition 3 of topic `orders`
- **THEN** the clipboard SHALL contain `orders/3/1042`

#### Scenario: Clipboard write fails
- **WHEN** the clipboard write is rejected by the platform
- **THEN** the app SHALL show an error notice and SHALL NOT show the success notice

### Requirement: Selection Actions in the Context Menu
When the user right-clicks a row that belongs to a selection of two or more messages, the context menu SHALL additionally offer "Copy selected messages as JSON" and, for exactly two selected messages, "Compare". The single-message entries SHALL act on the row under the cursor.

#### Scenario: Copy selected messages as JSON
- **WHEN** 4 rows are selected and the user chooses "Copy selected messages as JSON"
- **THEN** the clipboard SHALL contain a JSON array of the 4 messages in the displayed order, each in the message JSON format

#### Scenario: Compare entry only for two messages
- **WHEN** 3 rows are selected and the user right-clicks one of them
- **THEN** the "Compare" entry SHALL NOT be offered

### Requirement: Compare Two Selected Messages
With exactly two messages selected, a "Compare" action in the context menu and in the results toolbar SHALL open a comparison of the two messages. It SHALL show topic, partition, offset, timestamp and key of both messages, the older message by timestamp (then offset) on the left, and the payload differences. A tombstone side SHALL be marked as tombstone, not compared as an empty object.

#### Scenario: Compare two JSON messages
- **WHEN** two messages with JSON payloads are selected and the user activates "Compare"
- **THEN** a comparison SHALL open showing the field-level differences between the two payloads

#### Scenario: Compare non-JSON payloads
- **WHEN** at least one of the two payloads is not valid JSON
- **THEN** the comparison SHALL show a text difference of the two payloads

#### Scenario: Compare with a tombstone
- **WHEN** one of the two messages is a tombstone
- **THEN** that side SHALL be labelled as tombstone and no field-level difference SHALL be computed

#### Scenario: Diff computation fails
- **WHEN** computing the difference raises an error
- **THEN** the comparison SHALL show a localized error message instead of an empty result

### Requirement: Message JSON Copy Format
"Copy message as JSON" and every selection copy SHALL produce JSON with topic, partition, offset, epoch-millisecond timestamp, an ISO-8601 timestamp with zone, key, value and headers. A key or value that parses as JSON SHALL be embedded as JSON; otherwise it SHALL be a string. A `null` key or value SHALL be `null`, an empty key or value SHALL be `""`.

#### Scenario: Empty key is not turned into null
- **WHEN** the user copies a message whose key is an empty string
- **THEN** the copied JSON SHALL contain the key as `""`

#### Scenario: Tombstone value is null
- **WHEN** the user copies a tombstone message
- **THEN** the copied JSON SHALL contain the value as `null`

### Requirement: Copy Key and Copy Value Respect Absence
"Copy key" and "Copy value" SHALL copy the raw text of the field. They SHALL be disabled when the field is `null` and SHALL copy an empty string when the field is empty.

#### Scenario: Copy value of a tombstone
- **WHEN** the user opens the context menu of a tombstone message
- **THEN** "Copy value" SHALL be disabled

#### Scenario: Copy key of a message without key
- **WHEN** the user opens the context menu of a message whose key is `null`
- **THEN** "Copy key" SHALL be disabled

### Requirement: Consume-Only kcat Command
"Copy kcat command" SHALL copy a shell command that reads exactly this message in consumer mode: consumer flag, broker list, topic, partition, offset, a count of one and exit at end. It SHALL NOT contain producer, consumer-group or offset-commit options, SHALL NOT contain passwords, tokens or other secrets, and SHALL NOT disable TLS verification. Values SHALL be quoted for a POSIX shell.

#### Scenario: Command for a message
- **WHEN** the user copies the kcat command for offset 1042 of partition 3 of topic `orders` on a cluster with brokers `b1:9092`
- **THEN** the clipboard SHALL contain `kcat -C -b 'b1:9092' -t 'orders' -p 3 -o 1042 -c 1 -e`

#### Scenario: SASL profile without secrets
- **WHEN** the active profile uses SASL with a username and a password
- **THEN** the command SHALL carry security protocol, mechanism and username as `-X` options
- **AND** the password SHALL appear only as a reference to an environment variable, never as its value

#### Scenario: Unknown brokers
- **WHEN** the result view has no cluster profile (for example script run results)
- **THEN** the broker list SHALL be a visible placeholder instead of an empty or invented value

#### Scenario: No write or group options
- **WHEN** any kcat command is generated
- **THEN** it SHALL NOT contain `-P`, `-G` or any option that commits offsets or joins a consumer group

### Requirement: Null, Empty and Tombstone Markers in Result Views
The table, the timeline and the inspector SHALL mark a `null` value as tombstone and a `null` key as "no key", and SHALL show an empty key or value as "empty". The markers SHALL use text or an icon with a label, not colour alone, and SHALL be localized.

#### Scenario: Tombstone in the table
- **WHEN** a tombstone message is shown in the table
- **THEN** its Content cell SHALL show a tombstone marker instead of an empty cell

#### Scenario: Null key versus empty key in the table
- **WHEN** one message has a `null` key and another an empty-string key
- **THEN** their Key cells SHALL show two different markers

#### Scenario: Empty value in the timeline
- **WHEN** a message with an empty-string value is shown in the timeline
- **THEN** its card SHALL show an "empty" marker and SHALL NOT show the tombstone marker
