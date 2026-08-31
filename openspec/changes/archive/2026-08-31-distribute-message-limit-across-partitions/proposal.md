## Why

When a result limit is set (for example 200), the consumer stops as soon as the global match count is reached. rdkafka tends to deliver from lower partition IDs first, so multi-partition topics often show only partition 0 even when 12 partitions exist. That hides cross-partition traffic and makes limited scans misleading for exploration and debugging.

## What Changes

- Change bounded message consumption so a configured result limit is shared across all assigned partitions instead of being filled greedily from whichever partition delivers first.
- Allocate per-partition match quotas as evenly as possible, then redistribute unused quota when a partition has no (further) matching messages in the selected offset/time range.
- Adjust Latest/tail start-offset calculation so each partition seeks back by its share of the limit (not the full global limit on every partition).
- Preserve existing behavior when the user explicitly selects a single partition, when no limit is set, and for live streaming (`run_forever = true`) after the initial tail window.
- Keep the global limit as a hard ceiling on total returned matches.

## Capabilities

### New Capabilities

<!-- None. This extends existing topic consumption behavior. -->

### Modified Capabilities

- `topic-consumption`: Result limits on multi-partition reads must be distributed fairly across assigned partitions, with redistribution when some partitions are empty or exhausted for the selected range; Latest tail seeking must use the per-partition share of the limit.

## Impact

- Rust consumer in `rust/kafkalyzer-kafka` (`kafka_consumer.rs`): poll-loop limit enforcement, per-partition quota tracking/pause-resume or equivalent fairness, and `tail_offset_from_watermarks` / start-offset resolution.
- Existing unit/integration tests covering Latest start strategy and result limits; new tests for multi-partition fair allocation and empty-partition redistribution.
- No Flutter UI or API surface changes expected: `maxResults` / limit checkbox semantics stay the same; only the composition of returned messages changes.
- No bridge/FFI type changes expected.
