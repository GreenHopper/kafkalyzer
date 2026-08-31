## ADDED Requirements

### Requirement: Fair Result Limit Across Partitions
When a result limit of $N$ matching messages is configured and more than one partition is assigned, the consumer SHALL distribute that limit across assigned partitions as evenly as possible, rather than filling the entire limit from whichever partition delivers first. Unused quota from partitions that have no (further) matching messages in the selected offset or time range SHALL be redistributed to remaining active partitions until the global limit is reached or all assigned partitions are exhausted. The global limit $N$ remains a hard ceiling on total emitted matches.

#### Scenario: Even distribution when all partitions have enough matches
- **WHEN** message consumption begins on a topic with $P$ assigned partitions ($P > 1$)
- **AND** a result limit of $N$ matching messages is configured
- **AND** each assigned partition has at least $\lceil N / P \rceil$ matching messages in the selected range
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL emit at most $N$ matching messages in total
- **AND** the count of matching messages emitted per partition SHALL differ by at most 1
- **AND** every assigned partition SHALL contribute at least $\lfloor N / P \rfloor$ matching messages

#### Scenario: Redistributing unused quota from empty partitions
- **WHEN** message consumption begins with a result limit of $N$ across $P$ assigned partitions ($P > 1$)
- **AND** one or more partitions have no matching messages in the selected offset or time range
- **AND** the remaining partitions collectively have enough matching messages to fill $N$
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL still emit up to $N$ matching messages from the partitions that have matches
- **AND** SHALL NOT leave unused quota stranded on empty partitions

#### Scenario: Single-partition selection keeps full limit on that partition
- **WHEN** the user explicitly selects a single partition
- **AND** a result limit of $N$ is configured
- **THEN** the consumer SHALL apply the full limit $N$ to that partition alone
- **AND** SHALL NOT attempt cross-partition redistribution

#### Scenario: Unlimited reads are unchanged
- **WHEN** no result limit is configured
- **THEN** the consumer SHALL continue reading across all assigned partitions until stop conditions are met
- **AND** SHALL NOT enforce per-partition match quotas

## MODIFIED Requirements

### Requirement: Tail Offset Resolution for Latest Start Strategy
The message consumer SHALL support starting consumption from the tail of a topic by computing partition start offsets from watermarks and the configured result limit. When multiple partitions are assigned and a limit of $N$ matching messages is configured, each assigned partition's start offset SHALL be resolved using that partition's share of $N$ (as evenly as possible across $P$ partitions), not the full global limit $N$ on every partition. When a single partition is assigned, the full limit $N$ SHALL be used for that partition's tail seek.

#### Scenario: Consuming latest messages from an inactive topic with bounded end
- **WHEN** message consumption begins on a topic with start strategy set to `Latest`
- **AND** a limit of $N$ messages (e.g. 200) is configured
- **AND** $P$ partitions are assigned ($P > 1$)
- **AND** `run_forever` is `false` (Stop condition `End`)
- **THEN** the consumer SHALL resolve the start offset for each assigned partition to `max(low_watermark, high_watermark - share_p)` where `share_p` is that partition's even share of $N$ (floor/ceil split so shares sum to $N$)
- **AND** seek each assigned partition to its resolved start offset
- **AND** poll and emit matching messages under the fair per-partition quotas until the global limit $N$ or partition high watermarks are reached
- **AND** emit `__EOF__` and terminate when the high watermarks or the result limit is reached

#### Scenario: Consuming latest messages with a single selected partition
- **WHEN** message consumption begins with start strategy set to `Latest`
- **AND** a limit of $N$ messages is configured
- **AND** exactly one partition is assigned
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL resolve that partition's start offset to `max(low_watermark, high_watermark - N)`
- **AND** emit up to $N$ matching messages from that partition

#### Scenario: Consuming latest messages on an empty topic
- **WHEN** message consumption begins with start strategy set to `Latest` on a topic where `low_watermark == high_watermark` across all partitions
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL compute `total_to_scan` as `0`
- **AND** immediately emit `__PROGRESS__:0:0` and `__EOF__` without entering polling delays

#### Scenario: Consuming latest messages in live streaming mode
- **WHEN** message consumption begins with start strategy set to `Latest` and `run_forever` set to `true` (Stop condition `Stream`)
- **AND** a limit of $N$ messages is configured
- **AND** $P$ partitions are assigned ($P > 1$)
- **THEN** the consumer SHALL seek each assigned partition to `max(low_watermark, high_watermark - share_p)` using that partition's even share of $N`
- **AND** emit existing tail messages under fair per-partition quotas up to high watermark, while continuing to poll and emit newly produced messages in real time
