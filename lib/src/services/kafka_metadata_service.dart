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
}
