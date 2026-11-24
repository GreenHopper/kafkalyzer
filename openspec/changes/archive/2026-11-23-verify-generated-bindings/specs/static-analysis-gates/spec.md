# Spec Delta

## ADDED Requirements

### Requirement: Generated Source Drift Guard

The quality gate SHALL regenerate every checked-in source that a code
generator owns for the language bridge and for the test doubles, using the
generator version the project pins, and SHALL fail when the regenerated output
differs from the checked-in files. The guard SHALL decide from the checked-out
sources alone, with no committed baseline or exception list, and SHALL run
both as part of the full gate and as a separate entry point, locally and in
the pipeline.

#### Scenario: Bridge interface changed without regeneration

- **WHEN** a change edits a function or data type exposed across the language
  bridge and does not commit the regenerated bindings
- **THEN** the quality gate SHALL fail and name every generated file whose
  content differs

#### Scenario: Test double out of date

- **WHEN** a mocked interface changes and the checked-in test double was not
  regenerated
- **THEN** the quality gate SHALL fail and name the stale test double

#### Scenario: Regeneration adds a file

- **WHEN** regeneration produces a generated file that is not checked in
- **THEN** the quality gate SHALL fail and name the new file

#### Scenario: Checked-in output matches the generator

- **WHEN** regenerating with the pinned generator leaves every checked-in file
  unchanged and adds none
- **THEN** the guard SHALL report no finding

#### Scenario: Generator missing or at another version

- **WHEN** the generator is not installed, or its version differs from the
  version the project pins
- **THEN** the guard SHALL fail with a tooling error naming the expected version
  and how to install it
- **AND** it SHALL NOT report success for the checked-out sources

#### Scenario: Generated files already have uncommitted edits

- **WHEN** a generated file has uncommitted changes before the guard runs
- **THEN** the guard SHALL fail without regenerating, name the file, and leave
  its content untouched

#### Scenario: Generator run fails

- **WHEN** a generator exits with an error
- **THEN** the guard SHALL fail with a tooling error carrying the generator
  output and SHALL NOT report the sources as matching
