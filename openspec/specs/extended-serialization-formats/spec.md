# extended-serialization-formats Specification

## Purpose
TBD - created by archiving change enterprise-security-and-decoding-improvements. Update Purpose after archive.
## Requirements
### Requirement: Confluent JSON Schema Decoding
The system SHALL support decoding Kafka message keys and payloads that are serialized with Confluent JSON Schema.

#### Scenario: Consume JSON Schema message
- **WHEN** the consumer receives a message whose schema type is registered as JSON Schema in the Schema Registry
- **THEN** the system SHALL fetch the JSON Schema, decode the binary payload, and display the formatted JSON string in the message details view

### Requirement: Confluent Protobuf Decoding
The system SHALL support decoding Kafka message keys and payloads that are serialized with Confluent Protobuf.

#### Scenario: Consume Protobuf message
- **WHEN** the consumer receives a message whose schema type is registered as Protobuf in the Schema Registry
- **THEN** the system SHALL fetch the Protobuf schema, decode the binary payload, and display the decoded fields as formatted JSON in the message details view

