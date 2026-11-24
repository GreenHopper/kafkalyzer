import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_view_controllers.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:logger/logger.dart';

ClusterProfile _profile(String name) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

void main() {
  final clusterA = _profile('cluster-a');
  final clusterB = _profile('cluster-b');

  test(
    'closing a tab on one cluster leaves the same-named topic on another cluster usable',
    () {
      final registry = TopicViewControllerRegistry();
      final keyA = TopicViewControllerRegistry.topicKey(
        'orders',
        clusterA.name,
      );
      final keyB = TopicViewControllerRegistry.topicKey(
        'orders',
        clusterB.name,
      );
      expect(keyA, isNot(equals(keyB)));

      final streamA = registry.stream(keyA);
      final streamB = registry.stream(keyB);
      final factsA = registry.facts(keyA, clusterA, 'orders');
      final factsB = registry.facts(keyB, clusterB, 'orders');
      expect(identical(streamA, streamB), isFalse);
      expect(identical(factsA, factsB), isFalse);

      registry.release([keyA]);

      // Cluster B keeps its instances: still the same, still answerable.
      expect(identical(registry.stream(keyB), streamB), isTrue);
      expect(
        identical(registry.facts(keyB, clusterB, 'orders'), factsB),
        isTrue,
      );
      expect(streamB.isStreaming, isFalse);
      expect(registry.hasRunningOperations([keyB]), isFalse);

      // Cluster A was released, so its next lookup starts clean.
      expect(identical(registry.stream(keyA), streamA), isFalse);
      expect(
        identical(registry.facts(keyA, clusterA, 'orders'), factsA),
        isFalse,
      );
    },
  );

  test(
    'refreshing the cached topic list keeps the per-topic controllers, clearing it releases them',
    () async {
      GetIt.instance.registerLazySingleton<Logger>(
        () => Logger(level: Level.off),
      );
      GetIt.instance.registerSingleton<KafkaMetadataService>(
        _FakeMetadataService(),
      );
      final topics = TopicController();
      final key = TopicViewControllerRegistry.topicKey('orders', clusterA.name);

      await topics.fetchTopics(clusterA);
      final before = topics.viewControllers.stream(key);

      await topics.fetchTopics(clusterA, force: true);
      expect(identical(topics.viewControllers.stream(key), before), isTrue);

      topics.clearCache(clusterA);
      final after = topics.viewControllers.stream(key);
      expect(identical(after, before), isFalse);
      expect(after, isA<MessageStreamController>());
    },
  );

  test('clearing the topic cache releases every per-topic controller', () {
    final registry = TopicViewControllerRegistry();
    final streamA = registry.stream(
      TopicViewControllerRegistry.topicKey('orders', clusterA.name),
    );
    registry.releaseAll();
    expect(
      identical(
        registry.stream(
          TopicViewControllerRegistry.topicKey('orders', clusterA.name),
        ),
        streamA,
      ),
      isFalse,
    );
  });
}

class _FakeMetadataService implements KafkaMetadataService {
  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async => [
    TopicMetadata(
      name: 'orders',
      partitionCount: 1,
      replicationFactor: 1,
      underReplicatedPartitions: 0,
      leaderlessPartitions: 0,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
