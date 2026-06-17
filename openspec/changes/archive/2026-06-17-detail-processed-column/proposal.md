## Why

To enhance the visual detail in the Consumer Lag view:
1. **Topic-level delta indicators**: In the detailed group view, topics list only their total lag. Displaying the combined delta change (throughput) for each topic gives users context on which specific topics are active or falling behind.
2. **Partition-level lag change**: Inside the topic assignment tables, partition metrics only show absolute lag values. Adding the "Abarbeitung" (Processed) delta column directly inside the partition list lets administrators pinpoint which partitions have processed messages and which ones are accumulating lag.

## What Changes

- **Pass Previous Lags Map**: Pass the `_previousLags[group.groupId]` map as a parameter to the `GroupDetailsView` widget.
- **Display Topic Lag Deltas**:
  - In `GroupDetailsView`, compute the combined delta change for each topic by summing up the changes in lag values of its partitions.
  - Render a badge matching the color-coded delta design next to the topic lag badge: green for negative (reduced lag), red for positive (increased lag), grey for zero, or a grey `-` if no comparative lag is available.
- **Pass Lags to Partition Table**: Pass the previous lags map down to the `TopicPartitionTable` widget.
- **Render Processed Column inside Partition Table**:
  - Expand `TopicPartitionTable` to have 5 columns: Partition, Log End Offset, Committed Offset, Lag, and Abarbeitung (Processed).
  - Calculate each partition's lag change (`lag_new - lag_old`).
  - Render it as a colored text badge matching the main table's visual representation.
  - Implement full column sorting in `TopicPartitionTable` for the new Abarbeitung column.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `consumer-lag-monitoring`: Enhanced group detail widget and topic-partition assignment tables with localized, color-coded lag change throughput (Abarbeitung) tracking at the topic and partition levels.

## Impact

- **Frontend (Dart/Flutter)**:
  - Modify `consumer_lag_view.dart` to supply the previous lags map to `GroupDetailsView`.
  - Modify `group_details_view.dart` to compute and display topic-level deltas, and pass the map to `TopicPartitionTable`.
  - Modify `topic_partition_table.dart` to add the "Abarbeitung" / "Processed" column, display the deltas, and support sorting on it.
  - Update unit/widget tests to cover the new details-level delta rendering and sorting.
