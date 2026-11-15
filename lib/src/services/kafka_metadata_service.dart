import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class KafkaMetadataService {
  Future<bool> validateConnection({required ClusterProfile profile}) {
    return api.validateConnection(profile: profile);
  }

  Future<List<api.TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) {
    return api.fetchTopics(profile: profile);
  }

  Future<api.TopicMetadata> fetchTopicMetadata({
    required ClusterProfile profile,
    required String topic,
  }) {
    return api.fetchTopicMetadata(profile: profile, topic: topic);
  }

  Future<List<api.TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) {
    return api.describeTopicConfigs(profile: profile, topics: topics);
  }

  Future<api.TopicPartitionDetails> fetchTopicPartitions({
    required ClusterProfile profile,
    required String topic,
  }) {
    return api.fetchTopicPartitions(profile: profile, topic: topic);
  }

  Future<List<ConsumerGroupLag>> fetchConsumerLags({
    required ClusterProfile profile,
  }) {
    return api.fetchConsumerLags(profile: profile);
  }

  Future<List<ConsumerGroupLag>> fetchConsumerGroups({
    required ClusterProfile profile,
  }) {
    return api.fetchConsumerGroups(profile: profile);
  }

  Future<ConsumerGroupLag> fetchConsumerGroupLag({
    required ClusterProfile profile,
    required String groupId,
  }) {
    return api.fetchConsumerGroupLag(profile: profile, groupId: groupId);
  }

  Future<List<ConsumerGroupLag>> fetchConsumerGroupLags({
    required ClusterProfile profile,
    required List<String> groupIds,
  }) {
    return api.fetchConsumerGroupLags(profile: profile, groupIds: groupIds);
  }

  Future<api.PartitionOffsetDistribution> fetchPartitionOffsets({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  }) {
    return api.fetchPartitionOffsets(
      profile: profile,
      topic: topic,
      skewThresholdPercent: skewThresholdPercent,
    );
  }

  Future<api.ClusterOverview> fetchClusterOverview({
    required ClusterProfile profile,
  }) {
    return api.fetchClusterOverview(profile: profile);
  }

  Future<api.TopicTimeRange> fetchTopicTimeRange({
    required ClusterProfile profile,
    required String topic,
  }) {
    return api.fetchTopicTimeRange(profile: profile, topic: topic);
  }
}
