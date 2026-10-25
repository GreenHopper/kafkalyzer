# saved-topic-searches Specification

## Purpose

Enables users to save, manage, and recall complete topic search configurations (filters, scan modes, offsets, boundaries, and table column presets) as reusable named presets, eliminating repetitive setup across operational shifts.

## Requirements

### Requirement: Persistent Topic Search Presets

The system SHALL persist named search configurations for each topic and cluster in local storage, capturing scan mode, filter type, filter query, search scope, fast trace setting, partition filter, result limit, start/end conditions, and table column configurations.

#### Scenario: Saving a new search preset

- **WHEN** the user configures search parameters and chooses to save the current configuration as a preset named "Errors Last Hour"
- **THEN** the system SHALL store the complete configuration under the topic and cluster namespace in local storage
- **AND** "Errors Last Hour" SHALL immediately become selectable in the topic's preset list

#### Scenario: Applying a saved search preset

- **WHEN** the user selects a saved search preset from the preset selector
- **THEN** all search configuration inputs (scan mode, filter options, start/stop conditions, and limits) SHALL immediately populate with the preset's saved values
- **AND** the table view SHALL apply any associated column visibility and projected column paths

#### Scenario: Overwriting an existing search preset

- **WHEN** the user modifies parameters and chooses to update an existing saved preset
- **THEN** the stored preset configuration SHALL be updated with the current values without duplicating the preset name

#### Scenario: Deleting a search preset

- **WHEN** the user deletes a saved preset from the management affordance
- **THEN** the preset SHALL be removed from storage and from the selectable preset list
- **AND** the currently displayed search inputs SHALL remain unchanged

### Requirement: Ergonomic Search Preset Selector

The Search Configuration panel SHALL provide a compact, non-intrusive preset selector that allows loading and saving presets without adding dedicated button rows or reducing the vertical space allocated to message results.

#### Scenario: Preset selector integrated into configuration header

- **WHEN** the Search Configuration panel is displayed
- **THEN** a compact preset dropdown selector SHALL be rendered in the configuration control area
- **AND** the selector SHALL indicate the currently active preset name or "Default / Unsaved"

#### Scenario: Save preset action opens lightweight dialog

- **WHEN** the user triggers the "Save Current Search as Preset" action
- **THEN** a lightweight dialog SHALL prompt for a descriptive preset name
- **AND** upon confirmation, the preset SHALL be saved and selected

### Requirement: Per-Topic and Cluster Preset Scoping

Search presets SHALL be strictly scoped to the combination of cluster identity and topic name, preventing presets created for one topic structure from cluttering or conflicting with another topic.

#### Scenario: Topic context switches hide presets of other topics

- **WHEN** the user switches from topic `orders` to topic `notifications`
- **THEN** the preset selector SHALL display only presets configured for `notifications` on the active cluster
- **AND** presets configured for `orders` SHALL NOT appear in the dropdown
