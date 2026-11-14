# Spec Delta

## ADDED Requirements

### Requirement: Decoding With A Given Schema And Framing

The system SHALL decode an Avro, Protobuf or JSON Schema payload with a schema given to it, without a registry lookup. A payload with the registry prefix (magic byte `0x00` and a 4-byte schema id) SHALL be decoded after the prefix, a raw payload from its first byte. For Avro the framing SHALL be selectable as auto, prefixed or raw.

#### Scenario: Prefixed Avro payload

- **WHEN** an Avro value starts with magic byte `0x00` and schema id 42, followed by a record matching the given schema
- **THEN** the system SHALL decode the record and report schema id 42 and prefixed framing

#### Scenario: Raw Avro payload

- **WHEN** an Avro value without prefix matches the given schema and the framing is auto or raw
- **THEN** the system SHALL decode the record and report raw framing

#### Scenario: Raw Avro payload that starts with a zero byte

- **WHEN** the framing is auto and a raw Avro value starts with `0x00` but does not decode after a 5-byte prefix
- **THEN** the system SHALL decode it as a raw payload and report raw framing

#### Scenario: Framing forced to prefixed

- **WHEN** the framing is set to prefixed and a value has no valid prefix
- **THEN** decoding SHALL fail with the reason that the expected prefix is missing

#### Scenario: Prefixed JSON Schema payload

- **WHEN** a JSON Schema value carries the prefix followed by a JSON document
- **THEN** the system SHALL show the JSON document without the prefix bytes

### Requirement: Protobuf Message Selection From Message Indexes

For a prefixed Protobuf payload the system SHALL read the message-index list after the schema id and decode with the message it names in the given schema. A raw Protobuf payload SHALL be decoded with the chosen message type. The message type used SHALL be reported.

#### Scenario: Default message index

- **WHEN** a prefixed Protobuf value has the single-byte index list `0` and the given schema declares `Order` as its first message
- **THEN** the system SHALL decode the value as `Order`

#### Scenario: Nested message index

- **WHEN** the index list of a prefixed value is `[1, 0]` and the second top-level message `Envelope` declares the nested message `Item` first
- **THEN** the system SHALL decode the value as `Envelope.Item`

#### Scenario: Index not present in the given schema

- **WHEN** the index list names a message the given schema does not declare, or the index list is malformed
- **THEN** decoding SHALL fail with the reason naming the index list, without stopping the scan

#### Scenario: Raw Protobuf payload

- **WHEN** a Protobuf value has no prefix and the chosen message type is `acme.Order`
- **THEN** the system SHALL decode the value as `acme.Order`

### Requirement: Strict Match And Visible Decode Errors

Decoding with a given schema SHALL succeed only when the whole payload is consumed by the schema. Otherwise the payload SHALL keep its raw text or hex form and SHALL carry the decode error. A failed decode SHALL never yield an empty value.

#### Scenario: Unread trailing bytes

- **WHEN** an Avro record decodes but bytes of the payload remain unread
- **THEN** decoding SHALL fail with the number of unread bytes as reason

#### Scenario: Protobuf payload that does not match

- **WHEN** a Protobuf payload contains bytes that cannot be read as fields of the selected message
- **THEN** decoding SHALL fail and the raw hex form SHALL be shown with the reason

#### Scenario: JSON Schema payload that is not JSON

- **WHEN** a value assigned a JSON Schema is not a JSON document after the optional prefix
- **THEN** the raw form SHALL be shown with the reason that the payload is not JSON

#### Scenario: Null or empty payload

- **WHEN** a value is a tombstone (null) or has zero bytes
- **THEN** no decoding SHALL be attempted and the value SHALL be shown as a tombstone or empty value as without a schema
