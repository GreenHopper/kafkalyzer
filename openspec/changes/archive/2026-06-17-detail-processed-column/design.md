## Context

The main table shows the "Abarbeitung" (Processed) column representing change in total lag. When a user expands a group to see topic-partition assignments, they need the same contextual insight inside the detailed views.

## Goals / Non-Goals

**Goals:**
- Render topic-level delta badges in the detailed group view.
- Render partition-level delta values in the partition table view.
- Support sorting by the new "Abarbeitung" column in the partition table view.
- Maintain consistent visual formatting (colors/signs) across all delta displays.

**Non-Goals:**
- Storing individual partition metrics in separate global state databases (instead, we reuse the existing `_previousLags` map).

## UI Components & State Flow

### 1. State Parameter Propagation
- Update `GroupDetailsView` constructor to accept `final Map<String, int>? previousLags;`.
- Update `TopicPartitionTable` constructor to accept `final Map<String, int>? previousLags;`.
- In `consumer_lag_view.dart`, pass `_previousLags[group.groupId]` to `GroupDetailsView`.

### 2. Topic-Level Delta Calculation & Display
- In `group_details_view.dart`, calculate the topic-level delta:
  ```dart
  int? _calculateTopicDelta(String topic, List<TopicPartitionLag> partitionLags) {
    if (widget.previousLags == null) return null;
    int totalDelta = 0;
    bool hasOld = false;
    for (final part in partitionLags) {
      final key = "${part.topic}-${part.partition}";
      final oldLag = widget.previousLags![key];
      if (oldLag != null) {
        totalDelta += (part.lag.toInt() - oldLag);
        hasOld = true;
      }
    }
    return hasOld ? totalDelta : null;
  }
  ```
- Build a helper `_buildTopicDeltaWidget(BuildContext context, int? delta)` in `GroupDetailsView`:
  - `delta == null` or no historical compare: render grey `-` badge.
  - `delta > 0` (lag increased, bad): render `+X` with red background/text.
  - `delta < 0` (lag decreased, good): render `X` (value with its natural minus sign) with green background/text.
  - `delta == 0`: render `0` with grey background/text.
- Place this badge to the left of the total lag badge inside the `ExpansionTile`'s `trailing` property.

### 3. Partition-Level Delta Column
- Add a fifth column with index 4 to `TopicPartitionTable`.
- Column header: `Abarbeitung` (German) / `Processed` (English).
- Table body cells: calculate `lag_new - lag_old`. Render the formatted number:
  - If `delta > 0`: `+X` in red text.
  - If `delta < 0`: `X` in green text.
  - If `delta == 0`: `0` in grey/default text.
  - If no historical compare: `-` in grey text.

### 4. Partition Sorting
- In `TopicPartitionTable`'s sorting logic, support case `4` representing the `Abarbeitung` column:
  ```dart
  int _getPartitionDelta(TopicPartitionLag part) {
    if (widget.previousLags == null) return 0;
    final key = "${part.topic}-${part.partition}";
    final oldLag = widget.previousLags![key];
    if (oldLag == null) return 0;
    return part.lag.toInt() - oldLag;
  }
  ```
- Compare using `_getPartitionDelta(a).compareTo(_getPartitionDelta(b))`.
