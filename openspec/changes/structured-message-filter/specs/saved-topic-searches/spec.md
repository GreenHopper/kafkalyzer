# Spec Delta

## MODIFIED Requirements

### Requirement: Persistent Topic Search Presets

The system SHALL persist named search configurations for each topic and cluster in local storage, capturing scan mode, filter type, filter query, filter expression, search scope, fast trace setting, partition filter, result limit, start/end conditions, and table column configurations. A preset stored without a filter expression SHALL load as a preset without expression.

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

#### Scenario: Saving and applying a preset with a filter expression

- **WHEN** the user saves a preset while the expression `header.eventType == "OrderCreated"` is set and later applies it
- **THEN** the stored preset SHALL contain the canonical expression text
- **AND** applying it SHALL restore that expression in the expression editor

#### Scenario: Preset saved before filter expressions existed

- **WHEN** a preset stored by an earlier version without a filter expression is applied
- **THEN** all its other values SHALL be restored unchanged and the expression editor SHALL be empty

#### Scenario: Preset with an expression that is no longer valid

- **WHEN** a stored preset contains an expression that fails validation
- **THEN** the preset SHALL remain selectable, applying it SHALL put the stored text into the text mode of the editor with its localized error
- **AND** the scan SHALL NOT start until the expression is corrected or cleared
