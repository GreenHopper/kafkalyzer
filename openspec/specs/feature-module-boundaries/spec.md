# feature-module-boundaries Specification

## Purpose
Fixes what the module layout promises: feature modules depend on each other in
one direction only, anything two features share is defined once in a shared
module, and moving a source between modules changes no observable behaviour.

## Requirements

### Requirement: Feature Modules Import Each Other In One Direction Only

For any pair of feature modules, imports SHALL flow in at most one direction,
so that no sequence of feature-to-feature imports returns to the module it
started from. A change that needs an item held by a module that already depends
on it SHALL relocate that item to a shared module or to the requesting module
instead of adding the reverse import.

#### Scenario: Change would close an import cycle

- **WHEN** a change adds an import from a feature module that the owning feature
  module already depends on
- **THEN** the change SHALL move the needed item instead of adding that import,
  and the resulting module graph SHALL still contain no cycle

#### Scenario: Reverse need is a view reading another feature's data

- **WHEN** the only reason for a reverse import is that a view in one feature
  shows data owned by a feature that depends on it
- **THEN** that view SHALL receive the data from the source that opens it rather
  than resolving the other feature's session-wide state itself

#### Scenario: Unrelated change adds no new import

- **WHEN** a change edits feature modules without adding any import between them
- **THEN** the module graph SHALL report the same set of import directions as
  before the change

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

### Requirement: Feature State Is Created By Its Own Module

State that presents one feature's data — the state of a per-item view, a
feature's list query and preferences — SHALL be created and held by the feature
module that owns that data, and another feature module SHALL receive it from
that owner rather than constructing and caching it itself.

#### Scenario: Feature needs another feature's per-item state

- **WHEN** a feature opens a view whose state belongs to another feature
- **THEN** it SHALL obtain that state from the owning module and SHALL NOT keep
  its own cache of it

#### Scenario: State for one item cannot be loaded

- **WHEN** the state for one item fails to load or is not readable
- **THEN** the item SHALL still be presented as not readable or unknown
- **AND** it SHALL NOT disappear from the list or be presented as an empty result

### Requirement: Relocating A Source Between Modules Preserves Behaviour

Moving a source from one module to another SHALL NOT change what the user sees,
which requests a user action issues, how long any piece of state lives, or the
localisation of any text.

#### Scenario: Same action before and after a move

- **WHEN** the user performs an action that reads cluster or Schema Registry
  data before and after the source move
- **THEN** the same set of describe-only read requests SHALL be issued
- **AND** the results, progress indication and error presentation SHALL be
  identical

#### Scenario: State that survives navigation still does

- **WHEN** state that a user finds again after leaving and returning to a
  destination is moved between modules
- **THEN** it SHALL still survive that navigation and SHALL still be released
  with the view when it is view-owned

#### Scenario: Source move leaves a lookup unresolvable

- **WHEN** a moved source can no longer be resolved at build time
- **THEN** the build SHALL fail with an unresolved-reference error
- **AND** no fallback or duplicated definition SHALL be introduced to keep the
  build green

### Requirement: Module Boundaries Add No Cluster Or Registry Access

Re-organising modules and shared sources SHALL NOT introduce a new Kafka or
Schema Registry request, and SHALL NOT require a new exception in the read-only
verification stage.

#### Scenario: Read-only stage after the re-organisation

- **WHEN** the read-only verification stage runs against the re-organised
  sources
- **THEN** it SHALL pass with its existing rule set and no added exception

#### Scenario: Shared consume seam after its move

- **WHEN** a search or a topic stream runs through the relocated consume seam
- **THEN** it SHALL still consume with manual partition assignment and no offset
  commit, and a denied read SHALL still be reported as not readable
