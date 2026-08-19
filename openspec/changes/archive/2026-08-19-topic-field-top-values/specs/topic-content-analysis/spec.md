<!-- markdownlint-disable MD041 -->
## MODIFIED Requirements

### Requirement: Value Structure and Field Frequency Analysis

The system SHALL analyze message values to identify payload content types (JSON, Avro, Text, Binary) and, for structured JSON and Avro payloads, compute field presence frequencies, distinct value counts, and the Top 10 most frequent values per field.

#### Scenario: Analyzing structured JSON payloads

- **WHEN** message values contain valid structured JSON or decoded Avro objects
- **THEN** the system SHALL extract all top-level fields and calculate their occurrence counts and presence percentages
- **AND** tally and rank the Top 10 most frequent values for each discovered field with their respective occurrence counts and percentage shares

#### Scenario: Exploring field values interactively

- **WHEN** the user selects or inspects a field in the analysis dashboard
- **THEN** the system SHALL display the ranked Top 10 values list for that field with visual frequency distribution bars and quick copy actions

#### Scenario: Analyzing binary or unstructured text payloads

- **WHEN** message values are binary or non-JSON text
- **THEN** the system SHALL categorize the payload format and display size statistics without failing field-level extraction
