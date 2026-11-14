## ADDED Requirements

### Requirement: Quick Filter Covers Headers, Partition and Offset
The in-memory quick filter SHALL match a message when the case-insensitive query occurs in its key, value, topic, step name (scripting views), a header key or a header value. A query that is a whole number SHALL also match messages whose partition or offset equals that number. Match count, row dimming and the filtered list SHALL use the same rule.

#### Scenario: Match on a header value
- **WHEN** a loaded message has header `traceId: abc-123` and its key and value do not contain `abc-123`
- **AND** the user types `abc-123` into the quick filter
- **THEN** the message SHALL be counted as a match and SHALL remain visible

#### Scenario: Numeric query matches offset exactly
- **WHEN** the user types `1042`
- **THEN** the message at offset 1042 SHALL match
- **AND** a message at offset 10420 SHALL NOT match unless `1042` occurs in its key, value, topic or headers

#### Scenario: Numeric query matches partition
- **WHEN** the user types `3`
- **THEN** every message in partition 3 SHALL match

#### Scenario: Dimmed non-matches agree with the count
- **WHEN** "show non-matches" is active and the quick filter has a query
- **THEN** exactly the messages counted as matches SHALL be shown undimmed
