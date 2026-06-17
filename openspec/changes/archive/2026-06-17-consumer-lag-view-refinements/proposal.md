## Why

To further improve usability, reliability, and precision of the Consumer Lag View:
1. **Default Auto-Refresh**: Polling lag details is crucial for monitoring active
   consumers. Defaulting the refresh interval to 30s (instead of Off/0s) provides
   an out-of-the-box real-time monitoring experience.
2. **Processed Offset Delta Column**: Users need to see processing throughput at
   a glance. Adding a "Processed" delta column showing the difference in committed
   offsets since the last update indicates consumer progress.
3. **Locale-Aware Number Formatting**: Large numbers (offsets, lags, metrics) are
   difficult to read without thousands separators. Applying locale-based
   formatting improves visual clarity.
4. **Background Activity Control**: When a user navigates away from the lag view,
   background fetching and queued queries must be terminated immediately to save
   system/network resources and prevent memory leaks.

## What Changes

- **Set Default Polling**: Default `_refreshIntervalSeconds` to 30s on view load.
- **Add Processed (Delta) Column**:
  - Store previously loaded committed offsets for each consumer group partition.
  - Calculate `CurrentOffset_new - CurrentOffset_old` per partition and sum them.
  - Render a new sortable "Processed" column in the main group table showing
    deltas as "+X" (green), "-X" (red), or "0" (grey).
- **Format Numbers**:
  - Implement a locale-aware number formatter using `package:intl/intl.dart`.
  - Format consumers count, topics count, total lag, log end offsets, committed
    offsets, and matched search counts based on the user's active locale.
- **Dispose Queued Tasks**:
  - Prevent subsequent queued group lag requests from initiating if the widget
    is unmounted (check `!mounted` in `_processNextLagQuery` and callbacks).
  - Cancel any active timers and ignore in-flight query results if the active
    profile changes or the view is disposed.

## Capabilities

### New Capabilities
- None

### Modified Capabilities
- `consumer-lag-monitoring`: Enhanced with processing delta tracking, locale-aware
  number formatting, default polling, and leak-safe navigation behavior.

## Impact

- **Frontend (Dart/Flutter)**:
  - Modify `consumer_lag_view.dart`, `group_details_view.dart`, and
    `topic_partition_table.dart` to apply locale formatting.
  - Introduce `_previousOffsets` and `_groupDeltas` state maps in
    `_ConsumerLagViewState` to calculate processing deltas.
  - Add the new "Processed" column to the header and body rows.
  - Ensure lifecycle hooks strictly cancel timers and halt the query queue.
