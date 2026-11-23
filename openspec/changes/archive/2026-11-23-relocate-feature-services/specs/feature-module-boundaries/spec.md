# Spec Delta

## MODIFIED Requirements

### Requirement: Item Shared By Two Features Has One Definition

A presentation item, a status value or a data-access seam that two or more
feature modules use SHALL exist exactly once, and no feature module SHALL keep a
private copy or a feature-local re-export of it. The single definition SHALL
live either in the feature module that owns it, imported by the other features
in one direction only, or in a shared module when no single feature owns it or
when keeping it in its owner would make two feature modules mutually reachable.

#### Scenario: Two features render the same item

- **WHEN** the same status badge or progress element is shown in two features
- **THEN** both SHALL render it from the single definition, with the same text,
  tooltip, semantic label and theme-derived colours

#### Scenario: Change copies a shared item into a second feature

- **WHEN** a change would satisfy a second feature by duplicating an item that
  already exists in a feature module
- **THEN** that change SHALL be considered non-conforming to this capability and
  SHALL relocate the original or import it instead

#### Scenario: Owner keeps an item another feature reads

- **WHEN** one feature module owns an item and a second feature module that the
  owner does not depend on reads it
- **THEN** the item MAY stay in the owning module, and the module graph SHALL
  still contain no cycle

## ADDED Requirements

### Requirement: Shared Modules Import No Feature Module

A shared module — the shared presentation, service and utility layers — SHALL
NOT import or re-export any feature module. Only the application's composition
root, which builds the top-level layout and registers session-wide state, MAY
depend on feature modules. A feature module SHALL therefore reach another
feature module only through a direct import that the module graph shows.

#### Scenario: Shared source needs a feature's type

- **WHEN** a shared source needs a type defined in a feature module
- **THEN** that type SHALL move to a shared module, or the shared source SHALL
  move into the single feature module that uses it, instead of the shared
  source importing the feature

#### Scenario: Shared service triggers a feature's refresh

- **WHEN** a shared service finishes an operation after which a feature's
  session-wide state must reload, for example importing a configuration
- **THEN** the feature that started the operation SHALL trigger the reload
- **AND** after a successful import the cluster list and the script list SHALL
  show the imported entries without a restart, as before

#### Scenario: Feature reaches another feature through a shared source

- **WHEN** the imports between feature modules are counted, including paths
  that pass through shared sources
- **THEN** the set of feature pairs that can reach each other SHALL be the same
  as when only direct feature-to-feature imports are counted

### Requirement: Stored Data Service Lives With Its Owning Feature

A service that reads and writes stored data owned by exactly one feature module
— saved preferences, saved searches, recent items, saved reports, local schema
assignments — SHALL live in that feature module. A service that no single
feature owns SHALL stay in the shared service layer. Relocating such a service
SHALL keep its stored data readable.

#### Scenario: Stored data written before the move

- **WHEN** a user starts the application after the update, with saved searches,
  recent topics, saved analysis reports, topic-list preferences and local
  schema assignments written by the previous version
- **THEN** each SHALL be shown exactly as before, with no entry lost or reset

#### Scenario: Stored data cannot be read

- **WHEN** a relocated service finds its stored data unreadable
- **THEN** it SHALL report that data as unreadable in the same way as before
  the move
- **AND** it SHALL NOT present the data as an empty list or overwrite it

#### Scenario: Another feature reads the owner's stored data

- **WHEN** a second feature shows or clears data that a relocated service owns,
  for example the settings screen deleting saved analysis reports
- **THEN** it SHALL use the owner's service through a one-direction import and
  SHALL NOT keep its own copy of the stored keys
