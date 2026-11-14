import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/consumer/domain/consumer_lag_calculator.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

void main() {
  ConsumerGroupLag makeGroup({
    List<TopicPartitionLag> partitions = const [],
    String? lagError,
  }) {
    return ConsumerGroupLag(
      groupId: 'g1',
      state: 'Empty',
      protocolType: 'consumer',
      partitionLags: partitions,
      membersCount: 0,
      topicsCount: 1,
      members: const [],
      unassignedPartitions: const [],
      lagError: lagError,
      ownershipKnown: false,
    );
  }

  test('summarizeGroupLag excludes NoCommit and counts them', () {
    final group = makeGroup(
      partitions: const [
        TopicPartitionLag(
          topic: 'orders',
          partition: 0,
          logEndOffset: 150,
          currentOffset: 100,
          lag: 50,
          status: PartitionLagStatus.known,
        ),
        TopicPartitionLag(
          topic: 'orders',
          partition: 1,
          logEndOffset: 20,
          currentOffset: -1,
          lag: 0,
          status: PartitionLagStatus.noCommit,
        ),
      ],
    );

    final summary = summarizeGroupLag(group);
    expect(summary.outcome, GroupLagOutcome.known);
    expect(summary.totalLag, 50);
    expect(summary.noCommitCount, 1);
    expect(knownGroupLag(group), 50);
  });

  test(
    'summarizeGroupLag returns noCommittedOffsets when all NoCommit or empty',
    () {
      final emptyGroup = makeGroup();
      expect(
        summarizeGroupLag(emptyGroup).outcome,
        GroupLagOutcome.noCommittedOffsets,
      );
      expect(knownGroupLag(emptyGroup), isNull);

      final noCommitOnly = makeGroup(
        partitions: const [
          TopicPartitionLag(
            topic: 'orders',
            partition: 0,
            logEndOffset: 10,
            currentOffset: -1,
            lag: 0,
            status: PartitionLagStatus.noCommit,
          ),
        ],
      );
      final summary = summarizeGroupLag(noCommitOnly);
      expect(summary.outcome, GroupLagOutcome.noCommittedOffsets);
      expect(summary.totalLag, isNull);
      expect(summary.noCommitCount, 1);
    },
  );

  test(
    'summarizeGroupLag returns unknown on Unknown partition or group error',
    () {
      final unknownPartition = makeGroup(
        partitions: const [
          TopicPartitionLag(
            topic: 'orders',
            partition: 0,
            logEndOffset: 150,
            currentOffset: 100,
            lag: 50,
            status: PartitionLagStatus.known,
          ),
          TopicPartitionLag(
            topic: 'orders',
            partition: 1,
            logEndOffset: -1,
            currentOffset: -1,
            lag: 0,
            status: PartitionLagStatus.unknown,
            error: 'leader unavailable',
          ),
        ],
      );

      final pSummary = summarizeGroupLag(unknownPartition);
      expect(pSummary.outcome, GroupLagOutcome.unknown);
      expect(pSummary.totalLag, isNull);
      expect(pSummary.unknownReason, 'leader unavailable');

      final groupErr = makeGroup(lagError: 'GroupAuthorizationFailed');
      final gSummary = summarizeGroupLag(groupErr);
      expect(gSummary.outcome, GroupLagOutcome.unknown);
      expect(gSummary.totalLag, isNull);
      expect(gSummary.unknownReason, 'GroupAuthorizationFailed');
    },
  );
}
