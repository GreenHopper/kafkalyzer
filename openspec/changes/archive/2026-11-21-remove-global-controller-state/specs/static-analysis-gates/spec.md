# Spec Delta

## ADDED Requirements

### Requirement: Controller Locator Guard For Presentation Sources

The quality gate SHALL verify that a change does not introduce a new ambient lookup of session-wide state inside presentation sources of a feature, and SHALL scope that check to the hand-written sources the change touches, with no committed baseline or exception list.

#### Scenario: Change introduces a locator lookup for session-wide state

- **WHEN** a change adds a lookup of session-wide state in a presentation source it touches
- **THEN** the gate SHALL fail and identify the file and the state being looked up

#### Scenario: Change only removes such lookups

- **WHEN** a change reduces the number of session-wide state lookups in the presentation sources it touches
- **THEN** the gate SHALL report no finding for those files

#### Scenario: Presentation source needs a stateless service

- **WHEN** a touched presentation source obtains a stateless service or a dependency it receives from its caller
- **THEN** the gate SHALL report no finding, so the check covers session-wide state only

#### Scenario: Composition root wires the state

- **WHEN** the only place that performs such lookups is the application wiring or the shared test setup that provides the state
- **THEN** the gate SHALL report no finding for that source

#### Scenario: Unrelated work in an already non-conforming source

- **WHEN** a change touches a presentation source that already contained such a lookup at the merge base and does not add one
- **THEN** the gate SHALL report no finding for that file, so the existing count does not block unrelated work
