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

### Requirement: Pre-compiled Filter Evaluation

The consumer SHALL pre-compile all configured regular expressions and search terms prior to entering the message consumption loop and evaluate them without allocating or compiling new regex instances per message.

#### Scenario: Consuming with regex filters

- **WHEN** message consumption begins with `filter_type` set to `Regex` and one or more filter terms provided
- **THEN** the consumer compiles each filter term into a reusable regular expression once during setup
- **AND** matches each incoming message against the pre-compiled expressions without compiling regular expressions inside the message loop

### Requirement: Cached Schema Registry Resolution

The consumer SHALL cache schema metadata and decoded schemas in memory across messages and across consecutive consumption sessions on the same cluster, resolving schema IDs without synchronous blocking network lookups on cached hits.

#### Scenario: Consuming schema-encoded messages with known schema ID

- **WHEN** a message with Confluent wire format is received and its schema ID has been previously resolved in the current cluster session
- **THEN** the consumer resolves the schema from the local in-memory cache
- **AND** decodes the payload without executing blocking runtime calls or HTTP requests to the Schema Registry

### Requirement: Throttled UI State Emission and Amortized Buffering

The Flutter message streaming layer SHALL buffer incoming messages from native Rust streams and dispatch UI state notifications (`notifyListeners`) at a throttled frame cadence of at most once every 50ms to 100ms, using amortized $O(1)$ collection operations.

#### Scenario: High-throughput message streaming to UI

- **WHEN** Kafka messages arrive across the FFI stream at sustained throughput exceeding 100 messages per second
- **THEN** the UI controller buffers incoming messages and triggers state notifications at a throttled cadence between 50ms and 100ms
- **AND** does not invoke `notifyListeners()` on every individual message
- **AND** adds incoming messages without $O(N)$ list prepending shifts

### Requirement: Non-Blocking Consumer Disk Logging

When message logging to an output directory is enabled, the search and consumption pipeline SHALL persist log entries asynchronously without executing synchronous blocking file I/O operations on the Flutter main UI isolate.

#### Scenario: Logging consumer events to disk

- **WHEN** a log message is received from the consumer stream while file logging is enabled
- **THEN** the log entry is written asynchronously using non-blocking I/O
- **AND** does not block frame rendering on the Flutter UI isolate
