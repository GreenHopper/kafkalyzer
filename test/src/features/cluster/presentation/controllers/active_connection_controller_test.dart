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

    test('openTopic opens initial tab and selects it', () async {
      mockMetadataService.shouldValidate = true;
      await controller.connect(validProfile);

      const topic1 = TopicMetadata(
        name: 'orders',
        partitionCount: 3,
        replicationFactor: 1,
      );

      final tab = controller.openTopic(topic: topic1);

      expect(tab, isNotNull);
      expect(controller.openTopics.length, equals(1));
      expect(controller.activeTopic?.id, equals(tab?.id));
      expect(controller.activeTopic?.topic.name, equals('orders'));
    });

    test(
      'setActiveTopic selects existing tab without duplicating when forceNew is false',
      () async {
        mockMetadataService.shouldValidate = true;
        await controller.connect(validProfile);

        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        );

        controller.setActiveTopic(topic1);
        final initialTabId = controller.activeTopic?.id;
        expect(controller.openTopics.length, equals(1));

        // Call setActiveTopic again on the same topic
        controller.setActiveTopic(topic1);
        expect(controller.openTopics.length, equals(1));
        expect(controller.activeTopic?.id, equals(initialTabId));
      },
    );

    test(
      'openTopic with forceNew creates multiple independent tabs for same topic',
      () async {
        mockMetadataService.shouldValidate = true;
        await controller.connect(validProfile);

        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        );

        final tab1 = controller.openTopic(topic: topic1, forceNew: false);
        final tab2 = controller.openTopic(topic: topic1, forceNew: true);

        expect(controller.openTopics.length, equals(2));
        expect(tab1?.id, isNot(equals(tab2?.id)));
        expect(controller.activeTopic?.id, equals(tab2?.id));

        // Each tab has independent stream controller
        final stream1 = controller.getStreamController(tab1!.id);
        final stream2 = controller.getStreamController(tab2!.id);
        expect(identical(stream1, stream2), isFalse);
      },
    );

    test('setActiveTabId switches active tab', () async {
      mockMetadataService.shouldValidate = true;
      await controller.connect(validProfile);

      const topic1 = TopicMetadata(
        name: 'orders',
        partitionCount: 3,
        replicationFactor: 1,
      );

      final tab1 = controller.openTopic(topic: topic1, forceNew: false)!;
      final tab2 = controller.openTopic(topic: topic1, forceNew: true)!;
      expect(controller.activeTopic?.id, equals(tab2.id));

      controller.setActiveTabId(tab1.id);
      expect(controller.activeTopic?.id, equals(tab1.id));
    });

    test(
      'closeTopicTab closes only the target tab and preserves sibling tabs',
      () async {
        mockMetadataService.shouldValidate = true;
        await controller.connect(validProfile);

        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        );

        final tab1 = controller.openTopic(topic: topic1, forceNew: false)!;
        final tab2 = controller.openTopic(topic: topic1, forceNew: true)!;
        expect(controller.openTopics.length, equals(2));
        expect(controller.activeTopic?.id, equals(tab2.id));

        // Close tab2 (active)
        controller.closeTopicTab(tab2.id);

        expect(controller.openTopics.length, equals(1));
        expect(controller.openTopics.first.id, equals(tab1.id));
        expect(controller.activeTopic?.id, equals(tab1.id));

        // Close tab1 (last remaining)
        controller.closeTopicTab(tab1.id);
        expect(controller.openTopics.isEmpty, isTrue);
        expect(controller.activeTopic, isNull);
      },
    );

    test(
      'clearOpenTopics disposes all stream controllers and clears tabs',
      () async {
        mockMetadataService.shouldValidate = true;
        await controller.connect(validProfile);

        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        );

        controller.openTopic(topic: topic1, forceNew: false);
        controller.openTopic(topic: topic1, forceNew: true);
        expect(controller.openTopics.length, equals(2));

        controller.clearOpenTopics();
        expect(controller.openTopics.isEmpty, isTrue);
        expect(controller.activeTopic, isNull);
      },
    );
  });
}
