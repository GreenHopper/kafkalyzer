# Design

## Context

In `TopicDetailView`, navigation from topic analysis currently receives only `(int partition, int offset)`. This implementation was originally modeled after jumping to a single sample message coordinate. However, duplicate messages typically occur across multiple offsets and across multiple partitions in multi-partition Kafka topics. 

By setting only `_partitionController.text = partition.toString()` and `_offsetController.text = offset.toString()` while leaving `_filterController.text` empty and `_scanMode` as `TopicScanMode.latestN`, the Messages view fails to filter for the duplicate. Instead, it scans the latest 200 arbitrary messages from that single partition, misleading users who expect to see the specific duplicate messages.

## Goals / Non-Goals

**Goals:**
- Provide a structured navigation target model (`DuplicateNavigationTarget`) conveying all necessary duplicate metadata: `key`, `payloadPreview`, `count`, `scope`, `samplePartition`, and `sampleOffset`.
- In `TopicDetailView`, automatically populate search criteria when navigating to filter duplicate occurrences:
  - Populate `_filterController.text` with `key` (if present) or `payloadPreview` (for unkeyed messages).
  - Configure `_searchScope` (`SearchScope.key` or `SearchScope.value`).
  - Configure `_filterType` (`FilterType.exact` for key, `FilterType.contains` for payload).
  - Clear `_partitionController` to scan all partitions across the topic.
  - Set `_scanMode = TopicScanMode.offsetEarliest` and `_startStrategy = MultiSearchStartStrategy.earliest` (offset 0).
  - Adjust `_maxResultsController` if needed to accommodate all duplicate occurrences.
  - Initiate consumption via `startStreaming()`.
- Provide clear user-facing navigation actions in `DuplicateDetailsDialog`:
  - Primary action: "In Nachrichten filtern" (Filter in Messages) to find all occurrences across partitions.
  - Secondary action: "Zum Beispiel springen" (Jump to sample offset) to jump to the exact sample partition and offset coordinates.
- Ensure all new strings are localized in `app_en.arb` and `app_de.arb`.

**Non-Goals:**
- Modifying Rust backend code or Kafka broker consumer logic.
- Changing duplicate detection hashing algorithms or report structure.

## Decisions

### Decision 1: Structured `DuplicateNavigationTarget`

Instead of passing an expanding list of loose positional arguments through `DuplicateDetailsDialog` -> `DuplicateAnalysisView` -> `TopicAnalysisView` -> `TopicDetailView`, define:

```dart
class DuplicateNavigationTarget {
  final String? key;
  final String payloadPreview;
  final int count;
  final int samplePartition;
  final int sampleOffset;
  final DuplicateDetectionScope scope;
  final bool filterOccurrences; // true = filter across topic, false = jump to sample offset

  const DuplicateNavigationTarget({
    this.key,
    required this.payloadPreview,
    required this.count,
    required this.samplePartition,
    required this.sampleOffset,
    required this.scope,
    this.filterOccurrences = true,
  });
}
```

*Rationale*: Encapsulates duplicate context cleanly and keeps view callbacks backwards compatible and type-safe.

### Decision 2: Two Distinct Actions in Duplicate Details Dialog

In `DuplicateDetailsDialog`, present two clear actions:
1. Primary FilledButton: `l10n.filterDuplicatesInMessages` ("In Nachrichten filtern" / "Filter in Messages") with `filterOccurrences: true`.
2. OutlinedButton: `l10n.jumpToSampleOffset` ("Zum Beispiel springen" / "Jump to Sample") with `filterOccurrences: false`.

*Rationale*: Resolves the user's confusion directly. Users looking for all 12 duplicate occurrences click the primary filter button; users needing to inspect the exact sample message in its surrounding context click the coordinate jump button.

### Decision 3: Filter Term and Scope Resolution

When `filterOccurrences` is true in `TopicDetailView`:
- **Keyed duplicates** (`target.key != null && target.key!.isNotEmpty`):
  - `_filterController.text = target.key!`
  - `_searchScope = SearchScope.key`
  - `_filterType = FilterType.exact`
- **Unkeyed duplicates** (`target.key == null || target.key!.isEmpty`):
  - Normalize `target.payloadPreview` (taking a clean substring if lengthy or trimming whitespaces)
  - `_filterController.text = normalizedPayload`
  - `_searchScope = SearchScope.value`
  - `_filterType = FilterType.contains`
- **Scan range**:
  - `_partitionController.clear()` (enabling multi-partition scan)
  - `_scanMode = TopicScanMode.offsetEarliest`
  - `_startStrategy = MultiSearchStartStrategy.earliest`
  - `_offsetController.text = '0'`
  - `_limitResults = true`
  - `_maxResultsController.text = math.max(200, target.count).toString()`

When `filterOccurrences` is false (sample jump):
- `_partitionController.text = target.samplePartition.toString()`
- `_offsetController.text = target.sampleOffset.toString()`
- `_scanMode = TopicScanMode.offsetEarliest`
- `_startStrategy = MultiSearchStartStrategy.customOffset`

## Risks / Trade-offs

- **[Risk]** Unkeyed payload previews might contain formatting or JSON whitespace differences that prevent exact string matching during Kafka stream filtering.
  - *Mitigation*: Unkeyed duplicates use `FilterType.contains` with a trimmed excerpt from the payload preview rather than strict full-string exact matching.
- **[Risk]** Scanning an entire high-volume topic from offset 0 across all partitions could take time before finding all duplicates.
  - *Mitigation*: The scan operates asynchronously with full progress feedback, throttled streaming, and early cancellation via the "Stop" button.
