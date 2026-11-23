# Spec Delta

## ADDED Requirements

### Requirement: Legacy Material Import Guard

The quality gate SHALL reject any hand-written application or test source
that imports or re-exports the framework's deprecated legacy Material or
Cupertino library, so all Material UI comes from the standalone package.
Generated sources SHALL be exempt. The guard SHALL use no baseline or
exception list and SHALL run in the full gate and as its own entry point.

#### Scenario: Source imports the legacy Material library

- **WHEN** a hand-written application or test source imports the legacy
  Material library, with or without a prefix or an ignore comment
- **THEN** the quality gate SHALL fail and name the source and the imported
  library

#### Scenario: Source re-exports the legacy Cupertino library

- **WHEN** a hand-written source re-exports the legacy Cupertino library
- **THEN** the quality gate SHALL fail and name the source

#### Scenario: Only the standalone Material UI package is used

- **WHEN** every hand-written source takes Material UI from the standalone
  package
- **THEN** the guard SHALL report no finding

#### Scenario: Generated source uses the legacy library

- **WHEN** only a generated source references the legacy library
- **THEN** the guard SHALL report no finding for it

#### Scenario: Listed source cannot be read

- **WHEN** a source the guard must check cannot be read
- **THEN** the guard SHALL fail with a tooling error naming the source
- **AND** it SHALL NOT report the sources as clean
