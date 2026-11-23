# Spec Delta

## ADDED Requirements

### Requirement: Import Cycle Guard For Changed Sources

The quality gate SHALL verify that a change does not enlarge the set of import
cycles between feature modules, and SHALL decide that verdict from the
hand-written sources the change touches and the merge base of the change, with
no committed baseline or exception list.

#### Scenario: Change closes an import cycle between features

- **WHEN** a change adds an import between feature modules that completes a cycle
  which did not exist at the merge base
- **THEN** the quality gate SHALL fail and name the feature modules on that cycle
  and the source carrying the added import

#### Scenario: Change removes a cycle

- **WHEN** a change relocates a shared source so that one cycle disappears and no
  cycle is added
- **THEN** the quality gate SHALL report no finding

#### Scenario: Pre-existing cycle is untouched

- **WHEN** a change edits feature modules that already form a cycle at the merge
  base and adds no import that creates another cycle
- **THEN** the quality gate SHALL report no finding, so the existing cycle does
  not block unrelated work

#### Scenario: Generated source takes part in a cycle

- **WHEN** the only source on the added edge is produced by a checked-in
  generator or by code generation
- **THEN** the quality gate SHALL report no finding for that file

#### Scenario: Module graph cannot be resolved

- **WHEN** the guard cannot resolve the imports of a touched source, for example
  because the source does not compile or the merge base is unavailable
- **THEN** the guard SHALL fail with a tooling error naming what it could not
  resolve
- **AND** it SHALL NOT report success for the checked-out sources
