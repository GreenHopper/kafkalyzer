## Context

The Kafkalyzer application currently provides a Consumer Lag Dashboard where users can monitor the lag of various consumer groups across clusters. While the lag (the gap between current offset and log end offset) is visible, there is no direct way to inspect the content of the messages where the consumer is currently stuck. This makes it difficult to quickly identify "poison pill" messages that might be causing processing failures or infinite retries.

## Goals / Non-Goals

**Goals:**
- Add a "View Messages" action to the topic-partition table in the Consumer Lag dashboard.
- Enable direct navigation from a lagging partition to a message inspection view starting at the current consumer offset.
- Reuse existing UI components and backend APIs for message fetching and display.

**Non-Goals:**
- Implementation of a new message consumption engine (existing `consume_with_filter` will be used).
- Modifying the consumer group's committed offsets from the UI.
- Real-time streaming of lagging messages (ad-hoc inspection only).

## Decisions

- **Decision 1: Action Placement in Partition Table**
  - **Rationale:** The most granular level of lag is per partition. Adding an icon/button in the partition detail table allows users to target specific lagging partitions.
  - **Implementation:** Add an `IconButton` to the `DataRow2` in the expanded consumer group table.

- **Decision 2: Reuse `MessageDetailsDialog` and `consume_with_filter` API**
  - **Rationale:** The backend API `consume_with_filter` already supports `start_offset`, `start_partition`, and `max_results`. The frontend already has `MessageDetailsDialog` for inspecting single messages.
  - **Implementation:** When the user clicks "View Messages", trigger a fetch with `max_results: 1` and `start_offset: current_offset`.

- **Decision 3: Integrated Inspection Flow**
  - **Rationale:** Instead of navigating away from the dashboard, a modal or overlay is preferred to maintain context.
  - **Implementation:** Open a dialog that fetches and displays the message. Optionally, provide a link to "Open in Explorer" for full-screen inspection.

## Risks / Trade-offs

- **[Risk] Offsets out of range** → If the current offset has already been deleted due to retention policy, the fetch might fail.
  - **Mitigation:** Handle "Offset Out of Range" errors gracefully in the UI and inform the user.
- **[Risk] UI Complexity** → Adding too many icons to the table might clutter the UI.
  - **Mitigation:** Use a subtle "eye" or "message" icon that only appears on hover or is clearly labeled.

## Open Questions

- Should we fetch more than one message? (e.g., fetch 10 messages starting at the offset to give more context).
- Should we automatically decode the message if a schema is available? (Yes, the existing bridge handles this).
