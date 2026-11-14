import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:logger/logger.dart';

class _StubKafkaMetadataService extends KafkaMetadataService {
  Future<List<TopicMetadata>> Function(ClusterProfile)? onFetchTopics;

  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async {
    if (onFetchTopics != null) {
      return onFetchTopics!(profile);
    }
    return [];
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
    await getIt.reset();
    stubService = _StubKafkaMetadataService();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    getIt.registerSingleton<KafkaMetadataService>(stubService);
    controller = TopicController();
  });

  tearDown(() async {
    await getIt.reset();
  });

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

      expect(controller.errorFor(profile), isNull);
      expect(controller.getTopics(profile)?.map((t) => t.name), ['orders']);
    },
  );

  test(
    'failed force refresh keeps cached topics while exposing errorFor',
    () async {
      stubService.onFetchTopics = (_) async => const [
        TopicMetadata(name: 'orders', partitionCount: 1, replicationFactor: 1),
      ];
      await controller.fetchTopics(profile);
      expect(controller.getTopics(profile), hasLength(1));

      stubService.onFetchTopics = (_) async => throw Exception('Timed out');
      await controller.fetchTopics(profile, force: true);

      expect(controller.getTopics(profile)?.map((t) => t.name), ['orders']);
      expect(controller.errorFor(profile), contains('Timed out'));
    },
  );
}
