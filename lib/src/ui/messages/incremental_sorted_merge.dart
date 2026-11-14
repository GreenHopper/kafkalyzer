/// Incrementally merges [added] into an already-sorted [previous] list while
/// filtering out items where [retain] returns `false`.
///
/// Only [added] items are sorted and binary-searched against the retained
/// elements, avoiding O(N log N) re-sorting or O(N) list shifts.
List<T> mergeIncremental<T>(
  List<T> previous, {
  required bool Function(T) retain,
  required List<T> added,
  required Comparator<T> compare,
}) {
  final retained = <T>[
    for (final item in previous)
      if (retain(item)) item,
  ];

  if (added.isEmpty) return retained;

  final sortedAdded = List<T>.of(added)..sort(compare);
  if (retained.isEmpty) return sortedAdded;

  final result = <T>[];
  var lo = 0;

  for (final item in sortedAdded) {
    var low = lo;
    var high = retained.length;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (compare(retained[mid], item) <= 0) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    if (low > lo) {
      result.addAll(retained.getRange(lo, low));
    }
    result.add(item);
    lo = low;
  }

  if (lo < retained.length) {
    result.addAll(retained.getRange(lo, retained.length));
  }

  return result;
}
