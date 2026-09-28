import 'dart:math';

/// A segment of a list in the context windowing calculation.
sealed class ListSegment {
  const ListSegment();
}

/// A visible item at [index]. [isDirectMatch] indicates if this element directly matched the query.
class VisibleItemSegment extends ListSegment {
  final int index;
  final bool isDirectMatch;

  const VisibleItemSegment({
    required this.index,
    required this.isDirectMatch,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VisibleItemSegment &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          isDirectMatch == other.isDirectMatch;

  @override
  int get hashCode => Object.hash(index, isDirectMatch);

  @override
  String toString() =>
      'VisibleItemSegment(index: $index, isDirectMatch: $isDirectMatch)';
}

/// A contiguous range of collapsed items from [startIndex] to [endIndex] inclusive.
class CollapsedRangeSegment extends ListSegment {
  final int startIndex;
  final int endIndex;

  const CollapsedRangeSegment({
    required this.startIndex,
    required this.endIndex,
  });

  /// Total count of collapsed elements in this segment.
  int get count => (endIndex - startIndex) + 1;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollapsedRangeSegment &&
          runtimeType == other.runtimeType &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex;

  @override
  int get hashCode => Object.hash(startIndex, endIndex);

  @override
  String toString() =>
      'CollapsedRangeSegment(startIndex: $startIndex, endIndex: $endIndex, count: $count)';
}

/// Calculates visibility segments for array items around matching indices.
///
/// If [forceShowAll] is true or [matchIndices] is empty, returns all items as [VisibleItemSegment].
/// Otherwise, surrounds each matching index with a context window of [radius] items on each side,
/// and collapses consecutive non-visible items into [CollapsedRangeSegment]s.
class ContextWindowCalculator {
  static List<ListSegment> calculateSegments({
    required int totalLength,
    required Set<int> matchIndices,
    int radius = 1,
    bool forceShowAll = false,
  }) {
    if (totalLength <= 0) return const [];
    if (forceShowAll || matchIndices.isEmpty) {
      return List.generate(
        totalLength,
        (i) => VisibleItemSegment(
          index: i,
          isDirectMatch: matchIndices.contains(i),
        ),
      );
    }

    final visibleIndices = <int>{};
    for (final match in matchIndices) {
      if (match < 0 || match >= totalLength) continue;
      final start = max(0, match - radius);
      final end = min(totalLength - 1, match + radius);
      for (int i = start; i <= end; i++) {
        visibleIndices.add(i);
      }
    }

    if (visibleIndices.isEmpty) {
      return List.generate(
        totalLength,
        (i) => VisibleItemSegment(index: i, isDirectMatch: false),
      );
    }

    final segments = <ListSegment>[];
    int currentIndex = 0;

    while (currentIndex < totalLength) {
      if (visibleIndices.contains(currentIndex)) {
        segments.add(VisibleItemSegment(
          index: currentIndex,
          isDirectMatch: matchIndices.contains(currentIndex),
        ));
        currentIndex++;
      } else {
        final collapsedStart = currentIndex;
        while (currentIndex < totalLength &&
            !visibleIndices.contains(currentIndex)) {
          currentIndex++;
        }
        segments.add(CollapsedRangeSegment(
          startIndex: collapsedStart,
          endIndex: currentIndex - 1,
        ));
      }
    }

    return segments;
  }
}
