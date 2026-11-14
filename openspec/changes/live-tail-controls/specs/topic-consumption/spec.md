## MODIFIED Requirements

### Requirement: Throttled UI State Emission and Amortized Buffering

The Flutter message streaming layer SHALL buffer messages from native Rust streams, for the single-topic stream and for every multi-topic search target, and dispatch UI state notifications at most once every 50ms to 100ms, delivering the last pending batch within one such interval. Adding a message, and dropping the oldest one at the buffer limit, SHALL take amortized $O(1)$ time without shifting the retained messages.

#### Scenario: High-throughput message streaming to UI

- **WHEN** Kafka messages arrive across the FFI stream at sustained throughput exceeding 100 messages per second
- **THEN** the UI controller buffers incoming messages and triggers state notifications at a throttled cadence between 50ms and 100ms
- **AND** does not invoke `notifyListeners()` on every individual message
- **AND** adds incoming messages without $O(N)$ list prepending shifts

#### Scenario: Last batch before a quiet period is delivered

- **WHEN** a multi-topic search target or the single-topic stream receives a burst of messages and then no further message for several seconds
- **THEN** every message of the burst SHALL be visible to the UI no later than 100ms after it arrived
- **AND** the UI SHALL NOT wait for a later message or for the end of the stream to show them

#### Scenario: Dropping the oldest message at the buffer limit does not shift the buffer

- **WHEN** the buffer holds as many messages as the buffer limit allows
- **AND** 10,000 further matching messages arrive
- **THEN** each arrival SHALL replace the oldest retained message in constant time
- **AND** the remaining retained messages SHALL NOT be moved or copied per arriving message

### Requirement: Result Buffer Honors Configured Limit

The streaming layer SHALL retain the matching messages of a session, for the single-topic stream and each multi-topic search target, up to the smaller of the result limit and the message buffer limit setting. At the buffer limit the oldest messages SHALL be dropped in arrival order and the view SHALL show how many were dropped. Messages MUST NOT be dropped silently or at a fixed ceiling. Retained messages SHALL stay available for display and export; match counts SHALL report all received matches.

#### Scenario: Unlimited consumption retains more than 1000 matches

- **WHEN** message consumption runs with no result limit configured and a buffer limit of 50,000
- **AND** 1,500 matching messages are delivered before the stream ends
- **THEN** the in-session message buffer SHALL contain all 1,500 delivered matching messages
- **AND** message export for that session SHALL include all retained matching messages
- **AND** no dropped-messages indicator SHALL be shown

#### Scenario: Configured limit above 1000 retains up to N matches

- **WHEN** message consumption runs with a result limit of $N$ where $1000 < N \le$ the buffer limit
- **AND** at least $N$ matching messages are available in the selected range
- **THEN** the in-session message buffer SHALL retain $N$ matching messages
- **AND** SHALL NOT drop matching messages solely because more than 1000 were received

#### Scenario: Configured limit still caps retention

- **WHEN** message consumption runs with a result limit of $N$
- **AND** more than $N$ matching messages would otherwise be available
- **THEN** the in-session message buffer SHALL retain at most $N$ matching messages
- **AND** consumption SHALL stop once $N$ matching messages have been received

#### Scenario: Buffer limit drops the oldest messages with a visible count

- **WHEN** a live stream runs with no result limit and a buffer limit of 1,000
- **AND** 1,250 matching messages have been received
- **THEN** the buffer SHALL retain the 1,000 most recently received messages
- **AND** the topic view SHALL show that 250 oldest messages were dropped
- **AND** the match count SHALL show 1,250 received matches

#### Scenario: Result limit above the buffer limit

- **WHEN** message consumption runs with a result limit of 80,000 and a buffer limit of 50,000
- **AND** 80,000 matching messages are available
- **THEN** consumption SHALL continue until 80,000 matching messages have been received
- **AND** the buffer SHALL retain the newest 50,000 and the view SHALL show that 30,000 oldest messages were dropped

#### Scenario: Multi-topic search target has no silent ceiling

- **WHEN** a script or multi-topic search target receives 6,000 matching messages with a buffer limit of 5,000
- **THEN** that target SHALL retain the newest 5,000 messages
- **AND** its topic progress entry SHALL show 6,000 matches and that 1,000 oldest messages were dropped
- **AND** a target receiving 3,000 matching messages SHALL retain all 3,000 and show no dropped count

#### Scenario: New session resets the dropped count

- **WHEN** messages were dropped in a previous session of a topic tab
- **AND** the user starts a new stream or clears the messages
- **THEN** the dropped count SHALL be reset to zero and the indicator SHALL be hidden

#### Scenario: Stream error after drops keeps the count

- **WHEN** a live stream fails with an error after messages were dropped
- **THEN** the retained messages and the dropped count SHALL stay visible next to the error
