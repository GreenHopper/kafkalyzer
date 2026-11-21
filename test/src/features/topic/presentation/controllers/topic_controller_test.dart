import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:logger/logger.dart';

class _StubKafkaMetadataService extends KafkaMetadataService {
  Future<List<TopicMetadata>> Function(ClusterProfile)? onFetchTopics;
  Future<TopicMetadata> Function(ClusterProfile, String)? onFetchTopicMetadata;
  Future<List<TopicConfigResult>> Function(ClusterProfile, List<String>)?
  onDescribeTopicConfigs;

  final List<List<String>> configCalls = [];
  int fetchTopicMetadataCalls = 0;

  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async {
    if (onFetchTopics != null) {
      return onFetchTopics!(profile);
    }
    return [];
  }

  @override
  Future<TopicMetadata> fetchTopicMetadata({
    required ClusterProfile profile,
    required String topic,
  }) async {
    fetchTopicMetadataCalls++;
    if (onFetchTopicMetadata != null) {
      return onFetchTopicMetadata!(profile, topic);
    }
    return TopicMetadata(name: topic, partitionCount: 1, replicationFactor: 1);
  }

  @override
  Future<List<TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) async {
    configCalls.add(List<String>.from(topics));
    if (onDescribeTopicConfigs != null) {
      return onDescribeTopicConfigs!(profile, topics);
    }
    return [
      for (final t in topics)
        TopicConfigResult(
          topic: t,
          status: TopicConfigStatus.available,
          entries: const [
            TopicConfigEntry(
              name: 'cleanup.policy',
              value: 'delete',
              source: TopicConfigSource.default_,
              isDefault: true,
              isSensitive: false,
              isReadOnly: false,
            ),
          ],
        ),
    ];
  }
}

