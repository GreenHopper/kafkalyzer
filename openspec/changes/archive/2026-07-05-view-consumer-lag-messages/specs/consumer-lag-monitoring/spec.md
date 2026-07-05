## ADDED Requirements

### Requirement: Targeted Message Fetching for Lag Analysis
The system SHALL support fetching a limited number of messages starting from a specific offset for a given topic and partition, independent of active consumption.

#### Scenario: Fetch message at current offset
- **WHEN** a request is made to fetch messages at the current consumer offset
- **THEN** the system SHALL seek to that offset and return the message(s) without advancing the consumer group's committed offset.
