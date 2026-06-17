## Context

The previous updates migrated the consumer lag overview to a sortable grid/table
with customizable refresh intervals, lazy loading of group details, and nested
collapsible topic-partition tables.
To make it production-ready, we need default active monitoring, visual indicators of
processing speed, localized numbers, and robust garbage collection of background
tasks when navigating away.

## Goals / Non-Goals

**Goals:**
- Set default refresh interval to 30 seconds.
- Compute committed offset differences per group/partition between refreshes.
- Render a "Processed" column representing delta throughput since the last poll.
- Format all numeric displays on the lag view using the user's localized format.
- Ensure zero background activity (timers, queue workers) after navigating away.

**Non-Goals:**
- Persistence of previous offsets across app restarts.

## UI Components & State Flow

### 1. Default Refresh Interval
- Initialize `_refreshIntervalSeconds` to `30`.
- In `build()`, when a cluster is connected, verify `_refreshTimer` is started
  with 30s period.

### 2. Processing Delta (Processed Column)
- Maintain `final Map<String, Map<String, int>> _previousOffsets = {};` mapping
  `groupId` -> `{"$topic-$partition": offset}`.
- Maintain `final Map<String, int> _groupDeltas = {};` mapping `groupId` -> delta.
- Upon receiving detailed lag for a group:
  - If previous offsets exist, calculate:
    `delta = sum(currentOffset_new - currentOffset_old)` (ignoring offsets < 0).
  - Update `_groupDeltas[groupId] = delta`.
  - Store the new offsets map in `_previousOffsets[groupId]`.
- Add column 7 (index 6) named "Abarbeitung" (German) or "Processed" (English).
- Display a color-coded badge:
  - `+X` (Green background/text) when `delta > 0`
  - `-X` (Red background/text) when `delta < 0`
  - `0` (Grey background/text) when `delta == 0`
  - `-` (Grey text) when no previous data is available.

### 3. Locale-Aware Formatting
- Implement a helper:
  ```dart
  String formatNum(BuildContext context, num value) {
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.decimalPattern(locale).format(value);
  }
  ```
- Wrap all displayed numbers:
  - Group details: `membersCount`, `topicsCount`, `totalLag`
  - Control badges / messages: `matchedCount`, `totalCount`, fetch elapsed counts
  - Expandable topics: topic total lag
  - Expandable partition rows: `logEndOffset`, `currentOffset` (if >= 0), and `lag`

### 4. Background Query Cancellation & Safe Lifecycle
- In `_processNextLagQuery()` and `_loadGroupLag()`, add early exits if
  `!mounted`.
- If a query resolves but `!mounted` or `activeProfile` changed in the interim,
  discard the update.
- Ensure `dispose()` cancels `_refreshTimer`.
