import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

class ClusterSummary {
  final int totalTopics;
  final int totalPartitions;
  final int unhealthyTopicCount;
  final int underReplicatedPartitions;
  final int leaderlessPartitions;
  final int unknownHealthTopicCount;

  const ClusterSummary({
    required this.totalTopics,
    required this.totalPartitions,
    required this.unhealthyTopicCount,
    required this.underReplicatedPartitions,
    required this.leaderlessPartitions,
    required this.unknownHealthTopicCount,
  });
}

/// Summarizes topic/partition totals and replication health across all loaded
/// topics (including internal topics).
ClusterSummary summarizeCluster(List<TopicMetadata> topics) {
  var totalPartitions = 0;
  var unhealthyTopicCount = 0;
  var underReplicatedPartitions = 0;
  var leaderlessPartitions = 0;
  var unknownHealthTopicCount = 0;

  for (final topic in topics) {
    if (topic.metadataError == null) {
      totalPartitions += topic.partitionCount;
    }

    final urp = topic.underReplicatedPartitions;
    final llp = topic.leaderlessPartitions;
    if (topic.metadataError != null || urp == null || llp == null) {
      unknownHealthTopicCount++;
      continue;
    }

    if (urp > 0 || llp > 0) {
      unhealthyTopicCount++;
      underReplicatedPartitions += urp;
      leaderlessPartitions += llp;
    }
  }

  return ClusterSummary(
    totalTopics: topics.length,
    totalPartitions: totalPartitions,
    unhealthyTopicCount: unhealthyTopicCount,
    underReplicatedPartitions: underReplicatedPartitions,
    leaderlessPartitions: leaderlessPartitions,
    unknownHealthTopicCount: unknownHealthTopicCount,
  );
}
