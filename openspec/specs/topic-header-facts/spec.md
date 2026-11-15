# topic-header-facts Specification

## Purpose

Shows key facts of a topic in its detail header without a full scan: an estimated message count, the timestamps of the
oldest and newest retained messages, and the retention settings in readable, localized form.

## Requirements

### Requirement: Estimated Message Count in Topic Header

The topic detail header SHALL show the sum of the per-partition offset spans (high minus low watermark) as an estimated message count, labelled as an estimate. For topics whose cleanup policy contains `compact` or is unknown, a note SHALL state that offset spans are not message counts. The value SHALL be read when the tab is first shown and on refresh, not for tabs that were never shown.

#### Scenario: Estimate for a delete-policy topic
- **WHEN** a topic with cleanup policy `delete` has three partitions with offset spans 100, 250 and 0
- **THEN** the header SHALL show about 350 messages marked as an estimate

#### Scenario: Compacted topic
- **WHEN** the topic's cleanup policy is `compact` or `compact,delete`
- **THEN** the estimate SHALL carry a note that offset spans are not message counts on compacted topics and that the topic analysis gives exact values

#### Scenario: A partition cannot be read
- **WHEN** the offsets of at least one partition could not be read
- **THEN** the estimate SHALL be shown as unknown with the reason available on hover, and SHALL NOT be shown as a partial sum or as 0
- **AND** a denied access SHALL be labelled as "not readable"

#### Scenario: Restored background tab
- **WHEN** the application restores several topic tabs and only one of them is visible
- **THEN** only the visible tab SHALL read offsets; the others SHALL read them when they are first shown

### Requirement: Oldest and Newest Retained Message Timestamps

The header SHALL offer an explicit action that reads the timestamp of the oldest and newest retained message of the topic. Per partition it SHALL read the first message at or after the low watermark and the last message before the end of the partition within a bounded tail window, under an overall time limit. The topic values SHALL be the earliest and latest of these timestamps.

#### Scenario: Reading the time range
- **WHEN** the user activates "Load time range" for a topic with two non-empty partitions
- **THEN** a progress indicator SHALL be shown while reading
- **AND** the header SHALL then show the oldest and newest message timestamp in the global time display mode with a visible zone

#### Scenario: Not read automatically
- **WHEN** a topic tab is opened or refreshed
- **THEN** no message SHALL be read for the time range until the user activates the action

#### Scenario: Empty topic
- **WHEN** every partition of the topic is empty
- **THEN** the header SHALL state that the topic holds no messages instead of showing timestamps

#### Scenario: Offset gaps at the end of a partition
- **WHEN** the tail window of a partition contains only offsets that are never delivered, for example transaction markers or compacted records
- **THEN** the newest timestamp of that partition SHALL be treated as unknown
- **AND** the topic result SHALL be marked as partial with the number of partitions that contributed

#### Scenario: Time limit reached or partition not readable
- **WHEN** the time limit is reached before some partitions delivered a message, or a partition cannot be read
- **THEN** those partitions SHALL be counted as unknown, the result SHALL be marked as partial, and the reason SHALL be available on hover
- **AND** when no partition delivered a timestamp, the values SHALL be shown as unknown, not as an empty topic

#### Scenario: Message without timestamp
- **WHEN** a probed message carries no broker timestamp
- **THEN** it SHALL NOT contribute a date derived from 0 and its partition SHALL count as unknown for that value

#### Scenario: Read fails completely
- **WHEN** the time-range read fails, for example because the broker is unreachable
- **THEN** the header SHALL show an error notice with the cause and a "Retry" action

### Requirement: Time Range Probe Stays Read-Only and Bounded

Reading the time range SHALL use manual partition assignment without consumer group membership, SHALL NOT commit or store offsets, and SHALL read at most one fetch at the low watermark and a fixed tail window per partition. End of partition SHALL be detected from the broker's end-of-partition signal, not from offset arithmetic.

#### Scenario: No offsets committed
- **WHEN** the time range of a topic was read
- **THEN** no consumer group SHALL have joined, and no offset SHALL have been committed for any group

#### Scenario: Bounded read on a large topic
- **WHEN** the time range of a topic with millions of messages per partition is read
- **THEN** the read SHALL fetch only the first messages at the low watermark and the messages of the tail window per partition, and SHALL end within the time limit

### Requirement: Localized Retention Settings in Topic Header

The header SHALL show the topic's `retention.ms` as a localized duration in days, hours and minutes and `retention.bytes` as a human-readable size per partition. The value `-1` SHALL be shown as unlimited. Values that are missing SHALL be shown as unknown, and values whose read was denied SHALL be shown as not readable. The same duration format SHALL be used in the topic list tooltip.

#### Scenario: Retention in days and hours
- **WHEN** `retention.ms` is `129600000`
- **THEN** the header SHALL show "1 day 12 hours" in English and "1 Tag 12 Stunden" in German

#### Scenario: Retention below one day
- **WHEN** `retention.ms` is `5400000`
- **THEN** the header SHALL show "1 hour 30 minutes" in English

#### Scenario: Unlimited retention
- **WHEN** `retention.ms` or `retention.bytes` is `-1`
- **THEN** the corresponding value SHALL be shown as unlimited

#### Scenario: Retention bytes per partition
- **WHEN** `retention.bytes` is `1073741824`
- **THEN** the header SHALL show the size as 1.00 GB with the note that it applies per partition

#### Scenario: Configuration not readable
- **WHEN** reading the topic configuration fails or is denied
- **THEN** both retention values SHALL be shown as unknown or not readable, and SHALL NOT be shown as 0 or as unlimited

#### Scenario: Unparsable value
- **WHEN** a retention value is not a number
- **THEN** the header SHALL show the raw value as reported by the broker

### Requirement: Localized Partition and Replication Tags

The partition count and replication factor tags in the topic header SHALL be rendered from localized strings.

#### Scenario: German header tags
- **WHEN** the application runs under German locale and the topic has 3 partitions with replication factor 2
- **THEN** the header tags SHALL show the localized German partition and replication factor labels
