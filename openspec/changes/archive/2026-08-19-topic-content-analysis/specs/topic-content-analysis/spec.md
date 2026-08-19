<!-- markdownlint-disable MD041 -->
## Purpose

Provides comprehensive topic content profiling and statistical analysis for Kafka topics, including message counts, production peak hours, partition balance, tombstone detection, key distributions, and structured field frequency analysis.

## ADDED Requirements

### Requirement: Topic Message Volume and Size Aggregation

The system SHALL scan topic partitions to compute the exact total number of messages, total payload bytes, average message payload size, and minimum/maximum message sizes across all assigned partitions.

#### Scenario: Full topic volume scan

- **WHEN** the user initiates a content analysis scan on a topic
- **THEN** the system SHALL iterate through all assigned partitions from their starting offset to high watermarks
- **AND** calculate the aggregate count of messages, total payload bytes, and average payload size

#### Scenario: Empty topic scan

- **WHEN** the user initiates an analysis scan on an empty topic
- **THEN** the system SHALL immediately complete the scan and report zero messages, zero bytes, and an empty distribution summary

### Requirement: Production Peak and Hourly Distribution Analysis

The system SHALL aggregate message timestamps into 24-hour buckets (hours 00:00 through 23:00) to identify daily production peaks and volume patterns.

#### Scenario: Aggregating messages by hour of day

- **WHEN** messages with valid timestamps are scanned during topic analysis
- **THEN** the system SHALL extract the hour of the day for each message timestamp
- **AND** tally the total message count and percentage for each of the 24 hourly buckets
- **AND** present the distribution as an hourly peak production histogram

#### Scenario: Handling messages without valid timestamps

- **WHEN** scanned messages have missing or invalid timestamps (e.g. timestamp <= 0)
- **THEN** the system SHALL record these messages under an "unknown timestamp" category without failing the hourly distribution calculation

### Requirement: Partition Utilization and Balance Analysis

The system SHALL compute per-partition message counts, percentages of total topic volume, and byte sizes, identifying partition skew and unbalanced workloads.

#### Scenario: Calculating per-partition distribution

- **WHEN** topic analysis completes across multiple partitions
- **THEN** the system SHALL report the message count, byte volume, and percentage share for each individual partition
- **AND** highlight any partition that significantly deviates from even distribution (hot partitions or idle partitions)

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

### Requirement: Message Key Frequency Analysis

The system SHALL analyze message keys to identify top recurring keys, the count of null keys, and key frequency distribution.

#### Scenario: Identifying top recurring keys

- **WHEN** messages with non-null keys are scanned
- **THEN** the system SHALL track key occurrences and rank the top most frequent keys with their respective counts and percentages
- **AND** calculate the total number of records with null keys

### Requirement: Value Structure and Field Frequency Analysis

The system SHALL analyze message values to identify payload content types (JSON, Avro, Text, Binary) and, for structured JSON payloads, compute field presence frequencies and top values for categorical fields.

#### Scenario: Analyzing structured JSON payloads

- **WHEN** message values contain valid JSON objects
- **THEN** the system SHALL identify common top-level JSON fields and their occurrence frequencies
- **AND** tally top value frequencies for common identifying or categorical fields (such as `type`, `status`, `event`, or `category`)

#### Scenario: Analyzing binary or unstructured text payloads

- **WHEN** message values are binary or non-JSON text
- **THEN** the system SHALL categorize the payload format and display size statistics without failing field-level extraction

### Requirement: Analysis Scan Progress and Cancellation

The system SHALL provide real-time visual progress feedback during scanning and allow the user to cancel or pause an ongoing analysis scan at any time.

#### Scenario: Real-time scan progress feedback

- **WHEN** an analysis scan is actively running
- **THEN** the system SHALL display the number of messages scanned, partitions completed, and elapsed scan time with live updates

#### Scenario: User cancels an ongoing scan

- **WHEN** the user presses the cancel/stop button while a scan is in progress
- **THEN** the system SHALL immediately halt consumer scanning and display the partial analysis results aggregated up to the point of cancellation
