# Spec Delta

## Purpose

Provides interactive schema compatibility verification against Confluent Schema Registry subject versions, two-version structural and textual schema diffing, and bidirectional schema-to-topic association mapping.

## ADDED Requirements

### Requirement: Schema Registry Compatibility Verification

The system SHALL allow users to test whether a draft or modified schema is compatible with a chosen subject and version in the connected Schema Registry without registering the schema or altering broker state.

#### Scenario: Testing draft schema against latest subject version

- **WHEN** the user inputs or modifies a schema definition and requests compatibility validation against the latest version of a subject
- **THEN** the system SHALL query the Schema Registry compatibility endpoint
- **AND** display whether the draft is compatible according to the subject's configured compatibility mode

#### Scenario: Incompatible schema reports compatibility violation details

- **WHEN** the tested schema violates compatibility rules configured on the Schema Registry
- **THEN** the system SHALL display an incompatibility warning
- **AND** show any descriptive violation reasons or incompatible fields returned by the registry

### Requirement: Two-Version Schema Diff Viewer

The system SHALL provide a dedicated visual diff viewer that compares any two selected versions of a schema subject, clearly highlighting added, removed, and modified fields, types, and documentation attributes.

#### Scenario: Comparing two distinct versions of a subject

- **WHEN** the user selects a base version and a comparison version for a schema subject
- **THEN** the system SHALL fetch both schema definitions
- **AND** render a synchronized side-by-side or unified diff highlighting textual and field-level differences

#### Scenario: Unchanged versions show identical state

- **WHEN** two identical schema versions are compared
- **THEN** the diff viewer SHALL indicate that no structural or textual changes exist between the selected versions

### Requirement: Schema-to-Topic Association Discovery

The system SHALL discover and display all Kafka topics associated with a selected Schema Registry subject, mapping standard key and value conventions as well as multi-topic schema references.

#### Scenario: Viewing topics associated with a convention-based subject

- **WHEN** the user inspects a subject named `<topic>-value` or `<topic>-key`
- **THEN** the system SHALL list the corresponding topic as an associated topic
- **AND** provide a direct action to open that topic in the Topic Explorer

#### Scenario: Subject bound to multiple topics lists all associated topics

- **WHEN** multiple topics in the cluster share the same schema subject
- **THEN** the system SHALL display all associated topics in a selectable list
