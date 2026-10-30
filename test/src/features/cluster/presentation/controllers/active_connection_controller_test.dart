import 'dart:async';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  @override
  void e(
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
  Future<bool> Function({required ClusterProfile profile})? onValidate;

  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async {
    if (onValidate != null) {
      return onValidate!(profile: profile);
    }
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
  List<TopicMetadata> topics = [];

  @override
  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    // No-op
  }

  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) => topics;

  @override
  bool isLoading(ClusterProfile cluster) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ActiveConnectionController controller;
  late MockKafkaMetadataService mockMetadataService;
  late MockTopicController mockTopicController;
  late SessionRestoreService sessionRestoreService;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    getIt.registerLazySingleton<Logger>(() => MockLogger());

    sessionRestoreService = SessionRestoreService();
    getIt.registerSingleton<SessionRestoreService>(sessionRestoreService);

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

    test(
      'tracks connectingProfile and isConnecting during in-flight validation and clears on success',
      () async {
        final completer = Completer<bool>();
        mockMetadataService.onValidate = ({required profile}) =>
            completer.future;

        expect(controller.connectingProfile, isNull);
        expect(controller.isConnecting, isFalse);

        final connectFuture = controller.connect(validProfile);

        // Verify connecting state immediately set
        expect(controller.connectingProfile, equals(validProfile));
        expect(controller.isConnectingCluster(validProfile), isTrue);
        expect(controller.isConnecting, isTrue);
        expect(controller.activeProfile, isNull);

        completer.complete(true);
        await connectFuture;

        expect(controller.connectingProfile, isNull);
        expect(controller.isConnectingCluster(validProfile), isFalse);
        expect(controller.isConnecting, isFalse);
        expect(controller.activeProfile, equals(validProfile));
      },
    );

    test(
      'tracks connectingProfile during timeout/failure and clears cleanly with error recorded',
      () async {
        final completer = Completer<bool>();
        mockMetadataService.onValidate = ({required profile}) =>
            completer.future;

        final connectFuture = controller.connect(validProfile);

        expect(controller.connectingProfile, equals(validProfile));
        expect(controller.isConnecting, isTrue);
        expect(controller.activeProfile, isNull);

        completer.completeError(
          Exception('BrokerTransportFailure: Connection timed out'),
        );
        await connectFuture;

        expect(controller.connectingProfile, isNull);
        expect(controller.isConnecting, isFalse);
        expect(controller.activeProfile, isNull);
        expect(controller.error, contains('Broker Transport Failure'));
      },
    );

    test(
      'ignores duplicate concurrent connect calls to the same connecting profile',
      () async {
        int validateCallCount = 0;
        final completer = Completer<bool>();
        mockMetadataService.onValidate = ({required profile}) {
          validateCallCount++;
          return completer.future;
        };

        final future1 = controller.connect(validProfile);
        final future2 = controller.connect(validProfile);

        expect(validateCallCount, equals(1));
        completer.complete(true);
        await Future.wait([future1, future2]);
        expect(validateCallCount, equals(1));
      },
    );

    test('disconnect clears state', () async {
      mockMetadataService.shouldValidate = true;
      await controller.connect(validProfile);
      expect(controller.activeProfile, isNotNull);

      controller.openTopic(
        topic: const TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        ),
      );

      controller.disconnect();

      expect(controller.activeProfile, isNull);
      expect(controller.error, isNull);
      // No topic view survives a disconnect, so no health state stays live.
      expect(controller.openTopics, isEmpty);
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

    test(
      'streamTopicWithDefaults opens tab, selects it, and starts stream controller',
      () async {
        mockMetadataService.shouldValidate = true;
        await controller.connect(validProfile);

        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        );

        final tab = controller.streamTopicWithDefaults(topic1);

        expect(tab, isNotNull);
        expect(controller.openTopics.length, equals(1));
        expect(controller.activeTopic?.id, equals(tab?.id));
        expect(controller.activeTopic?.topic.name, equals('orders'));

        final streamController = controller.getStreamController(tab!.id);
        expect(streamController, isNotNull);
      },
    );

    test(
      'automatically saves open tabs and restores them on reconnection',
      () async {
        mockMetadataService.shouldValidate = true;
        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 1,
        );
        const topic2 = TopicMetadata(
          name: 'payments',
          partitionCount: 3,
          replicationFactor: 1,
        );

        mockTopicController.topics = [topic1, topic2];

        await controller.connect(validProfile);
        controller.openTopic(topic: topic1);
        controller.openTopic(topic: topic2);

        // Verify session was saved
        final session = await sessionRestoreService.getSession(
          validProfile.name,
        );
        expect(session, isNotNull);
        expect(session!.openTopicNames, containsAll(['orders', 'payments']));
        expect(session.activeTopicName, 'payments');

        // Now create a fresh controller and connect again (simulating app restart)
        final newController = ActiveConnectionController();
        expect(newController.openTopics, isEmpty);

        await newController.connect(validProfile);

        // Tabs should be restored
        expect(newController.openTopics.length, 2);
        expect(
          newController.openTopics.map((t) => t.topic.name),
          containsAll(['orders', 'payments']),
        );
        expect(newController.activeTopic?.topic.name, 'payments');
      },
    );

    test('bypasses tab restoration when restore setting is disabled', () async {
      mockMetadataService.shouldValidate = true;
      const topic1 = TopicMetadata(
        name: 'orders',
        partitionCount: 3,
        replicationFactor: 1,
      );
      mockTopicController.topics = [topic1];

      await sessionRestoreService.saveSession(
        validProfile.name,
        openTopicNames: ['orders'],
        activeTopicName: 'orders',
      );
      await sessionRestoreService.setRestorationEnabled(false);

      final newController = ActiveConnectionController();
      await newController.connect(validProfile);

      // Restoration disabled, so openTopics should remain empty
      expect(newController.openTopics, isEmpty);
      expect(newController.activeTopic, isNull);
    });
  });
}
