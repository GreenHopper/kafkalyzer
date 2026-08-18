# Design: Topic Consumption & Empty Topic Optimization

## Overview

Kafkalyzer's message consumption engine in `kafkalyzer-kafka/src/kafka_consumer.rs` provides filtered, bounded, or live message streaming to the Flutter UI via Flutter Rust Bridge.

This design eliminates artificial latency bottlenecks during topic browsing, with particular focus on fast empty-topic detection and immediate message delivery for bounded offset queries (e.g. oldest 200 messages).

## Current Flow vs. Optimized Flow

### Current Execution Flow (~3,500ms - 5,000ms on empty topic)
1. `create_consumer` (with auto.offset.reset earliest/latest)
2. `setup_topic_assignment` (rdkafka `assign()`)
3. **Loop**: 20 x 100ms polls (**+2,000ms delay**)
4. `handle_seek_logic`:
   - **Loop**: 5 x 100ms polls (**+500ms delay**)
   - `perform_seek`: fetch watermarks per partition (timeout 10s), seek per partition
5. `calculate_end_offsets`: fetch watermarks *again* per partition (timeout 5s)
6. `calculate_total_to_scan` -> returns `0`
7. `sink.add("__PROGRESS__:0:0")`
8. `run_poll_loop`:
   - `poll(200ms)` returns `None`
   - Checks `last_eof_check_time.elapsed().as_secs() >= 1` (**+1,000ms delay**)
   - `check_done()` -> returns true
   - `send_eof()` -> exits

### Optimized Execution Flow (< 50ms on empty topic)
1. `create_consumer`
2. `setup_topic_assignment` (rdkafka `assign()`)
3. **Single-pass Watermark Query**: Query watermarks `(low, high)` once for all assigned partitions.
4. **Fast-path Check**:
   - For each partition, determine `start_offset` (from `start_strategy` or clamped to `low`) and `end_offset` (from `end_strategy` or `high`).
   - If `!run_forever && total_to_scan == 0` (or `start_offset >= high` for all partitions):
     - Emit `__PROGRESS__:0:0`
     - Emit `__EOF__`
     - Return `Ok(())` immediately (total time < 50ms).
5. **Direct Seek (if messages exist)**:
   - For partitions with messages, seek directly to target start offsets without artificial poll loops.
6. **Responsive Poll Loop**:
   - When `poll(100ms)` yields `None` or `PartitionEOF`, trigger `check_done` promptly instead of waiting 1 second.
   - Continue processing matching messages up to `max_results` or partition bounds.

---

## Detailed Component Changes

### 1. Watermark Consolidation (`kafka_consumer.rs`)
Replace separate watermark querying in `perform_seek` and `calculate_end_offsets` with a unified helper:
```rust
fn fetch_partition_watermarks(
    consumer: &BaseConsumer,
    topic: &str,
    partitions: &[i32],
    timeout: std::time::Duration,
) -> std::collections::HashMap<i32, (i64, i64)>
```
The resulting `HashMap<i32, (i64, i64)>` (mapping partition ID -> `(low_watermark, high_watermark)`) is reused across start offset clamping, seek validation, and end offset computation.

### 2. Fast-Path Early Exit
After computing start offsets and end offsets:
```rust
let total_to_scan = calculate_total_to_scan(...);

if !run_forever && total_to_scan == 0 {
    send_progress(&sink, &topic, 0, 0).ok();
    send_eof(&sink, &topic);
    return Ok(());
}
```
This bypasses `run_poll_loop` entirely for empty topics or query ranges that have no available messages.

### 3. Removal of Stabilization Loops
Remove the redundant polling loops:
- Remove `for _ in 0..20 { consumer.poll(100ms); }` in `consume_with_filter`.
- Remove `for _ in 0..5 { consumer.poll(100ms); }` in `handle_seek_logic`.
- With manual assignment (`consumer.assign`), partition assignments take effect immediately within the librdkafka consumer without coordinator rebalancing.

### 4. Responsive Poll Loop EOF Check
In `run_poll_loop`:
- Reduce poll duration from 200ms to 100ms for more responsive event processing.
- When `poll()` returns `None` or `PartitionEOF`, evaluate `check_done()` without requiring `last_eof_check_time.elapsed().as_secs() >= 1`.
- Retain progress throttling (e.g. at most every 250-500ms) to avoid flooding the Dart stream with duplicate progress events while ensuring completion is dispatched immediately.

---

## Verification & Metrics

- **Empty Topic Response Time**: Measure time from `startStreaming` invocation to `__EOF__` receipt on empty topics (expected: < 100ms vs ~4,000ms previously).
- **Populated Topic Initial Message Latency**: Measure time from `startStreaming` to first message received on populated topics (expected: < 150ms vs ~2,700ms previously).
- **Limit Enforcement**: Verify that setting `maxResults: 200` on a topic with 1,000 messages stops accurately after 200 messages.
- **Continuous / Live Streaming (`run_forever = true`)**: Verify that live streaming continues to wait for new incoming messages as expected.
