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
}
