## Why

When opening a Kafka topic to view messages (defaulting to the oldest 200 messages with earliest offset strategy), Kafkalyzer currently exhibits noticeable latency (typically 3.5 to 5+ seconds) before concluding that a topic is empty or before streaming initial messages.

Profiling the consumer pipeline in `kafkalyzer-kafka/src/kafka_consumer.rs` reveals several compounding bottlenecks:
1. **Artificial stabilization sleep loops**: The consumer executes hardcoded poll loops (20 iterations x 100ms = 2.0s during setup, plus 5 iterations x 100ms = 0.5s in seek logic) regardless of topic state or partition count.
2. **Missing fast-path early exit**: Even when partition watermarks report `low == 0` and `high == 0` (or start offset >= high watermark across all partitions), the system still executes all stabilization loops and enters the poll loop instead of immediately recognizing the empty range.
3. **Redundant watermark queries**: Watermarks are queried sequentially during seek handling and then re-queried during end offset calculation, duplicating network round-trips to Kafka brokers.
4. **Delayed EOF detection**: The polling loop enforces a 1-second throttle before evaluating `check_done`, causing an artificial 1-second wait when no messages are available.

Optimizing these areas will reduce empty topic detection and message consumption initialization from seconds to sub-100ms.

## What Changes

- **Eliminate artificial stabilization poll loops**: Remove the 2.0s (20x100ms) and 0.5s (5x100ms) blocking loops in `consume_with_filter` and `handle_seek_logic`, replacing them with an event-driven or minimal non-blocking poll.
- **Fast-path early exit for empty topics & exhausted offset ranges**: Check partition watermarks upfront; if all assigned partitions have `start_offset >= high_watermark` and `run_forever == false`, immediately send initial progress `0:0`, send `__EOF__`, and terminate without entering `run_poll_loop`.
- **Consolidate & cache watermark fetching**: Query topic partition watermarks once during assignment/seek setup and reuse the results for end offset calculations.
- **Responsive EOF detection in poll loop**: When `consumer.poll()` returns `None` (poll timeout) or `PartitionEOF`, trigger `check_done` promptly instead of waiting for a 1-second timer.
- **UI & Controller responsiveness**: Ensure `MessageStreamController` handles instant `__EOF__` cleanly and updates progress indicators without delay.

## Capabilities

### New Capabilities
- `topic-consumption`: Fast and responsive message consumption pipeline with early empty-topic detection, consolidated watermark inspection, and event-driven partition assignment.

### Modified Capabilities

## Impact

- **Performance**: Response time for opening empty topics drops from ~3.5-5s to under 100ms. Non-empty topics also begin receiving and displaying messages immediately without 2.5s setup latency.
- **Rust Backend**: Modifies `kafkalyzer-kafka/src/kafka_consumer.rs` (initialization flow, watermark resolution, seek handling, poll loop, EOF checks).
- **Dart Frontend**: No breaking API changes; `MessageStreamController` and topic detail views seamlessly benefit from lower latency and faster streaming completion.
