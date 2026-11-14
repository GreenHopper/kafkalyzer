# Spec Delta

## MODIFIED Requirements

### Requirement: Tombstone Detection and Compaction Analysis

The system SHALL detect tombstone records (messages with null or empty payload) and correlate tombstone counts with the topic's cleanup policy.

#### Scenario: Detecting tombstones on a compacted topic

- **WHEN** scanning a topic whose cleanup policy includes `compact`
- **THEN** the system SHALL identify all records with null or zero-length payloads as tombstones
- **AND** calculate the total tombstone count and the tombstone percentage relative to total messages
- **AND** prominently display the tombstone ratio alongside the topic's cleanup policy

#### Scenario: Scanning a delete-retention topic without tombstones

- **WHEN** scanning a topic where no records have null payloads
- **THEN** the system SHALL report zero tombstones and a 0% tombstone ratio

#### Scenario: Cleanup policy cannot be read

- **WHEN** the topic configuration cannot be read during the analysis, for example because describing configurations is denied or times out
- **THEN** the analysis SHALL still count tombstones
- **AND** the report SHALL show the cleanup policy as unknown ("not readable") instead of "delete" or "compact"

#### Scenario: Reports saved before the cleanup policy could be unknown

- **WHEN** the user imports or compares a report saved by an earlier version that has no unknown-cleanup-policy marker
- **THEN** the report SHALL load and show its stored cleanup policy as before

## ADDED Requirements

### Requirement: Read-only Cleanup Policy Lookup

The analysis SHALL read the topic's cleanup policy with a read-only configuration describe request and SHALL NOT change any topic or configuration. A failed lookup SHALL NOT stop the scan.

#### Scenario: Lookup denied
- **WHEN** describing the topic configuration is denied
- **THEN** the scan SHALL run to completion and the cleanup policy SHALL be reported as unknown

#### Scenario: No write request
- **WHEN** the read-only verification script runs on the analysis code
- **THEN** it SHALL pass without a new exception
