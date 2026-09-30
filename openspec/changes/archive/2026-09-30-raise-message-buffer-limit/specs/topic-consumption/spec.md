## ADDED Requirements

### Requirement: Result Buffer Honors Configured Limit

The Flutter message streaming layer SHALL retain every matching message delivered for a consumption session according to the configured result limit: when a limit of $N$ matching messages is configured, it SHALL retain up to $N$ matching messages; when no result limit is configured, it SHALL retain all matching messages received until the stream ends or the user stops consumption. The layer MUST NOT silently discard matching messages at a fixed buffer ceiling (such as 1000) that is independent of the configured result limit. Retained messages SHALL remain available for display and for message export for that session.

#### Scenario: Unlimited consumption retains more than 1000 matches

- **WHEN** message consumption runs with no result limit configured
- **AND** more than 1000 matching messages are delivered before the stream ends
- **THEN** the in-session message buffer SHALL contain all delivered matching messages
- **AND** message export for that session SHALL include all retained matching messages

#### Scenario: Configured limit above 1000 retains up to N matches

- **WHEN** message consumption runs with a result limit of $N$ where $N > 1000$
- **AND** at least $N$ matching messages are available in the selected range
- **THEN** the in-session message buffer SHALL retain $N$ matching messages
- **AND** SHALL NOT drop matching messages solely because more than 1000 were received

#### Scenario: Configured limit still caps retention

- **WHEN** message consumption runs with a result limit of $N$
- **AND** more than $N$ matching messages would otherwise be available
- **THEN** the in-session message buffer SHALL retain at most $N$ matching messages
- **AND** consumption SHALL stop once $N$ matching messages have been retained
