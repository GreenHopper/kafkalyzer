# Spec Delta

## MODIFIED Requirements

### Requirement: Value Structure and Field Frequency Analysis

The system SHALL analyze message values to identify payload content types (JSON, Avro, Text, Binary) and, for structured JSON and Avro payloads, compute field presence frequencies, distinct value counts, and the Top 10 most frequent values per field. Fields nested in objects, records and maps SHALL be reported under their field path in the canonical field-path syntax, and a field whose distinct-value tracking reached its limit SHALL be marked so its value counts are shown as approximate.

#### Scenario: Analyzing structured JSON payloads

- **WHEN** message values contain valid structured JSON or decoded Avro objects
- **THEN** the system SHALL extract all top-level fields and calculate their occurrence counts and presence percentages
- **AND** tally and rank the Top 10 most frequent values for each discovered field with their respective occurrence counts and percentage shares

#### Scenario: Analyzing nested object and map fields

- **WHEN** a message value is `{"order":{"id":"A1"},"attributes":{"region":"EU","channel":"web"}}`
- **THEN** the field frequencies SHALL contain `order`, `order.id`, `attributes`, `attributes.region` and `attributes.channel`
- **AND** the Top 10 values of `attributes.region` SHALL include `EU`

#### Scenario: Nested key that is not representable in dot notation

- **WHEN** a nested map contains a key with a `.`, `/`, `[` or `]` character, such as `{"labels":{"app.kubernetes.io/name":"api"}}`
- **THEN** the field SHALL be reported with a JSON Pointer path (`/labels/app.kubernetes.io~1name`) that resolves to the same value when used in a value filter or projected column

#### Scenario: Nesting depth limit

- **WHEN** a payload nests objects deeper than 5 levels
- **THEN** fields up to 5 levels SHALL be reported
- **AND** deeper levels SHALL be counted only as presence of the level-5 field without failing the analysis

#### Scenario: Arrays are not descended

- **WHEN** a field holds an array
- **THEN** the field SHALL be counted for presence
- **AND** the array elements SHALL NOT be reported as separate field paths

#### Scenario: Approximate value counts

- **WHEN** a field shows more distinct values than the analysis tracks per field
- **THEN** the field SHALL be marked as capped in the report
- **AND** the field value explorer SHALL label that field's value counts as approximate

#### Scenario: Long string values

- **WHEN** a string field value is longer than 80 characters, including values with multi-byte characters
- **THEN** the value SHALL be shortened for display at a character boundary and marked as shortened without failing the analysis

#### Scenario: Exploring field values interactively

- **WHEN** the user selects or inspects a field in the analysis dashboard
- **THEN** the system SHALL display the ranked Top 10 values list for that field with visual frequency distribution bars and quick copy actions

#### Scenario: Analyzing binary or unstructured text payloads

- **WHEN** message values are binary or non-JSON text
- **THEN** the system SHALL categorize the payload format and display size statistics without failing field-level extraction
