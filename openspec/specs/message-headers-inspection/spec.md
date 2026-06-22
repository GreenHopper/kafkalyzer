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
The system SHALL render message headers in the message details/inspector panel of the Explorer View.

#### Scenario: Display headers list
- **WHEN** the user inspects a message in the explorer view that contains headers
- **THEN** the system SHALL display the headers in a structured key-value list (with UTF-8 decoding for string values, and hex fallback for binary values)

