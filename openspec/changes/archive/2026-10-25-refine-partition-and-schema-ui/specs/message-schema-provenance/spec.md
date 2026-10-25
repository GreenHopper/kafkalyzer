# Spec Delta: message-schema-provenance

## ADDED Requirements

### Requirement: Compact Schema Provenance On Timeline Cards

The timeline and diff message cards SHALL present schema provenance in a compact, non-intrusive format that avoids repetitive multi-line text. The card SHALL NOT render negative placeholders for sides without a registry schema, and SHALL NOT display redundant subject names on every card.

#### Scenario: Message card with registry-encoded value

- **WHEN** a message has a schema-encoded value with id 128 and version 4, and no registry schema on the key
- **THEN** the message card SHALL display a compact schema indicator (such as version or id)
- **AND** the card SHALL NOT display a line stating that the key has no schema
- **AND** the card SHALL NOT render the full schema subject name across a dedicated line

#### Scenario: Message card without any registry schema

- **WHEN** a message has neither a key schema nor a value schema
- **THEN** the message card SHALL NOT render any schema lines or placeholders

## MODIFIED Requirements

### Requirement: Schema Provenance Visible In The Inspector

The message inspector SHALL remain the authoritative surface for full schema provenance details of the selected message, displaying the subject name, version number, and schema id labeled per key and value side.

#### Scenario: Inspector header shows provenance

- **WHEN** the user selects a message whose value was decoded from registry schema id 128
- **THEN** the inspector metadata header SHALL show subject, version and id for the value
- **AND** the entry SHALL be labeled so key-side and value-side provenance are distinguishable

#### Scenario: Message without provenance

- **WHEN** the user selects a message that carries no registry identifier
- **THEN** the inspector SHALL show a "no registry schema" state for that side
- **AND** no error message SHALL be shown
