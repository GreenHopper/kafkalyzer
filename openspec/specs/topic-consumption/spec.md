# topic-consumption Specification

## Purpose
Provides a fast, responsive message consumption pipeline with early empty-topic detection, consolidated watermark inspection, and prompt EOF termination for bounded reads.

## Requirements

### Requirement: Fast Empty Topic Detection
The message consumer SHALL detect empty topics and exhausted offset ranges during initial partition watermark inspection and terminate immediately when not in live streaming mode (`run_forever = false`).

#### Scenario: Opening an empty topic with earliest start strategy
- **WHEN** message consumption begins for a topic where all assigned partitions have a high watermark equal to the low watermark (e.g. `0 == 0`)
- **AND** `run_forever` is `false`
- **THEN** the consumer emits an initial progress indicator `__PROGRESS__:0:0`
- **AND** the consumer immediately emits `__EOF__` without entering the poll loop or sleeping
- **AND** the entire operation completes in under 100ms

#### Scenario: Requesting offset range beyond available messages
- **WHEN** message consumption begins with a `start_offset` or `start_timestamp` that resolves to greater than or equal to the high watermark on all assigned partitions
- **AND** `run_forever` is `false`
- **THEN** the consumer emits `__PROGRESS__:0:0` and `__EOF__` immediately without waiting for poll timeouts

### Requirement: Zero-Delay Consumer Initialization
The system SHALL NOT execute arbitrary sleep or fixed-iteration polling delays during consumer creation, assignment, or seek setup.

#### Scenario: Immediate partition assignment without blocking stabilization loops
- **WHEN** the consumer assigns target topic partitions
- **THEN** the consumer does not execute fixed-iteration blocking sleep loops (e.g. 20 x 100ms or 5 x 100ms)
- **AND** proceeds directly to watermark resolution and seeking

### Requirement: Consolidated Watermark Resolution
The consumer SHALL query partition low and high watermarks in a single pass during setup, reusing the retrieved watermarks for both start offset clamping and end offset calculation.

#### Scenario: Single-pass watermark lookup per partition
- **WHEN** setting up start and end offset boundaries for a topic
- **THEN** the consumer fetches partition watermarks at most once per partition
- **AND** uses the resolved high watermarks to determine total messages to scan and termination bounds

### Requirement: Responsive Poll Loop and EOF Termination
When consuming messages in bounded mode (`run_forever = false`), the consumer SHALL promptly detect when all partitions have reached their end boundaries.

#### Scenario: Poll timeout on exhausted partitions
- **WHEN** the consumer poll returns `None` or `PartitionEOF` while all partitions have reached their target end offsets
- **AND** `run_forever` is `false`
- **THEN** the consumer evaluates completion without requiring a 1-second delay
- **AND** emits `__EOF__` and exits the polling loop immediately

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

