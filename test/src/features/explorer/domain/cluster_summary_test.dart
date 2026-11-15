import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/explorer/domain/cluster_summary.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

void main() {
  group('summarizeCluster', () {
    test('empty topic list returns all zeroes', () {
      final summary = summarizeCluster(const []);
      expect(summary.totalTopics, 0);
      expect(summary.totalPartitions, 0);
      expect(summary.unhealthyTopicCount, 0);
      expect(summary.underReplicatedPartitions, 0);
      expect(summary.leaderlessPartitions, 0);
      expect(summary.unknownHealthTopicCount, 0);
    });

    test(
      'healthy cluster sums topics and partitions including internal topics',
      () {
        final summary = summarizeCluster(const [
          TopicMetadata(
            name: 'orders',
            partitionCount: 12,
            replicationFactor: 3,
            underReplicatedPartitions: 0,
            leaderlessPartitions: 0,
          ),
          TopicMetadata(
            name: '__consumer_offsets',
            partitionCount: 50,
            replicationFactor: 3,
            underReplicatedPartitions: 0,
            leaderlessPartitions: 0,
          ),
        ]);
        expect(summary.totalTopics, 2);
        expect(summary.totalPartitions, 62);
        expect(summary.unhealthyTopicCount, 0);
        expect(summary.unknownHealthTopicCount, 0);
      },
    );

    test(
      'mixed cluster counts unhealthy topics, partition totals, and unknown health separately',
      () {
        final summary = summarizeCluster(const [
          TopicMetadata(
            name: 'topic-a',
            partitionCount: 6,
            replicationFactor: 3,
            underReplicatedPartitions: 1,
            leaderlessPartitions: 0,
          ),
          TopicMetadata(
            name: '__internal_b',
            partitionCount: 4,
            replicationFactor: 3,
            underReplicatedPartitions: 0,
            leaderlessPartitions: 2,
          ),
          TopicMetadata(
            name: 'topic-c',
            partitionCount: 3,
            replicationFactor: 3,
            underReplicatedPartitions: 0,
            leaderlessPartitions: 0,
          ),
          TopicMetadata(
            name: 'topic-unknown-1',
            partitionCount: 0,
            replicationFactor: 0,
            underReplicatedPartitions: null,
            leaderlessPartitions: null,
          ),
          TopicMetadata(
            name: 'topic-unknown-2',
            partitionCount: 0,
            replicationFactor: 0,
            underReplicatedPartitions: 0,
            leaderlessPartitions: 0,
            metadataError: TopicMetadataError(
              kind: TopicMetadataErrorKind.notAuthorized,
              message: 'denied',
            ),
          ),
        ]);
        expect(summary.totalTopics, 5);
        expect(summary.totalPartitions, 13);
        expect(summary.unhealthyTopicCount, 2);
        expect(summary.underReplicatedPartitions, 1);
        expect(summary.leaderlessPartitions, 2);
        expect(summary.unknownHealthTopicCount, 2);
      },
    );
  });
}
