## ADDED Requirements

### Requirement: Consumer Overview
The system SHALL display an overview of all active and inactive consumer groups in the Kafka cluster.

#### Scenario: View consumers
- **WHEN** the user navigates to the consumers view
- **THEN** the system fetches and displays a list of all consumer groups

### Requirement: Consumer Lag Display
The system SHALL calculate and display the lag for each partition of a consumer group's topics.

#### Scenario: View consumer lag
- **WHEN** the user views a specific consumer group
- **THEN** the system displays the topics, partitions, log end offsets, current offsets, and the computed lag

### Requirement: Refresh Consumer Lag
The system SHALL provide a way to refresh the consumer lag data to view the most current state.

#### Scenario: Refresh lag data
- **WHEN** the user clicks the refresh button or triggers an auto-refresh
- **THEN** the system fetches the latest offsets and updates the displayed lags
