# message-headers-inspection Specification

## Purpose
TBD - created by archiving change enterprise-security-and-decoding-improvements. Update Purpose after archive.
## Requirements
### Requirement: Message Headers Extraction
The system SHALL extract message headers (metadata key-value pairs) from polled Kafka messages and pass them through the Rust-Dart bridge boundary.

#### Scenario: Parse headers from Kafka message
- **WHEN** the consumer retrieves a message that contains one or more headers
- **THEN** the system SHALL extract the key and byte value of each header and pack them in the `KafkaMessage` structure

### Requirement: Message Headers UI Display
The system SHALL render message headers in a reusable message details/inspector component that can be invoked from both the Explorer View and the Consumer Lag View.

#### Scenario: Display headers list in reusable inspector
- **WHEN** the user inspects a message that contains headers (regardless of which view triggered the inspection)
- **THEN** the system SHALL display the headers in a structured key-value list (with UTF-8 decoding for string values, and hex fallback for binary values).

