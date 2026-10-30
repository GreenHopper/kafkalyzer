# Spec Delta

## MODIFIED Requirements

### Requirement: Top Duplicated Messages Ranking

The analysis report SHALL rank the top most frequent duplicated messages (up to 20) with their occurrence count, percentage share of total messages, key preview (if present), decoded payload representation (or fallback binary indicator when decoding is unavailable), and sample metadata (partition, offset, timestamp).

#### Scenario: Inspecting top duplicated messages
- **WHEN** an analysis finishes on a topic that contains duplicate messages
- **THEN** the system SHALL display the ranked list of top duplicated messages with their occurrence count, percentage share, and decoded payload preview
- **AND** provide sample partition, offset, and timestamp for inspection

#### Scenario: Payload preview truncation
- **WHEN** a duplicated message payload exceeds display limits
- **THEN** the preview SHALL be shortened for display without failing analysis

#### Scenario: Schema Registry and structured message decoding
- **WHEN** duplicated messages are encoded with Schema Registry wire format (Avro/Protobuf) or valid JSON
- **THEN** the system SHALL produce readable decoded JSON representations for duplicate previews rather than raw hex binary markers

#### Scenario: Undecodable binary fallback
- **WHEN** a duplicated message payload is arbitrary binary or cannot be decoded with active schemas
- **THEN** the system SHALL retain hexadecimal binary markers without failing analysis

### Requirement: Duplicate Analysis Dashboard Presentation

The topic analysis view SHALL present duplicate analysis metrics in a dedicated summary card and provide a section to inspect the top duplicated messages with interactive drill-down and copy actions.

#### Scenario: Summary card display
- **WHEN** topic analysis results are loaded in the view
- **THEN** a summary card SHALL display the duplicate message count and duplicate rate percentage

#### Scenario: Viewing top duplicates list
- **WHEN** duplicate messages were detected
- **THEN** the report view SHALL render the top duplicated messages list with decoded payload preview and occurrence details
- **AND** allow copying payload and key contents

#### Scenario: Inspecting duplicate message details
- **WHEN** the user selects a duplicated message item or activates its details action
- **THEN** the system SHALL display a duplicate details dialog presenting full decoded payload content, key, occurrence count, share percentage, and sample partition, offset, and timestamp
- **AND** provide quick copy actions for the payload and key

#### Scenario: Navigating to sample message
- **WHEN** the user triggers navigation from the duplicate details dialog for a sample message in a live session
- **THEN** the system SHALL navigate to the topic's messages view positioned at the sample partition and offset
