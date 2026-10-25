# Spec Delta

## Purpose

Keeps recent consumer lag readings per group so the direction of the lag over the last queries is visible, and lets a user set the lag level they consider a problem.

## ADDED Requirements

### Requirement: Recent Lag Samples Per Group

The system SHALL retain the lag readings of the current cluster session for each consumer group, newest last, and SHALL drop the oldest samples once the retained history reaches its limit.

#### Scenario: Repeated refresh builds history

- **WHEN** the user refreshes consumer lag five times for one group
- **THEN** the system SHALL hold five lag readings for that group
- **AND** the newest reading SHALL be the one currently shown as the lag value

#### Scenario: History limit is bounded

- **WHEN** the user refreshes lag more often than the retained history allows
- **THEN** the system SHALL keep the most recent readings up to the limit
- **AND** the total retained readings for a group SHALL NOT exceed that limit

#### Scenario: History is per cluster session

- **WHEN** the user disconnects from a cluster or connects to a different cluster
- **THEN** previously retained lag readings SHALL NOT be shown for the new session

### Requirement: Visible Lag Trend Per Group

The system SHALL render the retained lag history of each group as a compact trend in the group row, and SHALL render a trend for each partition row of the partition table.

#### Scenario: Growing backlog is visible

- **WHEN** a group's lag readings over the session are 100, 400, 900 and 1500
- **THEN** the group row SHALL show a rising trend
- **AND** the current lag value SHALL still be shown next to the trend

#### Scenario: Single reading

- **WHEN** only one lag reading exists for a group
- **THEN** the system SHALL show the lag value without a trend line
- **AND** no misleading flat trend SHALL be drawn

#### Scenario: Trend on hover

- **WHEN** the user points at a group's trend
- **THEN** the system SHALL show the retained readings with their refresh order
- **AND** the highest and lowest retained value SHALL be identifiable

### Requirement: Configurable Lag Warning Threshold

The system SHALL provide a numeric lag threshold setting and SHALL mark every group whose current lag exceeds that threshold with a warning indication.

#### Scenario: Threshold set and applied

- **WHEN** the user sets the warning threshold to 5000 and a group has a lag of 8000
- **THEN** that group SHALL be marked with the warning indication
- **AND** a group with a lag of 1200 SHALL not be marked

#### Scenario: Threshold persists

- **WHEN** the user sets a threshold and restarts the application
- **THEN** the previously set threshold SHALL be applied to the first lag query after start

#### Scenario: Threshold disabled

- **WHEN** the user clears or disables the threshold
- **THEN** no group SHALL carry the warning indication regardless of its lag
