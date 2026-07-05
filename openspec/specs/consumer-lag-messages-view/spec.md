# consumer-lag-messages-view Specification

## Purpose
TBD - created by archiving change view-consumer-lag-messages. Update Purpose after archive.
## Requirements
### Requirement: Launch Message Inspection from Partition
The system SHALL provide a "View Messages" action for each partition in the consumer group details table of the Lag Dashboard.

#### Scenario: Open message inspector from lag view
- **WHEN** the user clicks the "View Messages" icon for a specific partition in the expanded consumer group table
- **THEN** the system SHALL open a message inspection view focused on that topic, partition, and starting at the current consumer offset.

### Requirement: Display Poison Pill Candidate
The system SHALL highlight or automatically select the message at the current consumer offset to help the user identify it as a potential poison pill.

#### Scenario: Auto-select current offset message
- **WHEN** the message inspection view is opened from the lag dashboard
- **THEN** the system SHALL fetch and display the message at the current offset and prioritize its visibility in the inspector.

