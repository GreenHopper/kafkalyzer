# cluster-connection-progress Specification

## Purpose

Provides immediate visual progress feedback and robust lifecycle state tracking when connecting to Kafka clusters across all UI entry points, persisting through connection success, failure, and timeout scenarios.

## Requirements

### Requirement: Immediate Visual Connection Progress on Cluster Selection

When a user initiates connection to a Kafka cluster, the system SHALL display an immediate visual progress indicator on the targeted cluster item across all cluster selection surfaces until the connection succeeds, fails, or times out.

#### Scenario: Progress indicator on sidebar cluster during connection attempt
- **WHEN** the user clicks on a cluster in the Explorer sidebar cluster list to connect
- **THEN** the system SHALL immediately display a progress indicator next to that cluster's name before network validation starts
- **AND** the progress indicator SHALL remain continuously visible while the connection attempt is pending

#### Scenario: Progress indicator on onboarding cluster card
- **WHEN** the user clicks the connect action on a cluster card in the Explorer onboarding dashboard
- **THEN** the system SHALL immediately display a progress indicator on that cluster card
- **AND** the connect action SHALL be disabled to prevent duplicate concurrent connection requests

#### Scenario: Progress indicator persists through connection failure or timeout
- **WHEN** a cluster connection attempt encounters network latency, connection refusal, or times out
- **THEN** the visual progress indicator SHALL remain visible on the connecting cluster throughout the entire wait duration
- **AND** the progress indicator SHALL dismiss only when the timeout or error is finalized and reported

#### Scenario: Progress indicator dismisses upon successful connection
- **WHEN** a cluster connection attempt successfully completes validation and initial metadata loading
- **THEN** the connecting progress indicator SHALL dismiss
- **AND** the cluster SHALL transition to active selected state

### Requirement: Active Connection Controller Connecting Profile Tracking

The active connection controller SHALL track the specific cluster profile currently undergoing connection establishment and notify listeners immediately upon initiation and upon completion.

#### Scenario: Recording connecting profile at connection start
- **WHEN** `connect(profile)` is invoked on `ActiveConnectionController`
- **THEN** `connectingProfile` SHALL be set to the targeted profile
- **AND** `isConnecting` SHALL be set to true
- **AND** UI listeners SHALL be notified immediately before initiating network validation

#### Scenario: Clearing connecting profile on failure or timeout
- **WHEN** `connect(profile)` fails due to an exception, invalid credentials, or network timeout
- **THEN** `connectingProfile` SHALL be cleared to null
- **AND** `isConnecting` SHALL be set to false
- **AND** the error message SHALL be recorded and UI listeners notified

#### Scenario: Clearing connecting profile on success
- **WHEN** `connect(profile)` finishes validating and setting the active profile
- **THEN** `connectingProfile` SHALL be cleared to null
- **AND** `isConnecting` SHALL be set to false
- **AND** UI listeners SHALL be notified
