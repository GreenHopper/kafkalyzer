# Read-Only Invariants Enforcement Specification

## Purpose

Enforces strict read-only guarantees across the codebase through automated static analysis tooling and continuous integration verification gates, preventing accidental introduction of Kafka producer clients, message publishing, or partition offset mutations.

## Requirements

### Requirement: Automated Static Analysis Check for Write and Commit Paths

The system SHALL provide a dedicated static verification script that scans all Rust and Dart source files, failing with a descriptive error message and non-zero exit code if any Kafka producer, message publish, consumer group subscription, or offset commit API is detected.

#### Scenario: Forbidden Kafka producer or publish call fails verification

- **WHEN** the static analysis script is executed on source files containing `Producer`, `ThreadedProducer`, `FutureRecord`, or `.send(`
- **THEN** the script SHALL output the offending file paths and line numbers
- **AND** terminate execution with a non-zero exit status

#### Scenario: Forbidden consumer group commit call fails verification

- **WHEN** the static analysis script is executed on source files containing consumer `commit(`, `commit_message(`, or `commit_consumer_state(`
- **THEN** the script SHALL output the offending lines
- **AND** terminate execution with a non-zero exit status

#### Scenario: Compliant read-only codebase passes verification

- **WHEN** the static analysis script is executed against a codebase containing only consumer read and metadata query APIs
- **THEN** the script SHALL print a confirmation message stating that all read-only invariants are satisfied
- **AND** terminate execution with exit code 0

### Requirement: Continuous Integration Enforcement Gate

The automated CI workflow SHALL execute the read-only verification script as an independent check on every pull request and branch build, failing the CI pipeline if any prohibited write or commit pattern is detected.

#### Scenario: Pull request with prohibited write pattern is blocked in CI

- **WHEN** a pull request introduces a Kafka producer dependency or message mutation API
- **THEN** the CI workflow job for read-only verification SHALL fail
- **AND** block merging of the pull request

#### Scenario: Clean pull request passes CI gate

- **WHEN** all source code changes strictly adhere to read-only consumer and metadata operations
- **THEN** the CI workflow job for read-only verification SHALL succeed

### Requirement: Architectural Invariance of Kafka Consumer Configuration

Every Kafka consumer client configured and instantiated in the native backend SHALL explicitly configure `enable.auto.commit` as `false`, use manual partition assignment without joining broker consumer groups, and perform no partition offset commits.

#### Scenario: Consumer configuration sets enable.auto.commit to false

- **WHEN** a Kafka consumer client configuration is constructed for partition consumption or search streaming
- **THEN** the client configuration SHALL explicitly set `enable.auto.commit` to `false`

#### Scenario: Stream consumption does not mutate broker consumer group offsets

- **WHEN** message streaming or analysis completes, pauses, or terminates
- **THEN** the consumer client SHALL NOT invoke offset commit APIs or alter high-watermark consumer group progress on the broker
