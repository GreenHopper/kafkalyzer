## ADDED Requirements

### Requirement: Estimated Partition Offset Distribution

The partition health view opened from the topic detail view SHALL show, per partition, the low watermark, the high watermark, the offset span (high minus low) and the span's share of the topic's total span as a bar with a percentage. The block SHALL be labelled as an estimate. Shares SHALL only be shown when every partition's offsets are known and the total span is greater than zero.

#### Scenario: Distribution of a readable topic

- **WHEN** the user opens the partition health view for a topic with partitions 0 (low 0, high 600) and 1 (low 100, high 500)
- **THEN** partition 0 SHALL show low 0, high 600, span 600 and a share of 60 %
- **AND** partition 1 SHALL show low 100, high 500, span 400 and a share of 40 %
- **AND** the block SHALL be titled as an estimate

#### Scenario: Empty topic

- **WHEN** every partition has a low watermark equal to its high watermark
- **THEN** every span SHALL be shown as 0
- **AND** no share bar or percentage SHALL be shown
- **AND** the view SHALL state that the topic currently retains no offsets

#### Scenario: Offsets of one partition unreadable

- **WHEN** the offsets of partition 2 cannot be read and the other partitions are readable
- **THEN** the row of partition 2 SHALL show its low watermark, high watermark, span and share as unknown together with the error text
- **AND** the other rows SHALL show their offsets and spans
- **AND** no share SHALL be shown for any partition and the view SHALL state that shares need all partitions

#### Scenario: Missing permission for a partition

- **WHEN** reading a partition's offsets fails because the user is not authorized for the topic
- **THEN** that row SHALL be marked "not readable" with a hint to check permissions
- **AND** its values SHALL be shown as unknown, never as 0

#### Scenario: Topic metadata unavailable

- **WHEN** the partition list of the topic cannot be read or the broker is unreachable
- **THEN** the block SHALL show an inline error with a retry action
- **AND** no partition row SHALL show offsets, spans or shares

### Requirement: Offset Spans Are Not Message Counts

The offset distribution SHALL state that offset spans are estimates and SHALL offer an action that opens the topic analysis for exact per-partition message counts. When the topic's cleanup policy contains `compact`, it SHALL state that spans are not message counts for this topic. When the cleanup policy is unknown, it SHALL say that the cleanup policy is unknown.

#### Scenario: Compacted topic

- **WHEN** the offset distribution is shown for a topic whose cleanup policy is `compact,delete`
- **THEN** the view SHALL state that the topic is compacted and offset spans are not message counts

#### Scenario: Delete-only topic

- **WHEN** the cleanup policy is `delete`
- **THEN** no compaction note SHALL be shown
- **AND** the estimate label SHALL still be shown

#### Scenario: Cleanup policy unknown

- **WHEN** the cleanup policy of the topic was not read or could not be read
- **THEN** the view SHALL state that the cleanup policy is unknown and that spans may not be message counts

#### Scenario: Open topic analysis for exact values

- **WHEN** the user activates the exact-values action in the offset distribution
- **THEN** the partition health view SHALL close and the topic's analysis view SHALL open
- **AND** no analysis scan SHALL start without the user starting it

### Requirement: Offset Distribution Skew Hint

The offset distribution SHALL show a skew badge with an icon and text naming each partition whose share is above the configured partition skew threshold. The badge SHALL only be evaluated when the topic has at least two partitions, every partition's offsets are known and the total span is greater than zero. The badge SHALL be labelled as an estimate and SHALL NOT rely on colour alone.

#### Scenario: Hot partition above the default threshold

- **WHEN** the threshold is 50 % and partitions 0, 1 and 2 have spans 700, 200 and 100
- **THEN** a skew badge SHALL name partition 0 with a share of 70 %
- **AND** the row of partition 0 SHALL be marked with an icon in addition to colour

#### Scenario: Share equal to the threshold

- **WHEN** the threshold is 50 % and two partitions each have span 500
- **THEN** no skew badge SHALL be shown

#### Scenario: Single partition topic

- **WHEN** the topic has exactly one partition
- **THEN** no skew badge SHALL be shown even though that partition holds 100 % of the span

#### Scenario: Empty or partially readable topic

- **WHEN** the total span is 0 or at least one partition's offsets are unknown
- **THEN** no skew badge SHALL be shown
- **AND** the view SHALL NOT state that the topic is balanced

#### Scenario: Changed threshold

- **WHEN** the user sets the partition skew threshold to 80 % and reopens the partition health view for partitions with spans 700, 200 and 100
- **THEN** no skew badge SHALL be shown

### Requirement: Offset Distribution Loads On Demand

Partition offsets SHALL be read only when the user opens the partition health view from the topic detail view or refreshes it there. The topic list, the sidebar and the analysis tab's partition health card SHALL NOT read partition offsets. Reading SHALL show progress, SHALL use bounded parallelism and an overall time limit, and SHALL show when the values were read.

#### Scenario: Topic list stays offset-free

- **WHEN** the topic list is loaded or refreshed for a cluster
- **THEN** no partition offsets SHALL be read

#### Scenario: Opening the view reads offsets once

- **WHEN** the user opens the partition health view for a topic
- **THEN** the offsets of every partition SHALL be read once and a progress indicator SHALL be shown until they arrive
- **AND** the view SHALL show the time the offsets were read

#### Scenario: Refresh rereads offsets

- **WHEN** the user triggers refresh in the partition health view
- **THEN** the offsets SHALL be read again and the shown values and read time SHALL be replaced

#### Scenario: Topic with many partitions exceeds the time limit

- **WHEN** reading the offsets of a topic with many partitions does not finish within the overall time limit
- **THEN** the partitions read so far SHALL show their offsets
- **AND** every remaining partition SHALL show its values as unknown with a timeout error
- **AND** no share or skew badge SHALL be shown

#### Scenario: Stale values after disconnect

- **WHEN** the cluster connection is closed while offsets are shown
- **THEN** the shown offsets SHALL NOT be presented as current values

### Requirement: Offset Distribution Reads Stay Read-Only

Reading partition offsets SHALL use only metadata and offset lookups. It SHALL NOT join a consumer group, subscribe, assign, commit offsets, read configuration or change any topic, partition or group.

#### Scenario: Offsets read without side effects

- **WHEN** the partition health view reads offsets for a topic
- **THEN** no consumer group SHALL be created or joined and no offset SHALL be committed
- **AND** the read-only CI gate SHALL pass without a new exception
