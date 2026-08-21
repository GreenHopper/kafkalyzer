## Context

Currently, Kafkalyzer supports consuming messages with start strategies (`Earliest`, `Latest`, `Offset`, `Timestamp`) and stop strategies (`Stream`, `End`, `Offset`, `Timestamp`). When `Latest` is selected without custom offsets, the consumer defaults start offsets to the partition high watermarks ($H$). For topics where message production has ceased or is intermittent, bounded reads (`run_forever = false`) terminate immediately with 0 messages, while live streams (`run_forever = true`) wait indefinitely for new records.

This design introduces tail offset resolution when starting from `Latest`, computing partition start offsets as $\max(\text{low\_watermark}, \text{high\_watermark} - \text{limit})$, allowing users to immediately inspect the most recently produced messages on any topic.

## Goals / Non-Goals

**Goals:**
- Enable retrieving the latest $N$ messages from a topic (bounded or live) when `Latest` start strategy is selected with a result limit $N$.
- Compute partition start offsets based on cached high and low watermarks without extra Kafka round-trips.
- Support both single-partition targeting and multi-partition topics (seeking each assigned partition to its respective tail offset).
- Maintain 100% backwards compatibility for `Earliest`, explicit `Offset`, explicit `Timestamp`, and live streaming modes.
- Improve UI clarity and localization with tooltips explaining start/stop condition semantics.

**Non-Goals:**
- Modifying Kafka partition assignment or consumer group subscription semantics.
- Introducing complex multi-partition priority sorting beyond standard timestamp/offset ingestion order.

## Decisions

### Decision 1: Derive Tail Offset per Partition from High Watermark and Result Limit
- **Approach**: During `resolve_start_offsets`, if the start strategy is `Latest` (or `start_from_tail = true`), compute the start offset for each assigned partition $p$ as:
  $$\text{start\_offset}_p = \max(\text{low}_p, \text{high}_p - \text{limit})$$
  where $\text{limit} = \text{max\_results.unwrap\_or}(200)$.
- **Rationale**: Reuses the single-pass partition watermarks already queried during consumer initialization (`fetch_partition_watermarks`). This adds zero network overhead and ensures that even if traffic is concentrated on a subset of partitions, all available recent messages up to the limit can be fetched and processed.
- **Alternatives Considered**:
  - *Querying timestamps for time-based tail (e.g. last 1 hour)*: Ineffective for inactive topics where production stopped days or weeks ago.
  - *Consuming entire topic from earliest and discarding in Flutter*: Heavy network and memory overhead on large topics with millions of messages.

### Decision 2: Explicit `start_from_tail` in Rust Bridge API
- **Approach**: Pass an explicit boolean flag `start_from_tail` (or infer `start_offset.is_none() && start_timestamp.is_none() && start_from_tail`) across `rust_lib_kafkalyzer` and `kafkalyzer-kafka`.
- **Rationale**: Clearly distinguishes between starting at high watermark (0 historical messages) versus tail reading (fetching the latest $N$ messages up to high watermark), preserving type safety across the flutter_rust_bridge layer.

### Decision 3: Consistent UI Representation and Tooltips in Flutter
- **Approach**: Keep the familiar GroupButton selector (`Earliest`, `Latest`, `Offset`, `Timestamp`) for start condition, and (`End`, `Stream`, `Offset`, `Timestamp`) for stop condition, while adding tooltip helpers and localized helper hints.
- **Rationale**: Maintains existing muscle memory while making the semantics crystal clear for users.

## Risks / Trade-offs

- **[Multi-Partition Distribution]** On topics with many partitions and skewed traffic, setting each partition's start offset to `high - limit` might read up to $\text{partitions} \times \text{limit}$ messages before hitting the global `max_results` limiter.
  → *Mitigation*: The consumer already enforces `should_stop_for_limit(matched_count, max_results)` inside the poll loop and terminates promptly when `max_results` is satisfied.
