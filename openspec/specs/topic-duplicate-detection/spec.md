# topic-duplicate-detection Specification

## Purpose

Enables detection and analysis of duplicate messages during topic content analysis, allowing users to measure message redundancy and inspect the most frequently duplicated messages.

## Requirements

### Requirement: Configurable Duplicate Scope Before Scan

Before initiating a topic analysis, the user SHALL be able to configure the equality scope used for duplicate message detection: Payload (Value) only or Key + Payload combination. The default scope SHALL be Payload only.

#### Scenario: Default duplicate scope
- **WHEN** the user initiates an analysis scan without altering the duplicate configuration
- **THEN** the analyzer SHALL evaluate duplicate messages based on message payload equality

#### Scenario: Key and Payload duplicate scope selected
- **WHEN** the user selects the Key + Payload scope before starting an analysis
- **THEN** two messages SHALL only be counted as duplicates if both their keys and their payloads are identical

### Requirement: Duplicate Message Identification

During the topic analysis scan, the system SHALL evaluate each message against previously scanned messages according to the selected duplicate scope. Two messages SHALL be recognized as duplicates if their evaluated components are identical.

#### Scenario: Identical payloads with different keys
- **WHEN** the duplicate scope is Payload only and two messages have identical payloads but different or null keys
- **THEN** the second message SHALL be counted as a duplicate

#### Scenario: Identical payloads with different keys under Key + Payload scope
- **WHEN** the duplicate scope is Key + Payload and two messages have identical payloads but different keys
- **THEN** the second message SHALL NOT be counted as a duplicate

#### Scenario: Tombstone records
- **WHEN** multiple tombstone records (null/empty payloads) are scanned
- **THEN** they SHALL be evaluated for duplication according to the active scope

### Requirement: Duplicate Analysis Summary Metrics

The completed topic analysis report SHALL include duplicate detection summary metrics: total scanned messages, unique message count, duplicate message count, and the duplicate rate percentage.

#### Scenario: Topic with duplicates
- **WHEN** a scan completes over 10,000 messages where 8,500 are unique and 1,500 are duplicate occurrences
- **THEN** the report SHALL indicate 8,500 unique messages, 1,500 duplicate messages, and a 15.0 % duplicate rate

#### Scenario: Topic without duplicates
- **WHEN** a scan completes over 5,000 messages where all messages are distinct
- **THEN** the report SHALL indicate 5,000 unique messages, 0 duplicate messages, and a 0.0 % duplicate rate

#### Scenario: Empty topic
- **WHEN** a scan completes over an empty topic
- **THEN** unique messages SHALL be 0, duplicate messages SHALL be 0, and the duplicate rate SHALL be 0.0 %

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

### Requirement: Bounded Memory Tracking

To support scanning large topics with millions of messages, duplicate message tracking SHALL use memory-efficient fingerprint hashing and enforce bounded tracking structures for top duplicate samples. The set of tracked fingerprints SHALL have a fixed upper limit, SHALL NOT be copied for intermediate progress results, and reaching the limit SHALL mark the duplicate figures as estimated.

#### Scenario: High volume scan
- **WHEN** a scan processes hundreds of thousands or millions of messages
- **THEN** duplicate tracking SHALL operate via compact hash representations without storing full payload copies of non-duplicate messages in memory

#### Scenario: Fingerprint limit not reached
- **WHEN** a scan sees fewer distinct messages than the fingerprint limit
- **THEN** the unique and duplicate counts SHALL be exact
- **AND** the duplicate figures SHALL NOT be marked as estimated

#### Scenario: Fingerprint limit reached
- **WHEN** a scan sees more distinct messages than the fingerprint limit
- **THEN** the number of tracked fingerprints SHALL NOT exceed the limit
- **AND** messages whose fingerprint could no longer be tracked SHALL be counted as unique
- **AND** the duplicate summary card and the duplicate section SHALL label the duplicate count and rate as an estimate that is a lower bound, together with the number of untracked messages

#### Scenario: Duplicate sample table full
- **WHEN** more distinct duplicated messages occur than the duplicate sample table holds
- **THEN** the top duplicated messages list SHALL be labelled as possibly incomplete

#### Scenario: Duplicates across partitions read in parallel
- **WHEN** two identical messages are stored in different partitions that are read by different scan workers
- **THEN** the second message SHALL be counted as a duplicate

#### Scenario: Older report without estimate information
- **WHEN** the displayed report does not contain fingerprint limit information
- **THEN** the duplicate figures SHALL be shown without the estimate label

### Requirement: Duplicate Analysis Dashboard Presentation

The topic analysis view SHALL present duplicate analysis metrics in a dedicated summary card and provide a section to inspect the top duplicated messages with interactive drill-down, copy actions, and seamless navigation into filtered message views.

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

#### Scenario: Filtering duplicate occurrences across topic partitions
- **WHEN** the user triggers the action to show duplicate occurrences in the messages view from the duplicate details dialog
- **THEN** the system SHALL switch to the topic's messages view
- **AND** pre-populate the quick filter text with the duplicate key when present, or an excerpt/content from the payload preview when unkeyed
- **AND** set the search scope to `key` for keyed duplicates and `value` for unkeyed duplicates
- **AND** set the filter type to `exact` for key matching and `contains` for payload matching
- **AND** clear partition restrictions so message consumption spans all topic partitions
- **AND** configure the scan mode to `offsetEarliest` starting from offset 0 with an adequate result limit
- **AND** initiate message streaming to isolate and display the duplicate messages
