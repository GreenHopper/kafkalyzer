import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

// Manual Mocks
class MockLogger extends Logger {
  @override
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // No-op
  }
}

class MockKafkaMetadataService extends KafkaMetadataService {
  bool shouldValidate = true;

  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async {
    if (!shouldValidate) throw Exception('Connection Refused');
    return true;
  }

  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async {
    return [];
  }
}

class MockTopicController extends TopicController {
  @override
  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    // No-op
  }

  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) => [];

  @override
  bool isLoading(ClusterProfile cluster) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ActiveConnectionController controller;
  late MockKafkaMetadataService mockMetadataService;
  late MockTopicController mockTopicController;

  setUp(() async {
    await getIt.reset();
    getIt.registerLazySingleton<Logger>(() => MockLogger());

    mockMetadataService = MockKafkaMetadataService();
    getIt.registerSingleton<KafkaMetadataService>(mockMetadataService);

    mockTopicController = MockTopicController();
    getIt.registerSingleton<TopicController>(mockTopicController);

    controller = ActiveConnectionController();
  });

  group('ActiveConnectionController', () {
    final validProfile = ClusterProfile(
      name: 'Test Cluster',
      bootstrapServers: 'localhost:9092',
    );

    test('connects successfully to a valid cluster', () async {
      mockMetadataService.shouldValidate = true;

      await controller.connect(validProfile);

      expect(controller.activeProfile, equals(validProfile));
      expect(controller.error, isNull);
      expect(controller.isConnecting, isFalse);
    });

    test('handles connection errors', () async {
      mockMetadataService.shouldValidate = false;

      await controller.connect(validProfile);

      expect(controller.activeProfile, isNull);
      expect(controller.error, isNotNull);
      expect(controller.error, contains('Connection Refused'));
      expect(controller.isConnecting, isFalse);
    });

    test('disconnect clears state', () async {
      mockMetadataService.shouldValidate = true;
      await controller.connect(validProfile);
      expect(controller.activeProfile, isNotNull);

      controller.disconnect();

      expect(controller.activeProfile, isNull);
      expect(controller.error, isNull);
    });
  });
}
