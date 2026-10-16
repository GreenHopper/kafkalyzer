# modernized-script-and-step-editor Specification

## Purpose

Provides an ergonomic and robust script definition and step configuration interface with non-blocking topic visualization, scan mode presets, un-truncated extraction source selector, and step deletion confirmation guards.

## Requirements

### Requirement: Non-Blocking Topic Display in ScriptStepEditor

When editing a script step, `ScriptStepEditor` SHALL immediately render the step's currently configured `topicNames` as removable chips and keep the topic field visible even while cluster topic metadata is still loading in the background.

#### Scenario: Opening Edit Step while cluster topics are loading
- **WHEN** the user opens `ScriptStepEditor` for a step with configured topics
- **AND** `TopicController.isLoading` is true for the selected cluster
- **THEN** the configured topic chips and the topic selector input SHALL remain visible
- **AND** the loading indicator SHALL be shown inline within the topic selector field rather than hiding the section

#### Scenario: Opening Edit Step when cluster is offline or topics fail to load
- **WHEN** the user opens `ScriptStepEditor` for a step with configured topics on an unreachable cluster
- **THEN** the configured topic chips SHALL remain visible and editable
- **AND** the topic field SHALL allow manual topic name entry or display the offline state without hiding configured topics

---

### Requirement: Scan Mode Presets and Progressive Disclosure in Step Configuration

`ScriptStepEditor` SHALL provide intuitive scan mode presets matching `TopicScanMode` (*Latest N*, *Time Range*, *Offset / Earliest*, *Live Stream*) and collapse expert filtering options behind an expandable advanced filters toggle.

#### Scenario: Selecting a Scan Mode Preset in ScriptStepEditor
- **WHEN** the user selects a scan mode preset in `ScriptStepEditor`
- **THEN** the underlying start strategy, end strategy, and limit controls SHALL update accordingly
- **AND** the step configuration summary SHALL reflect the chosen preset parameters

#### Scenario: Expanding Advanced Filters
- **WHEN** the user toggles the advanced filters section
- **THEN** filter type (contains, regex, exact), search scope (key, value, both), partition, and fast trace controls SHALL be revealed

---

### Requirement: Ergonomic Extraction Layout Without Truncation

In `ScriptStepEditor`, extraction rows SHALL allocate sufficient layout width or responsive structure so that the extraction source (`KEY`, `VALUE`, `HEADER`) is displayed without text truncation or ellipsis.

#### Scenario: Rendering Value Extractions with multiple topics selected
- **WHEN** a step defines a value extraction with source `KEY` or `VALUE`
- **THEN** the `Source` selector SHALL display the full label `KEY` or `VALUE` without ellipsis truncation across desktop window sizes

---

### Requirement: Step Deletion Guard in ScriptEditor

In `ScriptEditor`, deleting a step SHALL require explicit confirmation via a confirmation dialog before removing the step from the script definition.

#### Scenario: Triggering Step Deletion
- **WHEN** the user clicks the delete button on a script step row in `ScriptEditor`
- **THEN** a confirmation dialog SHALL be displayed asking the user to confirm the deletion
- **AND** the step SHALL only be removed if the user confirms the action

#### Scenario: Canceling Step Deletion
- **WHEN** the confirmation dialog is displayed and the user cancels or dismisses it
- **THEN** the step SHALL remain in the script definition unchanged

---

### Requirement: Compact Script Header

`ScriptEditor` SHALL present script name and concurrency limit within a single unified, compact header card with responsive width limits rather than separate full-width cards.

#### Scenario: Viewing Script Properties
- **WHEN** `ScriptEditor` is rendered
- **THEN** script name and concurrency limit SHALL be arranged in a unified header card constrained to avoid excessive horizontal stretching
