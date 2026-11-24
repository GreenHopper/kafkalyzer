# Spec Delta

## ADDED Requirements

### Requirement: Shared Module Import Guard

The quality gate SHALL reject any hand-written source in a shared module that
imports or re-exports a feature module, whether the reference is written as a
package path or as a relative path. Generated sources SHALL be exempt, as for
the other source guards. The guard SHALL decide from the checked-out sources
alone, with no committed baseline or exception list, and SHALL run both as part
of the full gate and as a separate entry point.

#### Scenario: Shared source gains a feature import

- **WHEN** a change adds an import of a feature module to a shared source
- **THEN** the quality gate SHALL fail and name the shared source and the
  imported feature module

#### Scenario: Relative path into a feature module

- **WHEN** a shared source reaches a feature module through a relative import
  path instead of a package path
- **THEN** the quality gate SHALL fail in the same way

#### Scenario: Composition root imports features

- **WHEN** the application's composition root imports feature modules to build
  the layout or register session-wide state
- **THEN** the quality gate SHALL report no finding for it

#### Scenario: Generated shared source

- **WHEN** the only offending reference is in a source produced by code
  generation
- **THEN** the quality gate SHALL report no finding for that file

#### Scenario: Source cannot be read

- **WHEN** the guard cannot read a shared source it lists
- **THEN** it SHALL fail with a tooling error naming that source
- **AND** it SHALL NOT report success for the checked-out sources
