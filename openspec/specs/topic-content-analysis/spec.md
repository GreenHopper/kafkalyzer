# topic-content-analysis Specification

## Purpose

Provides comprehensive topic content profiling and statistical analysis for Kafka topics, including message counts, production peak hours, partition balance, tombstone detection, key distributions, and structured field frequency analysis.

## Requirements

### Requirement: Topic Message Volume and Size Aggregation

The system SHALL scan topic partitions to compute the exact total number of messages, total payload bytes, average message payload size, minimum and maximum message sizes, and the 50th, 95th and 99th percentile of message payload size across all assigned partitions.

#### Scenario: Full topic volume scan

- **WHEN** the user initiates a content analysis scan on a topic
- **THEN** the system SHALL iterate through all assigned partitions from their starting offset to high watermarks
- **AND** calculate the aggregate count of messages, total payload bytes, and average payload size

#### Scenario: Empty topic scan

- **WHEN** the user initiates an analysis scan on an empty topic
- **THEN** the system SHALL immediately complete the scan and report zero messages, zero bytes, and an empty distribution summary

#### Scenario: Percentile size summary

- **WHEN** a content analysis scan completes over messages whose payload sizes vary
- **THEN** the report SHALL show the 50th, 95th and 99th percentile payload size in bytes
- **AND** each percentile value SHALL lie between the reported minimum and maximum payload size

#### Scenario: Percentiles on a single message

- **WHEN** a content analysis scan completes over exactly one message
- **THEN** the 50th, 95th and 99th percentile SHALL equal that message payload size
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

#### Scenario: Cleanup policy cannot be read

- **WHEN** the topic configuration cannot be read during the analysis, for example because describing configurations is denied or times out
- **THEN** the analysis SHALL still count tombstones
- **AND** the report SHALL show the cleanup policy as unknown ("not readable") instead of "delete" or "compact"

#### Scenario: Reports saved before the cleanup policy could be unknown

- **WHEN** the user imports or compares a report saved by an earlier version that has no unknown-cleanup-policy marker
- **THEN** the report SHALL load and show its stored cleanup policy as before

### Requirement: Read-only Cleanup Policy Lookup

The analysis SHALL read the topic's cleanup policy with a read-only configuration describe request and SHALL NOT change any topic or configuration. A failed lookup SHALL NOT stop the scan.

#### Scenario: Lookup denied
- **WHEN** describing the topic configuration is denied
- **THEN** the scan SHALL run to completion and the cleanup policy SHALL be reported as unknown

#### Scenario: No write request
- **WHEN** the read-only verification script runs on the analysis code
- **THEN** it SHALL pass without a new exception

### Requirement: Message Key Frequency Analysis

The system SHALL analyze message keys to identify top recurring keys, the count of null keys, key frequency distribution, and an estimate of how many distinct keys occur in the scanned range.

#### Scenario: Identifying top recurring keys

- **WHEN** messages with non-null keys are scanned
- **THEN** the system SHALL track key occurrences and rank the top most frequent keys with their respective counts and percentages
- **AND** calculate the total number of records with null keys

#### Scenario: Distinct key estimate

- **WHEN** a scan covers 100000 messages carrying 400 different key values
- **THEN** the report SHALL show an estimated distinct key count
- **AND** the estimate SHALL be labeled as an estimate rather than an exact count

#### Scenario: All keys null

- **WHEN** every scanned message has a null key
- **THEN** the distinct key estimate SHALL be zero
- **AND** the null key count SHALL equal the scanned message count
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

### Requirement: Analysis Scan Progress and Cancellation

The system SHALL provide real-time visual progress feedback during scanning, including a remaining time estimate, and allow the user to cancel or pause an ongoing analysis scan at any time.

#### Scenario: Real-time scan progress feedback

- **WHEN** an analysis scan is actively running
- **THEN** the system SHALL display the number of messages scanned out of total messages to scan, the percentage progress, the current throughput in messages per second, and an estimated remaining time with live updates

#### Scenario: Estimated remaining time display

- **WHEN** an analysis scan is actively running and a total message count is known
- **THEN** the system SHALL compute and display an estimated remaining time based on the current scan throughput and the number of messages remaining to scan
- **AND** the estimate SHALL update in real time as the scan progresses
- **AND** the estimate SHALL be displayed in a human-readable format (e.g. "~45 s" for under one minute, "~3 m" for minutes)

#### Scenario: Indeterminate remaining time when total is unknown

- **WHEN** an analysis scan is actively running but the total number of messages to scan is not yet known
- **THEN** the system SHALL display the current throughput in messages per second without a specific remaining time estimate
- **AND** the progress bar SHALL display in indeterminate (indeterminate sweep) mode

