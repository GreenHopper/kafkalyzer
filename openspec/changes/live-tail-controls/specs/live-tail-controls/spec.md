## Purpose

Lets users watch a running message stream calmly: pause the result view without losing data, follow the newest
messages or keep their reading position, keep live updates cheap, and bound memory with a message buffer limit.

## ADDED Requirements

### Requirement: Pause and Resume the Result View

While a topic tab streams messages, the user SHALL be able to pause its result view. Pausing SHALL keep the displayed messages, SHALL NOT clear the buffer and SHALL NOT stop consumption. Messages received while paused SHALL be counted and shown as "n new" on the Resume control and SHALL be added to the view on resume, subject to the message buffer limit.

#### Scenario: Pause keeps the displayed messages

- **WHEN** the user pauses the result view of a running stream that shows 300 messages
- **AND** 200 further matching messages arrive
- **THEN** the view SHALL still show exactly the 300 messages it showed when paused, in the same order
- **AND** the Resume control SHALL show "200 new"

#### Scenario: Resume adds the new messages

- **WHEN** the user resumes a paused view with 200 new messages
- **THEN** the view SHALL show the 500 messages in the active order
- **AND** the "new" count SHALL be cleared
- **AND** the selected message and the inspector SHALL stay as they were if the selected message is still retained

#### Scenario: Buffer limit applies while paused

- **WHEN** the buffer limit is 1,000, the paused view shows 1,000 messages and 1,500 further messages arrive
- **THEN** the Resume control SHALL show "1,500 new"
- **AND** after resume the view SHALL show the newest 1,000 messages and the dropped-messages indicator SHALL include the dropped ones

#### Scenario: Stream ends or fails while paused

- **WHEN** the stream reaches its end, hits its result limit, is stopped by the user or fails while the view is paused
- **THEN** the view SHALL stay paused with its "new" count
- **AND** the stream status and any error SHALL be shown immediately, not deferred until resume

#### Scenario: New stream or clear ends the pause

- **WHEN** the user starts a new stream or clears the messages while the view is paused
- **THEN** the view SHALL no longer be paused and the "new" count SHALL be reset

#### Scenario: Pause is not offered without a stream

- **WHEN** no stream is running and the view is not paused
- **THEN** no Pause control SHALL be shown

### Requirement: Follow Newest Messages in the Table

The table view of a topic tab SHALL offer a "Follow newest" toggle, switched on when a stream starts. While on, the viewport SHALL stay at the edge where the newest messages appear under timestamp order. A manual scroll or selecting a row SHALL switch it off. While off, rows in the viewport SHALL stay in place as messages are added or dropped. The toggle SHALL be available only when the table is ordered by timestamp.

#### Scenario: Following with newest first

- **WHEN** the table is ordered by timestamp descending, follow is on and new messages arrive
- **THEN** the table SHALL stay scrolled to the top and show the newest messages

#### Scenario: Following with oldest first

- **WHEN** the table is ordered by timestamp ascending, follow is on and new messages arrive
- **THEN** the table SHALL stay scrolled to the bottom and show the newest messages

#### Scenario: Manual scroll switches follow off

- **WHEN** follow is on and the user scrolls the table by mouse wheel, drag, scrollbar or keyboard
- **THEN** the toggle SHALL switch off and show the off state by icon and label, not by colour alone
- **AND** programmatic scrolling done by the table itself SHALL NOT switch it off

#### Scenario: Selecting a row switches follow off

- **WHEN** follow is on and the user selects a row
- **THEN** follow SHALL switch off and the selected row SHALL stay in view while messages arrive

#### Scenario: Reading position is kept while follow is off

- **WHEN** follow is off, the table is ordered newest first and the user reads a row in the middle of the viewport
- **AND** 50 new messages arrive and 50 oldest messages are dropped
- **THEN** the row SHALL stay at the same position in the viewport

#### Scenario: Switching follow on jumps to the newest messages

- **WHEN** the user switches follow on
- **THEN** the table SHALL scroll to the edge with the newest messages and keep following

