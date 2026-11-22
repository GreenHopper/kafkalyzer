# Spec Delta

## Purpose

Fixes what the module layout promises: feature modules depend on each other in
one direction only, anything two features share is defined once in a shared
module, and moving a source between modules changes no observable behaviour.

## ADDED Requirements

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
feature modules use SHALL exist once, in a shared module, and no feature module
SHALL keep a private copy or a feature-local re-export of it.

#### Scenario: Two features render the same item

- **WHEN** the same status badge or progress element is shown in two features
- **THEN** both SHALL render it from the single shared definition, with the same
  text, tooltip, semantic label and theme-derived colours

#### Scenario: Change copies a shared item into a second feature

- **WHEN** a change would satisfy a second feature by duplicating an item that
  already exists in a feature module
- **THEN** that change SHALL be considered non-conforming to this capability and
  SHALL relocate the original instead

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
