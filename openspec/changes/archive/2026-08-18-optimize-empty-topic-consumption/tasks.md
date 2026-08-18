# Tasks: Topic Consumption & Empty Topic Optimization

## 1. Rust Consumer Setup & Watermark Consolidation
- [x] 1.1 Implement consolidated watermark query helper (`fetch_partition_watermarks`) in `kafkalyzer-kafka/src/kafka_consumer.rs` to fetch partition bounds in a single pass. <!-- id: 1.1 -->
- [x] 1.2 Remove the artificial blocking stabilization poll loops (20x100ms in `consume_with_filter` and 5x100ms in `handle_seek_logic`). <!-- id: 1.2 -->
- [x] 1.3 Refactor `perform_seek` and `calculate_end_offsets` to reuse the pre-fetched watermark map rather than executing duplicate broker calls per partition. <!-- id: 1.3 -->

## 2. Fast-Path Early Exit & Responsive Polling
- [x] 2.1 Implement fast-path early exit in `consume_with_filter`: if `!run_forever && total_to_scan == 0`, immediately emit initial progress `0:0` and `__EOF__` and return `Ok(())`. <!-- id: 2.1 -->
- [x] 2.2 Refactor `run_poll_loop` in `kafka_consumer.rs` to check completion promptly on `None` or `PartitionEOF` poll results without enforcing an arbitrary 1-second delay. <!-- id: 2.2 -->
- [x] 2.3 Optimize poll interval and progress dispatch to maintain high UI responsiveness with minimal overhead. <!-- id: 2.3 -->

## 3. Verification & Validation
- [x] 3.1 Verify empty topic detection latency is sub-100ms when browsing an empty topic with earliest start strategy. <!-- id: 3.1 -->
- [x] 3.2 Verify message loading latency and message limit enforcement (e.g. oldest 200 messages) on populated topics. <!-- id: 3.2 -->
- [x] 3.3 Verify continuous/live streaming (`run_forever = true`) continues operating correctly without premature termination. <!-- id: 3.3 -->
- [x] 3.4 Build and run tests to ensure no regressions in filtering, decoding, and lag viewing. <!-- id: 3.4 -->