#### Scenario: Follow unavailable for other orders

- **WHEN** the table is ordered by a column other than timestamp
- **THEN** the toggle SHALL be disabled and its tooltip SHALL explain that following needs timestamp order
- **AND** new messages SHALL NOT move the rows in the viewport

### Requirement: Incremental Result View Updates

When a live update only adds messages or drops the oldest ones, the result views SHALL evaluate the in-memory search, the table column filters, cell formatting, projected column values and sort comparisons only for the added messages, and remove dropped ones without re-filtering or re-sorting the retained messages. Changing the search, filters, sort, columns or view, or replacing the list, SHALL recompute fully. The result SHALL equal a full recompute.

#### Scenario: Live update evaluates only new messages

- **WHEN** 10,000 messages are retained, an in-memory search is active and 100 new messages arrive
- **THEN** the search SHALL be evaluated for the 100 new messages only
- **AND** the displayed order, the match count and the dimmed non-matches SHALL equal those of a full recompute

#### Scenario: Projected columns resolve only new payloads

- **WHEN** projected columns are pinned and new messages arrive
- **THEN** projected values SHALL be resolved only for messages that have no resolved values yet
- **AND** values of dropped messages SHALL be released

#### Scenario: Dropped messages leave the view without re-sorting

- **WHEN** the buffer limit drops the oldest messages during a live update
- **THEN** exactly those messages SHALL disappear from every result view
- **AND** the relative order of the remaining messages SHALL NOT change

#### Scenario: Sort change recomputes fully

- **WHEN** the user changes the sort field, sort direction, table column sort, column filter or search text
- **THEN** the view SHALL recompute filtering and order over all retained messages once

#### Scenario: Non-live lists keep full recompute

- **WHEN** a result view shows a list that is not a live stream, such as a script run result
- **THEN** it SHALL be filtered and sorted as a whole whenever the list changes

### Requirement: Message Buffer Limit Setting

Settings SHALL offer a numeric message buffer limit (messages kept per result list) in the General section, stored as a non-sensitive preference, default 50,000, accepted range 1,000 to 1,000,000. Out-of-range or non-numeric input SHALL be rejected with an inline localized message. A changed limit SHALL apply to streams and searches started afterwards; running sessions keep their limit.

#### Scenario: Default when not set

- **WHEN** the buffer limit has never been set
- **THEN** the field SHALL show 50,000 and new streams and search targets SHALL retain up to 50,000 messages each

#### Scenario: Changed limit applies to the next stream

- **WHEN** the user sets the limit to 10,000 while a stream retains 30,000 messages
- **THEN** the running stream SHALL keep its retained messages and limit
- **AND** the next stream or search target started SHALL retain at most 10,000 messages

#### Scenario: Invalid input is rejected

- **WHEN** the user enters 500, 2,000,000 or a non-numeric value
- **THEN** the field SHALL show a localized inline error naming the accepted range
- **AND** the stored limit SHALL stay unchanged

#### Scenario: Unreadable stored value

- **WHEN** the stored preference is missing a valid integer or lies outside the accepted range, for example after a configuration import
- **THEN** the default of 50,000 SHALL be used and shown, and the stored value SHALL NOT be silently overwritten until the user saves a new one

### Requirement: Live Tail Controls Stay Read-Only

Pause, resume, follow and the buffer limit SHALL act only on data already received by the application. They SHALL NOT issue Kafka or Schema Registry requests, SHALL NOT commit, reset or seek offsets and SHALL NOT pause or reconfigure the broker consumer.

#### Scenario: Pausing does not touch the consumer

- **WHEN** the user pauses and resumes the result view of a running stream
- **THEN** no Kafka or Schema Registry request SHALL be issued because of it
- **AND** the consumer SHALL keep its manual partition assignment without committing or seeking offsets

#### Scenario: Read-only gate unchanged

- **WHEN** the read-only verification script runs on the code base with this capability
- **THEN** it SHALL pass without a new exception
