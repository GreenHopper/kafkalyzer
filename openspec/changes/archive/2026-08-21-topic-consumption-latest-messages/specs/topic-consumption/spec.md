## ADDED Requirements

### Requirement: Tail Offset Resolution for Latest Start Strategy
The message consumer SHALL support starting consumption from the tail of a topic by computing partition start offsets as `max(low_watermark, high_watermark - limit)` when the `Latest` start strategy is selected.

#### Scenario: Consuming latest messages from an inactive topic with bounded end
- **WHEN** message consumption begins on a topic with start strategy set to `Latest`
- **AND** a limit of $N$ messages (e.g. 200) is configured
- **AND** `run_forever` is `false` (Stop condition `End`)
- **THEN** the consumer SHALL resolve the start offset for each assigned partition to `max(low_watermark, high_watermark - N)`
- **AND** seek each assigned partition to its resolved start offset
- **AND** poll and emit up to $N$ messages until reaching the partition high watermarks
- **AND** emit `__EOF__` and terminate when the high watermarks or the result limit is reached

#### Scenario: Consuming latest messages on an empty topic
- **WHEN** message consumption begins with start strategy set to `Latest` on a topic where `low_watermark == high_watermark` across all partitions
- **AND** `run_forever` is `false`
- **THEN** the consumer SHALL compute `total_to_scan` as `0`
- **AND** immediately emit `__PROGRESS__:0:0` and `__EOF__` without entering polling delays

#### Scenario: Consuming latest messages in live streaming mode
- **WHEN** message consumption begins with start strategy set to `Latest` and `run_forever` set to `true` (Stop condition `Stream`)
- **AND** a limit of $N$ messages is configured
- **THEN** the consumer SHALL seek each assigned partition to `max(low_watermark, high_watermark - N)`
- **AND** emit existing tail messages up to high watermark, while continuing to poll and emit newly produced messages in real time
