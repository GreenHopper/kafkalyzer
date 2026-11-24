# test-execution-isolation Specification

## Purpose

Makes automated verification runs independent: each run starts from a clean application container, dependencies of the unit under test can be substituted, and a verdict never depends on what an earlier run left behind or on machine timing.

## Requirements

### Requirement: Clean application container per test

Every automated verification run of an application component SHALL start from an application container that carries no registrations, no state and no scheduled work left by an earlier run in the same suite.

#### Scenario: Two runs using the same state

- **WHEN** two verification runs in one suite each produce state of the same kind
- **THEN** the second run SHALL observe only the state it produced itself

#### Scenario: Substitute leaks towards the next run

- **WHEN** one run supplies a substitute for a dependency and a later run asks for that dependency
- **THEN** the later run SHALL receive the session-wide dependency, not the earlier run's substitute

#### Scenario: Run order changes

- **WHEN** the suite is executed in a different order, or a single file is executed alone
- **THEN** every run SHALL report the same verdict as in the full default order

### Requirement: Unmet dependency fails visibly

When a component under verification needs session-wide state or a dependency that the run has not provided, the run SHALL fail with a reason naming what is missing, and SHALL NOT substitute an empty, zero or default value.

#### Scenario: Missing dependency

- **WHEN** a component asks for a dependency that the run has not provided
- **THEN** the run SHALL fail and identify the missing dependency

#### Scenario: Empty result is a real result

- **WHEN** a verification asserts that a collection is empty and the producing dependency was provided and returned no entries
- **THEN** the run SHALL pass, so an empty result stays distinguishable from an unmet dependency

### Requirement: Dependencies of a unit under test can be substituted

A verification run SHALL be able to supply its own implementation of any dependency a screen or component uses, without editing production sources, so that failures, delays and unavailable data can be exercised.

#### Scenario: Dependency fails

- **WHEN** a run supplies a dependency that reports a failure for a user action
- **THEN** the screen SHALL present that failure through its error state
- **AND** it SHALL NOT present an empty result as the outcome

#### Scenario: Dependency is slow

- **WHEN** a run supplies a dependency that completes only after the test advances time
- **THEN** the screen SHALL show its progress state while waiting and its result once the substitute completes
- **AND** the run SHALL not depend on wall-clock duration

#### Scenario: Dependency needs a live cluster

- **WHEN** a verification run exercises a screen that normally reads cluster data
- **THEN** the run SHALL use a substitute and SHALL NOT open any connection to a Kafka cluster, a Schema Registry or an operating-system keyring

### Requirement: Time-dependent verification controls its clock

Verification of behaviour that depends on elapsed time SHALL advance a clock the run controls instead of waiting for real time, so the verdict does not vary with machine load.

#### Scenario: Loaded machine

- **WHEN** the suite runs on a heavily loaded workstation or runner
- **THEN** time-dependent runs SHALL report the same verdict as on an idle one
- **AND** no time-dependent run SHALL pass only because a real-time wait happened to be long enough

#### Scenario: Scheduled work outlives its view

- **WHEN** a run dismisses a view that had scheduled recurring work
- **THEN** the run SHALL show that no further work is scheduled for the dismissed view

### Requirement: Session-wide state used by a test is declared

A verification run that relies on session-wide state SHALL provide that state through the shared test setup, so the set of state that crosses a run boundary is visible in the suite instead of being an incidental leftover.

#### Scenario: Test relies on undeclared session-wide state

- **WHEN** a run reads session-wide state that the shared test setup does not provide
- **THEN** the run SHALL fail with the unmet-dependency reason
- **AND** the suite SHALL NOT pass by inheriting that state from an earlier run

#### Scenario: Shared setup provides the state

- **WHEN** the shared test setup provides the session-wide state a run needs
- **THEN** the run SHALL use that provided state and SHALL pass without registering anything itself
