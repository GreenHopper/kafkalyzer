# targeted-regression-coverage Specification

## Purpose

Makes the remaining high-gap search, scripting, schema-display and headless paths regression-safe through automated verification, and records the hand-written coverage floors that close the Tier-1 coverage debt without introducing a CI coverage ratchet.

## Requirements

### Requirement: Schema Display Simplification Is Unit-Verified

Transformations that turn a structured Avro schema definition into the simplified map shown in schema viewers SHALL be covered by automated unit verification for records, arrays, unions, primitives with documentation, and non-map passthrough inputs.

#### Scenario: Record with documented fields

- **WHEN** the suite runs the schema-display simplification cases
- **THEN** a record schema with nested and primitive fields SHALL produce a simplified map that preserves field names, type labels and documentation
- **AND** a non-map input SHALL pass through unchanged

#### Scenario: Union and array shapes

- **WHEN** the suite runs the union and array simplification cases
- **THEN** optional unions and array item types SHALL resolve to the simplified underlying shape without dropping documentation

### Requirement: Topic Selection Entry Point Is Widget-Verified

The multi-topic selection dialog used when composing a search SHALL be covered by automated widget verification for search filtering, internal/stream topic toggles, multi-select confirm, and cancel without selection change.

#### Scenario: Filter and confirm selection

- **WHEN** the suite opens the topic selection dialog with a known topic list
- **THEN** typing a query SHALL show only matching topic names
- **AND** confirming a multi-selection SHALL return the selected names to the caller

#### Scenario: Cancel leaves prior selection

- **WHEN** the user changes the in-dialog selection and cancels
- **THEN** the caller SHALL receive no new selection result

#### Scenario: Internal topics hidden by default

- **WHEN** the topic list includes names that start with an underscore
- **THEN** those topics SHALL be hidden until the internal-topics control is enabled

### Requirement: Script Parameter Value Picker Is Widget-Verified

The dialog that lets a user pick one or more values for a script parameter SHALL be covered by automated widget verification for search filtering, toggle selection, select-all on the filtered set, and confirm/cancel.

#### Scenario: Search and confirm values

- **WHEN** the suite opens the parameter-values dialog with a known value list
- **THEN** filtering by text SHALL narrow the visible values
- **AND** confirming SHALL return the selected set to the caller

#### Scenario: Empty filter result

- **WHEN** the filter matches no values
- **THEN** the dialog SHALL show an empty list state
- **AND** it SHALL NOT present that state as a confirmed empty selection until the user confirms

### Requirement: Script Run History Surfaces Are Widget-Verified

The script run history list, the per-run sidebar and the run details surface SHALL be covered by automated widget verification for empty history, populated history selection, and failure or missing-run presentation.

#### Scenario: Empty history

- **WHEN** no script runs are available
- **THEN** the history list SHALL show its empty state
- **AND** it SHALL NOT invent a run entry

#### Scenario: Select a run

- **WHEN** the history list contains at least one run and the user selects it
- **THEN** the sidebar and details surfaces SHALL show that run's summary
- **AND** unknown fields SHALL remain labelled as unknown rather than zero or blank success

#### Scenario: Failed run presentation

- **WHEN** a stored run records a failure
- **THEN** the details surface SHALL present the failure state
- **AND** it SHALL NOT present the run as successful

### Requirement: Filter Expression Editing Paths Are Widget-Verified

The filter expression editor used when configuring a topic search SHALL be covered by automated widget verification for valid expression acceptance, invalid expression blocking of the builder path, and the primary field-suggestion resolution order already required by search configuration behaviour.

#### Scenario: Invalid expression blocks builder

- **WHEN** the editor holds an invalid expression
- **THEN** switching to or applying the builder path SHALL be blocked
- **AND** a valid expression SHALL be accepted

#### Scenario: Suggestion sources

- **WHEN** field suggestions are requested
- **THEN** schema-derived fields SHALL take precedence over analysis-derived fields
- **AND** message-derived fields SHALL fill remaining gaps up to the documented cap

### Requirement: Script Schemas View Paths Are Widget-Verified

The script workspace surface that shows schemas associated with a script SHALL be covered by automated widget verification for an empty association list, a populated list, and the unavailable or error state when schema data cannot be loaded.

#### Scenario: Populated schema list

- **WHEN** the suite supplies associated schemas for a script
- **THEN** the schemas view SHALL list them for inspection

#### Scenario: Unavailable schema data

- **WHEN** schema data cannot be loaded
- **THEN** the schemas view SHALL present an error or unavailable state
- **AND** it SHALL NOT present an empty success list in place of the failure

### Requirement: Headless Runner Edge Paths Are Verified

Automated verification of the headless script runner SHALL cover missing required parameters, successful structured reporting, and at least one failure path that returns a non-zero process outcome, without opening a Kafka cluster or Schema Registry connection.

#### Scenario: Missing required parameter

- **WHEN** a script declares a required variable that is not supplied
- **THEN** the runner SHALL abort before any cluster connection
- **AND** the process outcome SHALL be non-zero with an error naming the missing variable

#### Scenario: Failure path is distinguishable

- **WHEN** a run is configured to fail through a substitute dependency
- **THEN** the structured report SHALL record the failure
- **AND** the process outcome SHALL be non-zero

### Requirement: Hand-Written Coverage Floors For This Change

After the new verification is in place, a fresh coverage measurement that excludes generated bridge bindings, localization outputs and codegen artifacts SHALL report at least 86 % line coverage on hand-written application sources, no hand-written application source below 40 % except the application bootstrap entry point, and the script run history directory above 70 %.

#### Scenario: Floors met on a fresh measurement

- **WHEN** the suite is run with coverage collection after this change
- **THEN** hand-written application line coverage SHALL be at least 86 %
- **AND** every hand-written application source except the bootstrap entry point SHALL be at or above 40 %
- **AND** the script run history directory SHALL be above 70 %

#### Scenario: Bootstrap entry point remains exempt

- **WHEN** the bootstrap entry point alone sits below 40 %
- **THEN** that file SHALL NOT fail the floor check for this capability

### Requirement: No Coverage Percentage Ratchet In The Quality Gate

The source quality gate SHALL NOT fail a change solely because measured line coverage is below a fixed percentage, and SHALL NOT introduce a committed coverage baseline, allowlist or ratchet file for that purpose.

#### Scenario: Coverage number alone does not fail the gate

- **WHEN** a change leaves formatting, analysis and existing gate checks clean but measured line coverage is below a chosen percentage
- **THEN** the quality gate SHALL still report success for those checks
- **AND** a coverage percentage ratchet SHALL be considered non-conforming to this capability

#### Scenario: Read-only and isolation gates stay separate

- **WHEN** this capability's verification is added
- **THEN** the read-only invariant stage and test-execution isolation behaviour SHALL continue unchanged as their own contracts
