# Spec Delta

## ADDED Requirements

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
