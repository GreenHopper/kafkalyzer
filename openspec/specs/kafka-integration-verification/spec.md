# kafka-integration-verification Specification

## Purpose
Verifies the backend's Kafka read paths against a real, disposable broker on
every change, using fixtures that any checkout can recreate, and proves that
the verified operations leave broker data unchanged.

## Requirements

### Requirement: Whole Backend Unit Suite Runs On Every Change

The pipeline SHALL run the unit tests of every crate in the native backend
workspace on every pull request and branch build, and SHALL fail when any of
them fails.

#### Scenario: Unit test in a non-bridge crate fails

- **WHEN** a change breaks a unit test in the computation crate or the Kafka
  I/O crate
- **THEN** the pipeline SHALL fail and name that test

#### Scenario: All workspace unit tests pass

- **WHEN** every unit test in every backend crate passes
- **THEN** the unit test stage SHALL succeed

### Requirement: Broker-Dependent Tests Run Against A Disposable Broker

The pipeline SHALL run every broker-dependent backend test on every pull
request and branch build against a broker started for that run, and a failure
SHALL block the build and release jobs. The broker tests SHALL run separately
from the source quality gate.

#### Scenario: Broker read path regresses

- **WHEN** a change breaks a Kafka metadata, configuration, watermark,
  consumer-lag or time-range read that a broker test covers
- **THEN** the broker test stage SHALL fail and no build or release job
  SHALL start

#### Scenario: Broker cannot be started

- **WHEN** the disposable broker does not become ready within the allowed
  time
- **THEN** the stage SHALL fail with a tooling error saying the broker is
  unavailable
- **AND** it SHALL NOT report the broker tests as passed or skipped

### Requirement: Fixtures Are Created And Checked By The Run

Every topic, record and consumer-group offset that a broker test reads SHALL
be created by the same entry point that runs the tests. The entry point SHALL
check each fixture's shape before any test runs and stop with an error that
names the fixture when the shape differs. Fixture creation SHALL be
deterministic, so repeated runs on a fresh broker give the same fixtures.

#### Scenario: Fresh broker

- **WHEN** the entry point runs against a broker without fixtures
- **THEN** it SHALL create every fixture the broker tests read and run the
  tests

#### Scenario: Fixture already present with the expected shape

- **WHEN** the entry point runs against a broker that already holds a fixture
  with the expected shape
- **THEN** it SHALL reuse that fixture and run the tests

#### Scenario: Fixture shape differs

- **WHEN** a fixture exists but differs from the expected shape, for example
  its record count per partition or its committed group offsets
- **THEN** the entry point SHALL stop before running any test, name the
  fixture and the difference, and say how to reset the broker
- **AND** it SHALL NOT change or delete the existing fixture

### Requirement: Verification Leaves Broker Data Unchanged

The verified backend operations SHALL stay read-only. After the broker tests,
the entry point SHALL compare the fixtures' end offsets, committed
consumer-group offsets and group membership with their state before the tests,
and SHALL fail when any of them changed. When a value cannot be read after the
tests, the run SHALL report it as unknown and fail. It SHALL NOT count an
unreadable value as unchanged.

#### Scenario: Tests leave fixtures untouched

- **WHEN** the broker tests finish and every recorded end offset, committed
  offset and group membership equals its value before the tests
- **THEN** the read-only comparison SHALL pass

#### Scenario: A test changes broker data

- **WHEN** a committed offset or end offset differs after the tests, or the
  fixture group gained a member
- **THEN** the run SHALL fail and name the fixture and the changed value

#### Scenario: State cannot be read after the tests

- **WHEN** the entry point cannot read a fixture's state after the tests
- **THEN** the run SHALL fail and report that value as unknown

### Requirement: Seeding Is Confined To The Disposable Broker

Fixture creation SHALL write only to the broker the entry point started. The
entry point SHALL accept no broker address and SHALL refuse to run when that
broker is not running.

#### Scenario: Disposable broker not running

- **WHEN** the entry point starts and the disposable broker is not running
  and cannot be started
- **THEN** it SHALL fail without writing to any broker

#### Scenario: Developer has another cluster configured

- **WHEN** a developer's environment points to another Kafka cluster
- **THEN** fixture creation SHALL still write only to the disposable broker

### Requirement: Same Verdict Locally And In The Pipeline

Developers SHALL be able to run the broker tests, with fixture creation and
the read-only comparison, through the single entry point the pipeline uses.

#### Scenario: Local run on a clean machine

- **WHEN** a developer with a container runtime runs the entry point on a
  fresh checkout
- **THEN** it SHALL start the broker, create the fixtures and run the same
  tests as the pipeline, with the same verdict

#### Scenario: Container runtime missing

- **WHEN** the entry point runs on a machine without a container runtime
- **THEN** it SHALL fail with a tooling error naming the missing runtime and
  SHALL NOT report the tests as passed