#### Scenario: User cancels an ongoing scan

- **WHEN** the user presses the cancel/stop button while a scan is in progress
- **THEN** the system SHALL immediately halt consumer scanning and display the partial analysis results aggregated up to the point of cancellation

### Requirement: Decoupled Progress Reporting

Topic analysis SHALL track scan counts, byte volumes, and partition progress via lightweight atomic counters, emitting periodic progress reports without cloning full nested accumulator maps on every tick.

#### Scenario: Progress reporting during active scan

- **WHEN** topic content analysis is actively scanning messages
- **THEN** progress updates emitted every 250ms are computed using atomic message and byte counters
- **AND** the system does not clone or deep-merge the entire 100k+ entry accumulator state on every 250ms progress interval
- **AND** full analytical reports are synthesized only upon scan completion or user cancellation

### Requirement: Low-Latency Worker Partition Polling

Worker threads scanning multiple partition queues SHALL employ non-blocking polling and adaptive yield backoff without executing unconditional thread sleep delays on active queues.

#### Scenario: Multi-partition worker queue draining

- **WHEN** a worker thread polls multiple partition queues during content analysis
- **THEN** it does not inject fixed 5ms thread sleeps between consecutive polls when data is flowing or awaiting immediate fetch
- **AND** yields execution cooperatively only when all assigned queues are idle

### Requirement: Configurable Analysis Scope

Before starting an analysis the user SHALL be able to limit its scope by a time range (start and/or end moment), by a subset of partitions and by a free message count taken from the newest or the oldest end of each selected partition. The options SHALL be combinable. Without any limit the analysis SHALL be a full scan of all partitions, which stays the default.

#### Scenario: Default scope is a full scan

- **WHEN** the user opens the analysis of a topic and starts it without changing the scope
- **THEN** the analysis SHALL scan every partition from its earliest retained offset to the log end at scan start

#### Scenario: Time range

- **WHEN** the user sets the scope to the range 2026-11-20 14:00 to 2026-11-20 16:00 local time and starts the analysis
- **THEN** every partition SHALL be read only from the first offset whose timestamp is at or after 14:00 up to, but excluding, the first offset whose timestamp is at or after 16:00, both resolved before reading starts
- **AND** messages inside that offset range whose timestamp lies outside the range, or that have no valid timestamp, SHALL be excluded from all statistics and counted as excluded by the time range

#### Scenario: Open-ended time range

- **WHEN** the user sets only a start moment
- **THEN** each partition SHALL be read from the resolved start offset to the log end at scan start

#### Scenario: Start moment after the newest message

- **WHEN** a partition contains no message with a timestamp at or after the start moment
- **THEN** that partition SHALL be reported as containing no messages in the range, not as unreadable

#### Scenario: Partition subset

- **WHEN** the user selects partitions 0 and 3 of a 6-partition topic
- **THEN** only partitions 0 and 3 SHALL be read
- **AND** the report SHALL list only partitions 0 and 3 in the partition statistics

#### Scenario: Newest message count

- **WHEN** the user requests the newest 10,000 messages of a topic with 4 partitions of which each holds more than 2,500 offsets
- **THEN** each partition SHALL be read from 2,500 offsets before its log end to its log end

#### Scenario: Count larger than a small partition

- **WHEN** the user requests the newest 10,000 messages of a topic whose partition 0 holds only 1,000 offsets and whose partition 1 holds 50,000 offsets
- **THEN** partition 0 SHALL be read completely and partition 1 SHALL be read for its newest 9,000 offsets

#### Scenario: Oldest message count

- **WHEN** the user requests the oldest 5,000 messages of a single-partition topic
- **THEN** the partition SHALL be read from its earliest retained offset for 5,000 offsets

#### Scenario: Count combined with time range

- **WHEN** the user requests the newest 1,000 messages within the last 24 hours
- **THEN** the count SHALL be applied inside the offset range resolved for the time range

#### Scenario: Invalid scope rejected

- **WHEN** the end moment is not after the start moment, the message count is not positive, or no partition is selected
- **THEN** the analysis SHALL NOT start
- **AND** the view SHALL show a localized explanation next to the scope controls

#### Scenario: Time range cannot be resolved

- **WHEN** the broker cannot resolve the start or end moment to offsets
- **THEN** the analysis SHALL fail with a visible error naming the time range
- **AND** it SHALL NOT fall back to a full scan or to offset 0

### Requirement: Confirmation Before Large Scans

