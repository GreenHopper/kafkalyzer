# Spec Delta

## Purpose

Enables detection and analysis of duplicate messages during topic content analysis, allowing users to measure message redundancy and inspect the most frequently duplicated messages.

## ADDED Requirements

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

The analysis report SHALL rank the top most frequent duplicated messages (up to 20) with their occurrence count, percentage share of total messages, key preview (if present), payload preview (shortened if exceeding length limits), and sample metadata (partition, offset, timestamp).

#### Scenario: Inspecting top duplicated messages
- **WHEN** an analysis finishes on a topic that contains duplicate messages
- **THEN** the system SHALL display the ranked list of top duplicated messages with their occurrence count, percentage share, and payload preview
- **AND** provide sample partition, offset, and timestamp for inspection

#### Scenario: Payload preview truncation
- **WHEN** a duplicated message payload exceeds 120 characters
- **THEN** the preview SHALL be shortened for display without failing analysis

### Requirement: Bounded Memory Tracking

To support scanning large topics with millions of messages, duplicate message tracking SHALL use memory-efficient fingerprint hashing and enforce bounded tracking structures for top duplicate samples.

#### Scenario: High volume scan
- **WHEN** a scan processes hundreds of thousands or millions of messages
- **THEN** duplicate tracking SHALL operate via compact hash representations without storing full payload copies of non-duplicate messages in memory

### Requirement: Duplicate Analysis Dashboard Presentation

The topic analysis view SHALL present duplicate analysis metrics in a dedicated summary card and provide a section to inspect the top duplicated messages with copy actions.

#### Scenario: Summary card display
- **WHEN** topic analysis results are loaded in the view
- **THEN** a summary card SHALL display the duplicate message count and duplicate rate percentage

#### Scenario: Viewing top duplicates list
- **WHEN** duplicate messages were detected
- **THEN** the report view SHALL render the top duplicated messages list with payload preview and occurrence details
- **AND** allow copying payload and key contents
