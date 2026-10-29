# consumer-lag-monitoring Specification

## Purpose
Monitoring offset lag for consumer groups in the Kafka cluster.
## Requirements
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

### Requirement: Configurable Concurrent Lag Queries
The system SHALL strictly limit the number of concurrent background queries used to fetch individual consumer group lag details. It SHALL also allow configuring this concurrency limit in the settings.

#### Scenario: Enforce query concurrency limit
- **WHEN** multiple consumer group lag queries are triggered
- **THEN** the system SHALL queue queries and execute at most the configured limit of concurrent queries simultaneously

#### Scenario: Configure limit in settings
- **WHEN** the user changes the concurrent queries limit in the settings view
- **THEN** the system SHALL persist the new limit and apply it to the query execution queue immediately

### Requirement: Targeted Message Fetching for Lag Analysis
The system SHALL support fetching a limited number of messages starting from a specific offset for a given topic and partition, independent of active consumption.

#### Scenario: Fetch message at current offset
- **WHEN** a request is made to fetch messages at the current consumer offset
- **THEN** the system SHALL seek to that offset and return the message(s) without advancing the consumer group's committed offset.

### Requirement: Consumer Group Processing Rate and Backlog Estimate
The system SHALL calculate and display a processing estimate for each consumer group based on recent consumption progress and elapsed time, indicating the processing throughput rate and estimated time to resolve the remaining lag.

#### Scenario: Active lag reduction displays estimated time to clear backlog
- **WHEN** consecutive lag queries for a consumer group show a decrease in total lag over an elapsed time interval
- **THEN** the system SHALL calculate the net drain rate in messages per second
- **AND** the system SHALL display the estimated completion time to clear remaining lag in the consumer group row

#### Scenario: Consumer group with zero lag indicates caught up
- **WHEN** a consumer group has a total lag of zero
- **THEN** the system SHALL indicate that the group is caught up without displaying a pending time estimate

#### Scenario: Backlog accumulating or growing
- **WHEN** consecutive lag queries show an increase in total lag while messages remain pending
- **THEN** the system SHALL indicate that the backlog is growing
- **AND** the system SHALL NOT display a positive completion countdown

#### Scenario: Stalled or idle consumption with pending lag
- **WHEN** consecutive lag queries show zero change in committed progress while total lag remains greater than zero
- **THEN** the system SHALL indicate that consumption is stalled or idle

#### Scenario: Insufficient history before second reading
- **WHEN** only an initial lag query reading exists for a consumer group without an elapsed comparison interval
- **THEN** the system SHALL indicate that processing estimates are pending calculation

### Requirement: Processing Estimate Details and Recovery Status
The system SHALL provide detailed diagnostic metrics for the processing estimate on demand, including the current throughput rate, net lag delta, sample interval duration, and recovery status.

#### Scenario: Inspecting processing estimate metrics
- **WHEN** the user hovers over or inspects a consumer group's processing estimate
- **THEN** the system SHALL display a tooltip with the net throughput rate in messages per second, the observed lag change, the elapsed time interval, and the backlog recovery status

#### Scenario: Partition and topic level processing estimates
- **WHEN** the user expands a consumer group to view topic and partition details
- **THEN** the system SHALL display the processing rate and backlog status for individual topics and partitions that have historical lag readings
