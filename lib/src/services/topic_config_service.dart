import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart' as api;

/// Thin Dart wrapper around the topic-config inspection and diff bridge calls.
class TopicConfigService {
  Future<api.TopicConfigSnapshot> fetchTopicConfig({
    required ClusterProfile profile,
    required String topic,
  }) => api.fetchTopicConfig(profile: profile, topic: topic);

  api.TopicConfigDiff diffTopicConfigs({
    required api.TopicConfigSnapshot left,
    required api.TopicConfigSnapshot right,
  }) => api.diffTopicConfigs(left: left, right: right);
}
