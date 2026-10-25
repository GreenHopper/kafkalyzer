# message-schema-provenance Specification

## Purpose

Records which Schema Registry subject, version and schema id a consumed message was encoded with, so schema drift between producer and consumer is visible per message instead of only at topic level.

## Requirements

### Requirement: Schema Identity Per Message Side

For a message whose key or value is Schema Registry encoded, the system SHALL report the registry subject, the schema version and the schema id for that side of the message.

#### Scenario: Registry-encoded value

- **WHEN** a message value is encoded with the topic value schema and the registry returns subject `orders-value`, version 4, id 128
- **THEN** the system SHALL report subject `orders-value`, version 4 and id 128 for the value side of that message

#### Scenario: Key and value use different schemas

- **WHEN** a message key uses subject `orders-key` version 1 and the value uses subject `orders-value` version 4
- **THEN** the system SHALL report both subject, version and id pairs separately for that message

#### Scenario: Plain payload without registry encoding

- **WHEN** a message payload is plain JSON or raw bytes without a registry identifier
- **THEN** the system SHALL report that no registry schema applies to that side
- **AND** the message SHALL still be listed and decoded as before

### Requirement: Schema Provenance Visible In The Inspector

The message inspector SHALL show the schema provenance of the selected message in its metadata header, labeled per key and value side.

#### Scenario: Inspector header shows provenance

- **WHEN** the user selects a message whose value was decoded from registry schema id 128
- **THEN** the inspector metadata header SHALL show subject, version and id for the value
- **AND** the entry SHALL be labeled so key-side and value-side provenance are distinguishable

#### Scenario: Message without provenance

- **WHEN** the user selects a message that carries no registry identifier
- **THEN** the inspector SHALL show a "no registry schema" state for that side
- **AND** no error message SHALL be shown

### Requirement: Jump To The Schema Of A Message

From the provenance of a selected message, the user SHALL be able to open the schema inspector for that exact subject and version.

#### Scenario: Open the schema used by this message

- **WHEN** the user activates the schema provenance entry of a message decoded with subject `orders-value` version 4
- **THEN** the schema inspector SHALL open showing subject `orders-value` at version 4
- **AND** the schema definition shown SHALL be the definition of that version

#### Scenario: Schema no longer retrievable

- **WHEN** the registry no longer returns the schema for the recorded id
- **THEN** the system SHALL keep the recorded subject, version and id visible on the message
- **AND** it SHALL report that the schema definition could not be loaded

### Requirement: Provenance Does Not Change Message Delivery

Reporting schema provenance SHALL NOT change which messages a scan returns, and an unreachable or slow registry SHALL NOT prevent messages from being delivered to the user.

#### Scenario: Registry unreachable during a scan

- **WHEN** the Schema Registry is unreachable while a scan is running
- **THEN** the scan SHALL continue to return the same messages as with the registry reachable
- **AND** provenance SHALL be reported as unresolved for the affected messages

#### Scenario: Repeated schema lookups are avoided

- **WHEN** a scan reads many messages that share the same schema id
- **THEN** the system SHALL resolve that schema id once for the scan session
- **AND** the number of registry requests SHALL NOT grow with the number of messages of that schema
