import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

const _profile = ClusterProfile(
  name: 'test-cluster',
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

/// Stands in for the topic cache: the port only reads `getTopics`.
class _StubTopics extends TopicController {
  _StubTopics(this._topics);

  final List<api.TopicMetadata>? _topics;

  @override
  List<api.TopicMetadata>? getTopics(ClusterProfile cluster) => _topics;
}

void main() {
  setUpAll(() {
    getIt.registerSingleton<KafkaMetadataService>(KafkaMetadataService());
  });

  test('answers the names of the cached topics', () {
    final source = CachedTopicNames(
      _StubTopics(const [
        api.TopicMetadata(
          name: 'orders',
          partitionCount: 1,
          replicationFactor: 1,
        ),
        api.TopicMetadata(
          name: 'audit',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ]),
    );

    expect(source.topicNames(_profile), ['orders', 'audit']);
  });

  test('answers unknown while the topic list is not loaded', () {
    expect(CachedTopicNames(_StubTopics(null)).topicNames(_profile), isNull);
  });
}
