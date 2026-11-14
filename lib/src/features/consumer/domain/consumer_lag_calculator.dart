import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

enum GroupLagOutcome { known, noCommittedOffsets, unknown }

class GroupLagSummary {
  const GroupLagSummary({
    required this.outcome,
    required this.totalLag,
    required this.noCommitCount,
    this.unknownReason,
  });

  final GroupLagOutcome outcome;
  final int? totalLag;
  final int noCommitCount;
  final String? unknownReason;
}

/// Summarizes a list of partition lags (and optional group-level error)
/// without summing placeholder zeros from `NoCommit` or `Unknown` partitions.
GroupLagSummary summarizePartitionLags(
  List<TopicPartitionLag> partitionLags, {
  String? groupLagError,
}) {
  if (groupLagError != null && groupLagError.isNotEmpty) {
    return GroupLagSummary(
      outcome: GroupLagOutcome.unknown,
      totalLag: null,
      noCommitCount: 0,
      unknownReason: groupLagError,
    );
  }

  var noCommitCount = 0;
  var knownCount = 0;
  var sum = 0;

  for (final p in partitionLags) {
    switch (p.status) {
      case PartitionLagStatus.unknown:
        return GroupLagSummary(
          outcome: GroupLagOutcome.unknown,
          totalLag: null,
          noCommitCount: noCommitCount,
          unknownReason: p.error,
        );
      case PartitionLagStatus.noCommit:
        noCommitCount++;
      case PartitionLagStatus.known:
        knownCount++;
        sum += p.lag.toInt();
    }
  }

  if (knownCount == 0) {
    return GroupLagSummary(
      outcome: GroupLagOutcome.noCommittedOffsets,
      totalLag: null,
      noCommitCount: noCommitCount,
    );
  }

  return GroupLagSummary(
    outcome: GroupLagOutcome.known,
    totalLag: sum,
    noCommitCount: noCommitCount,
  );
}

GroupLagSummary summarizeGroupLag(ConsumerGroupLag group) {
  return summarizePartitionLags(
    group.partitionLags,
    groupLagError: group.lagError,
  );
}

/// Returns the group's known total lag, or `null` when the group has no
/// committed offsets or its lag is unknown.
int? knownGroupLag(ConsumerGroupLag group) {
  return summarizeGroupLag(group).totalLag;
}