Before a scan whose estimated size exceeds the configured threshold, or whose size cannot be estimated, the system SHALL show the estimated number of offsets to read, labelled as an estimate derived from offset spans, and SHALL start only after the user confirms. The threshold SHALL be a setting with a default of 1,000,000 offsets.

#### Scenario: Large full scan asks first

- **WHEN** the user starts a full scan of a topic whose offset spans add up to 25,000,000
- **THEN** a dialog SHALL show about 25,000,000 offsets as an estimate and offer to start or cancel
- **AND** no message SHALL be read before the user confirms

#### Scenario: Small scope starts directly

- **WHEN** the estimated size is at or below the threshold, or the scope is a message count at or below the threshold
- **THEN** the analysis SHALL start without a confirmation dialog

#### Scenario: Compacted topic hint

- **WHEN** the confirmation dialog is shown for a topic whose cleanup policy contains `compact`
- **THEN** the dialog SHALL state that compacted topics contain fewer messages than their offset span

#### Scenario: Estimate incomplete

- **WHEN** the offsets of some selected partitions cannot be read
- **THEN** the dialog SHALL show the known part as "at least" the summed span and name the unreadable partitions
- **AND** SHALL NOT present the unknown part as zero

#### Scenario: Estimate fails

- **WHEN** the estimate cannot be obtained at all
- **THEN** the dialog SHALL show that the size is unknown together with the error and still offer to start or cancel

#### Scenario: Estimate in progress

- **WHEN** the estimate is being obtained after the user pressed start
- **THEN** the view SHALL show a progress indication and the start action SHALL be disabled until the estimate finished

#### Scenario: Cancel in the dialog

- **WHEN** the user cancels the confirmation dialog
- **THEN** no analysis SHALL start and the previously displayed report SHALL stay displayed

### Requirement: Analysis Scope Recorded In The Report

The report SHALL record the requested scope, the planned offset range of every read partition, the partitions that could not be read with the reason, and the number of messages excluded by the time range, and the dashboard SHALL show this scope summary. A partition whose offsets cannot be read SHALL be reported as not readable, never as empty.

#### Scenario: Scope summary on the dashboard

- **WHEN** an analysis of the newest 10,000 messages of partitions 0 and 3 completes
- **THEN** the dashboard SHALL show the mode "newest 10,000", the selected partitions and the planned offset range per partition

#### Scenario: Unreadable partition

- **WHEN** the watermarks of partition 2 cannot be read at scan start
- **THEN** the analysis SHALL read the remaining partitions
- **AND** the report SHALL list partition 2 as not readable with the reason instead of reporting 0 messages for it

#### Scenario: No partition readable

- **WHEN** no selected partition can be read at scan start
- **THEN** the analysis SHALL end with a visible error and SHALL NOT show an empty report

#### Scenario: Excluded by time range

- **WHEN** a time-range scan read 12 messages whose timestamps lie outside the range
- **THEN** the scope summary SHALL show 12 messages excluded by the time range

### Requirement: Disclosed Analysis Limits

Every report SHALL list the internal limits that shaped it: tracked and listed fields, tracked and listed values per field, field nesting depth, value display length, tracked and listed keys, size-percentile sample size, tracked duplicate fingerprints, duplicate samples and listed duplicates. For each limit the report SHALL state its value and whether this scan reached it.

#### Scenario: Limits section

- **WHEN** an analysis report is displayed
- **THEN** a limits section SHALL list each limit with its value and a reached or not reached state

#### Scenario: Field limit reached

- **WHEN** the scanned payloads contain more distinct field paths than the analysis tracks
- **THEN** the field limit SHALL be marked as reached
- **AND** the field frequency section SHALL state that further fields were not tracked

#### Scenario: Depth limit reached

- **WHEN** a payload nests objects deeper than the depth limit
- **THEN** the depth limit SHALL be marked as reached

#### Scenario: Listed fields fewer than tracked fields

- **WHEN** 437 field paths were tracked and only the top 100 are listed
- **THEN** the field frequency section SHALL state that 100 of 437 fields are shown

#### Scenario: Report without limit information

- **WHEN** the displayed report does not contain limit information
- **THEN** the limits section SHALL show a localized "not available for this report" notice instead of values

### Requirement: Topic Analysis Stays Read-Only

Scope estimation and topic analysis SHALL only read: metadata, watermarks and timestamp-to-offset lookups, and messages through manually assigned partitions without committing offsets or joining a consumer group. They SHALL NOT write to Kafka or the Schema Registry.

#### Scenario: Time-range analysis

- **WHEN** the user runs an estimate and then a time-range analysis
- **THEN** the system SHALL issue only metadata, watermark, timestamp-to-offset and fetch requests
- **AND** no offset SHALL be committed for the analysis consumer