void main() {
  late _StubKafkaMetadataService stubService;
  late TopicController controller;

  const profile = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'broker:9092',
    tlsVerification: TlsVerification.enabled,
  );

  setUp(() async {
    stubService = _StubKafkaMetadataService();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    getIt.registerSingleton<KafkaMetadataService>(stubService);
    controller = TopicController();
  });

  tearDown(() async {});

  test(
    'failing fetchTopics exposes errorFor and later success clears it',
    () async {
      stubService.onFetchTopics = (_) async =>
          throw Exception('TLS handshake failed');

      await controller.fetchTopics(profile);

      expect(controller.getTopics(profile), isNull);
      expect(controller.errorFor(profile), contains('TLS handshake failed'));

      stubService.onFetchTopics = (_) async => const [
        TopicMetadata(name: 'orders', partitionCount: 1, replicationFactor: 1),
      ];
      await controller.fetchTopics(profile);
      await Future<void>.delayed(Duration.zero);

      expect(controller.errorFor(profile), isNull);
      expect(controller.getTopics(profile)?.map((t) => t.name), ['orders']);
      expect(controller.fetchedAt(profile), isNotNull);
    },
  );

  test(
    'failed force refresh keeps cached topics and fetchedAt while exposing errorFor',
    () async {
      stubService.onFetchTopics = (_) async => const [
        TopicMetadata(name: 'orders', partitionCount: 1, replicationFactor: 1),
      ];
      await controller.fetchTopics(profile);
      final initialFetchedAt = controller.fetchedAt(profile);
      expect(controller.getTopics(profile), hasLength(1));
      expect(initialFetchedAt, isNotNull);

      stubService.onFetchTopics = (_) async => throw Exception('Timed out');
      await controller.fetchTopics(profile, force: true);

      expect(controller.getTopics(profile)?.map((t) => t.name), ['orders']);
      expect(controller.fetchedAt(profile), initialFetchedAt);
      expect(controller.errorFor(profile), contains('Timed out'));
    },
  );

  test('250 topics produce 3 bridge calls of at most 100', () async {
    stubService.onFetchTopics = (_) async => [
      for (var i = 0; i < 250; i++)
        TopicMetadata(name: 't-$i', partitionCount: 1, replicationFactor: 1),
    ];

    await controller.fetchTopics(profile);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(stubService.configCalls, hasLength(3));
    expect(stubService.configCalls[0], hasLength(100));
    expect(stubService.configCalls[1], hasLength(100));
    expect(stubService.configCalls[2], hasLength(50));
    expect(
      controller.configFor(profile, 't-249').state,
      TopicConfigViewState.available,
    );
    expect(controller.configFor(profile, 't-0').cleanupPolicy, 'delete');
  });

  test('ensureConfig puts the requested topic into the next call', () async {
    final firstChunk = Completer<List<TopicConfigResult>>();
    var callIndex = 0;
    stubService.onFetchTopics = (_) async => [
      for (var i = 0; i < 250; i++)
        TopicMetadata(name: 't-$i', partitionCount: 1, replicationFactor: 1),
    ];
    stubService.onDescribeTopicConfigs = (_, topics) {
      callIndex++;
      if (callIndex == 1) {
        return firstChunk.future;
      }
      return Future.value([
        for (final t in topics)
          TopicConfigResult(
            topic: t,
            status: TopicConfigStatus.available,
            entries: const [],
          ),
      ]);
    };

    await controller.fetchTopics(profile);
    expect(stubService.configCalls, hasLength(1));

    // Topic t-245 would otherwise be in the 3rd chunk; ensureConfig moves it to front.
    controller.ensureConfig(profile, 't-245');

    firstChunk.complete([
      for (final t in stubService.configCalls[0])
        TopicConfigResult(
          topic: t,
          status: TopicConfigStatus.available,
          entries: const [],
        ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(stubService.configCalls[1].first, 't-245');
  });

  test('a failing chunk marks only its topics failed', () async {
    var callIndex = 0;
    stubService.onFetchTopics = (_) async => [
      for (var i = 0; i < 150; i++)
        TopicMetadata(name: 't-$i', partitionCount: 1, replicationFactor: 1),
    ];
    stubService.onDescribeTopicConfigs = (_, topics) async {
      callIndex++;
      if (callIndex == 1) {
        throw Exception('chunk 1 timed out');
      }
      return [
        for (final t in topics)
          TopicConfigResult(
            topic: t,
            status: TopicConfigStatus.available,
            entries: const [],
          ),
      ];
    };

    await controller.fetchTopics(profile);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      controller.configFor(profile, 't-0').state,
      TopicConfigViewState.failed,
    );
    expect(
      controller.configFor(profile, 't-99').state,
      TopicConfigViewState.failed,
    );
    expect(
      controller.configFor(profile, 't-100').state,
      TopicConfigViewState.available,
    );
  });

  test('refresh during loading drops stale config results', () async {
    final gen1Chunk = Completer<List<TopicConfigResult>>();
    var callIndex = 0;
    stubService.onFetchTopics = (_) async => [
      const TopicMetadata(name: 't-0', partitionCount: 1, replicationFactor: 1),
    ];
    stubService.onDescribeTopicConfigs = (_, topics) {
      callIndex++;
      if (callIndex == 1) {
        return gen1Chunk.future;
      }
      return Future.value([
        for (final t in topics)
          TopicConfigResult(
            topic: t,
            status: TopicConfigStatus.available,
            entries: const [
              TopicConfigEntry(
                name: 'cleanup.policy',
                value: 'compact',
                source: TopicConfigSource.dynamicTopic,
                isDefault: false,
                isSensitive: false,
                isReadOnly: false,
              ),
            ],
          ),
      ]);
    };

    await controller.fetchTopics(profile);
    // Generation 2 refresh while generation 1 config chunk is still pending.
    await controller.fetchTopics(profile, force: true);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(controller.configFor(profile, 't-0').cleanupPolicy, 'compact');

    // Now complete generation 1 with a different value; it must be dropped.
    gen1Chunk.complete(const [
      TopicConfigResult(
        topic: 't-0',
        status: TopicConfigStatus.notReadable,
        message: 'stale',
        entries: [],
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(
      controller.configFor(profile, 't-0').state,
      TopicConfigViewState.available,
    );
    expect(controller.configFor(profile, 't-0').cleanupPolicy, 'compact');
  });

  test('resolveTopic does not call the bridge for a listed topic', () async {
    stubService.onFetchTopics = (_) async => const [
      TopicMetadata(name: 'orders', partitionCount: 3, replicationFactor: 2),
    ];
    await controller.fetchTopics(profile);

    final resolved = await controller.resolveTopic(profile, 'orders');
    expect(resolved.partitionCount, 3);
    expect(stubService.fetchTopicMetadataCalls, 0);

    final missing = await controller.resolveTopic(profile, 'hidden-topic');
    expect(missing.name, 'hidden-topic');
    expect(stubService.fetchTopicMetadataCalls, 1);
  });
}
