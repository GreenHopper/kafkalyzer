## ADDED Requirements

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
