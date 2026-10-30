import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// Target parameters for navigating from duplicate analysis to message view.
class DuplicateNavigationTarget {
  final String? key;
  final String payloadPreview;
  final int count;
  final int samplePartition;
  final int sampleOffset;
  final int sampleTimestampMs;
  final DuplicateDetectionScope scope;
  final bool filterOccurrences;

  const DuplicateNavigationTarget({
    this.key,
    required this.payloadPreview,
    required this.count,
    required this.samplePartition,
    required this.sampleOffset,
    this.sampleTimestampMs = 0,
    required this.scope,
    this.filterOccurrences = true,
  });

  /// Factory constructor to build a target directly from a [TopDuplicateOccurrence].
  factory DuplicateNavigationTarget.fromOccurrence({
    required TopDuplicateOccurrence occurrence,
    required DuplicateDetectionScope scope,
    bool filterOccurrences = true,
  }) {
    return DuplicateNavigationTarget(
      key: occurrence.key,
      payloadPreview: occurrence.payloadPreview,
      count: occurrence.count.toInt(),
      samplePartition: occurrence.samplePartition,
      sampleOffset: occurrence.sampleOffset.toInt(),
      sampleTimestampMs: occurrence.sampleTimestampMs.toInt(),
      scope: scope,
      filterOccurrences: filterOccurrences,
    );
  }
}
