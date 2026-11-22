import 'dart:async';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/topic_list_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

import '../../../../../helpers/fake_cluster_profile_tools.dart';

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
  Future<TopicMetadata> Function(ClusterProfile, String)? onFetchTopicMetadata;

  @override
  Future<TopicMetadata> fetchTopicMetadata({
    required ClusterProfile profile,
    required String topic,
  }) async {
    if (onFetchTopicMetadata != null) {
      return onFetchTopicMetadata!(profile, topic);
    }
    return TopicMetadata(name: topic, partitionCount: 1, replicationFactor: 1);
  }

  @override
  Future<List<TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) async => const [];

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
  List<TopicMetadata>? topicList = [];
  final List<String> clearedClusters = [];

  @override
  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    // No-op
  }

  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) => topicList;

  @override
  void clearCache(ClusterProfile cluster) {
    clearedClusters.add(cluster.name);
  }

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
    SharedPreferences.setMockInitialValues({});
    getIt.registerLazySingleton<Logger>(() => MockLogger());

    sessionRestoreService = SessionRestoreService();
    getIt.registerSingleton<SessionRestoreService>(sessionRestoreService);

    mockMetadataService = MockKafkaMetadataService();
    getIt.registerSingleton<KafkaMetadataService>(mockMetadataService);

    mockTopicController = MockTopicController();
    getIt.registerSingleton<TopicController>(mockTopicController);

    getIt.registerSingleton<ClusterProfileTools>(FakeClusterProfileTools());

    controller = ActiveConnectionController();
  });

  group('ActiveConnectionController', () {
    final validProfile = ClusterProfile(
      name: 'Test Cluster',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.enabled,
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
      expect(controller.error?.kind, ConnectionErrorKind.connectionRefused);
      expect(controller.error?.detail, contains('Connection Refused'));
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
        expect(controller.error?.kind, ConnectionErrorKind.brokerTransport);
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
        final viewControllers = getIt<TopicController>().viewControllers;
        final stream1 = viewControllers.stream(tab1!.id);
        final stream2 = viewControllers.stream(tab2!.id);
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

        final streamController = getIt<TopicController>().viewControllers
            .stream(tab!.id);
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

        mockTopicController.topicList = [topic1, topic2];

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
      mockTopicController.topicList = [topic1];

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

    group('TLS transition integration in connect()', () {
      const unreviewedProfile = ClusterProfile(
        name: 'Legacy TLS',
        bootstrapServers: 'broker:9093',
        securityProtocol: 'SSL',
        tlsVerification: TlsVerification.unreviewed,
      );

      test(
        'verified probe updates profile to enabled before validateConnection',
        () async {
          final validatedProfiles = <ClusterProfile>[];
          mockMetadataService.onValidate = ({required profile}) async {
            validatedProfiles.add(profile);
            return true;
          };

          final tlsController = TlsTransitionController(
            probeFn: (_) async =>
                const TlsProbeResult(outcome: TlsProbeOutcome.verified),
          );
          getIt.registerSingleton<TlsTransitionController>(tlsController);

          await controller.connect(unreviewedProfile);

          expect(validatedProfiles, hasLength(1));
          expect(
            validatedProfiles.first.tlsVerification,
            TlsVerification.enabled,
          );
          expect(
            controller.activeProfile?.tlsVerification,
            TlsVerification.enabled,
          );
          expect(controller.error, isNull);
        },
      );

      test(
        'rejected probe + keep verification on blocks connect without calling validateConnection',
        () async {
          var validateCalled = false;
          mockMetadataService.onValidate = ({required profile}) async {
            validateCalled = true;
            return true;
          };

          final tlsController = TlsTransitionController(
            probeFn: (_) async => const TlsProbeResult(
              outcome: TlsProbeOutcome.certificateRejected,
              message: 'self-signed cert',
            ),
          );
          getIt.registerSingleton<TlsTransitionController>(tlsController);

          final connectFuture = controller.connect(unreviewedProfile);
          await Future<void>.delayed(Duration.zero);
          expect(tlsController.currentDecision, isNotNull);

          await tlsController.resolveDecision(
            tlsController.currentDecision!,
            keepVerificationEnabled: true,
          );
          await connectFuture;

          expect(validateCalled, isFalse);
          expect(controller.activeProfile, isNull);
          expect(
            controller.error?.kind,
            ConnectionErrorKind.tlsVerificationFailed,
          );
          expect(controller.error?.detail, contains('self-signed cert'));
        },
      );

      test('rejected probe + disable connects with disabled profile', () async {
        final validatedProfiles = <ClusterProfile>[];
        mockMetadataService.onValidate = ({required profile}) async {
          validatedProfiles.add(profile);
          return true;
        };

        final tlsController = TlsTransitionController(
          probeFn: (_) async => const TlsProbeResult(
            outcome: TlsProbeOutcome.certificateRejected,
            message: 'self-signed cert',
          ),
        );
        getIt.registerSingleton<TlsTransitionController>(tlsController);

        final connectFuture = controller.connect(unreviewedProfile);
        await Future<void>.delayed(Duration.zero);
        expect(tlsController.currentDecision, isNotNull);

        await tlsController.resolveDecision(
          tlsController.currentDecision!,
          keepVerificationEnabled: false,
        );
        await connectFuture;

        expect(validatedProfiles, hasLength(1));
        expect(
          validatedProfiles.first.tlsVerification,
          TlsVerification.disabled,
        );
        expect(
          controller.activeProfile?.tlsVerification,
          TlsVerification.disabled,
        );
        expect(controller.error, isNull);
      });

      test(
        'inconclusive probe keeps verification on during validateConnection and marks enabled on success',
        () async {
          final validatedProfiles = <ClusterProfile>[];
          mockMetadataService.onValidate = ({required profile}) async {
            validatedProfiles.add(profile);
            return true;
          };

          final tlsController = TlsTransitionController(
            probeFn: (_) async => const TlsProbeResult(
              outcome: TlsProbeOutcome.inconclusive,
              message: 'timed out',
            ),
          );
          getIt.registerSingleton<TlsTransitionController>(tlsController);

          await controller.connect(unreviewedProfile);

          expect(validatedProfiles, hasLength(1));
          expect(
            validatedProfiles.first.tlsVerification,
            isNot(TlsVerification.disabled),
          );
          expect(
            controller.activeProfile?.tlsVerification,
            TlsVerification.enabled,
          );
        },
      );
    });

    group('Cluster-scoped disconnect, bootstrap guard, and sessions (B13)', () {
      const profileA = ClusterProfile(
        name: 'Cluster A',
        bootstrapServers: 'a:9092',
        tlsVerification: TlsVerification.enabled,
      );
      const profileB = ClusterProfile(
        name: 'Cluster B',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
      );

      TopicMetadata makeTopic(String name) =>
          TopicMetadata(name: name, partitionCount: 1, replicationFactor: 1);

      test(
        'connect rejects invalid stored bootstrap without calling validateConnection',
        () async {
          var validateCalls = 0;
          mockMetadataService.onValidate = ({required profile}) async {
            validateCalls++;
            return true;
          };

          const invalid = ClusterProfile(
            name: 'Broken',
            bootstrapServers: 'broker-without-port',
            tlsVerification: TlsVerification.enabled,
          );
          await controller.connect(invalid);

          expect(validateCalls, 0);
          expect(controller.activeProfile, isNull);
          expect(controller.connectingProfile, isNull);
          expect(
            controller.error?.kind,
            ConnectionErrorKind.invalidBootstrapServers,
          );
          expect(controller.error?.detail, contains('broker-without-port'));
        },
      );

      test(
        'disconnect is cluster-scoped, clears cache, and keeps session',
        () async {
          await sessionRestoreService.setRestorationEnabled(true);
          await controller.connect(profileA);
          controller.openTopic(topic: makeTopic('orders'), profile: profileA);

          await controller.connect(profileB);
          controller.openTopic(topic: makeTopic('payments'), profile: profileB);
          await Future<void>.delayed(Duration.zero);

          controller.disconnect();

          expect(controller.activeProfile, isNull);
          expect(mockTopicController.clearedClusters, ['Cluster B']);
          expect(
            controller.openTopics.map(
              (t) => '${t.profile.name}:${t.topic.name}',
            ),
            ['Cluster A:orders'],
          );

          final sessionB = await sessionRestoreService.getSession('Cluster B');
          expect(sessionB?.openTopicNames, ['payments']);
        },
      );

      test(
        'sessions stay isolated per cluster and closing non-active tab updates its own session',
        () async {
          await sessionRestoreService.setRestorationEnabled(true);
          await controller.connect(profileA);
          final tabA = controller.openTopic(
            topic: makeTopic('orders'),
            profile: profileA,
          )!;

          await controller.connect(profileB);
          controller.openTopic(topic: makeTopic('payments'), profile: profileB);
          await Future<void>.delayed(Duration.zero);

          var sessionA = await sessionRestoreService.getSession('Cluster A');
          var sessionB = await sessionRestoreService.getSession('Cluster B');
          expect(sessionA?.openTopicNames, ['orders']);
          expect(sessionB?.openTopicNames, ['payments']);

          controller.closeTopicTab(tabA.id);
          await Future<void>.delayed(Duration.zero);

          sessionA = await sessionRestoreService.getSession('Cluster A');
          sessionB = await sessionRestoreService.getSession('Cluster B');
          expect(sessionA?.openTopicNames, isEmpty);
          expect(sessionB?.openTopicNames, ['payments']);
        },
      );

      test(
        'restore reports missing topics and prunes them, while null topic list preserves session',
        () async {
          await sessionRestoreService.setRestorationEnabled(true);
          await sessionRestoreService.saveSession(
            'Cluster A',
            openTopicNames: ['orders', 'legacy-events'],
            activeTopicName: 'orders',
          );

          // Null topic list guard
          mockTopicController.topicList = null;
          await controller.connect(profileA);
          var sessionA = await sessionRestoreService.getSession('Cluster A');
          expect(sessionA?.openTopicNames, ['orders', 'legacy-events']);
          expect(controller.unrestoredTopics, isEmpty);

          // Now connect with only 'orders' present
          controller.disconnect();
          mockTopicController.topicList = [makeTopic('orders')];
          await controller.connect(profileA);
          await Future<void>.delayed(Duration.zero);

          expect(controller.openTopics.map((t) => t.topic.name), ['orders']);
          expect(controller.unrestoredTopics, ['legacy-events']);

          sessionA = await sessionRestoreService.getSession('Cluster A');
          expect(sessionA?.openTopicNames, ['orders']);
        },
      );
    });

    group('Topic list preferences, memoisation and openTopicByName (5.33)', () {
      test('preferences are saved and restored per cluster', () async {
        SharedPreferences.setMockInitialValues({});
        getIt.registerSingleton<TopicListPreferencesService>(
          TopicListPreferencesService(),
        );

        const clusterA = ClusterProfile(
          name: 'Cluster A',
          bootstrapServers: 'a:9092',
          tlsVerification: TlsVerification.enabled,
        );
        const clusterB = ClusterProfile(
          name: 'Cluster B',
          bootstrapServers: 'b:9092',
          tlsVerification: TlsVerification.enabled,
        );

        final topics = getIt<TopicController>();
        await controller.connect(clusterA);
        topics.toggleShowInternalTopics(true);
        topics.setTopicFilterMode(TopicFilterMode.regex);
        await Future<void>.delayed(Duration.zero);

        await controller.connect(clusterB);
        expect(topics.showInternalTopics, isFalse);
        expect(topics.topicFilterMode, TopicFilterMode.substring);

        await controller.connect(clusterA);
        expect(topics.showInternalTopics, isTrue);
        expect(topics.topicFilterMode, TopicFilterMode.regex);
      });

      test(
        'memoised topicListView does not recompute on 10 000 reads and increments by 1 on text change',
        () async {
          const cluster = ClusterProfile(
            name: 'Memo Cluster',
            bootstrapServers: 'a:9092',
            tlsVerification: TlsVerification.enabled,
          );
          await controller.connect(cluster);
          final topics = getIt<TopicController>();
          topics.viewComputations = 0;

          for (var i = 0; i < 10000; i++) {
            topics.topicListView(cluster);
            topics.topics(cluster);
          }
          expect(topics.viewComputations, 1);

          topics.updateTopicFilter('orders');
          topics.topicListView(cluster);
          expect(topics.viewComputations, 2);
        },
      );

      test(
        'openTopicByName handles listed, resolved-not-authorized and failing topics',
        () async {
          const cluster = ClusterProfile(
            name: 'Open Cluster',
            bootstrapServers: 'a:9092',
            tlsVerification: TlsVerification.enabled,
          );
          await controller.connect(cluster);

          // 1. Listed topic
          final listed = await controller.openTopicByName(
            cluster,
            'test-topic',
          );
          expect(listed?.topic.name, 'test-topic');

          // 2. Resolved not-authorized topic
          mockMetadataService.onFetchTopicMetadata = (_, name) async =>
              TopicMetadata(
                name: name,
                partitionCount: 0,
                replicationFactor: 0,
                metadataError: const TopicMetadataError(
                  kind: TopicMetadataErrorKind.notAuthorized,
                  message: 'Topic authorization failed',
                ),
              );
          final notAuth = await controller.openTopicByName(
            cluster,
            'secret-topic',
          );
          expect(notAuth?.topic.name, 'secret-topic');
          expect(
            notAuth?.topic.metadataError?.kind,
            TopicMetadataErrorKind.notAuthorized,
          );

          // 3. Failing topic rethrows and opens no tab
          final tabsBefore = controller.openTopics.length;
          mockMetadataService.onFetchTopicMetadata = (_, _) async =>
              throw Exception('broker unreachable');
          await expectLater(
            controller.openTopicByName(cluster, 'broken-topic'),
            throwsException,
          );
          expect(controller.openTopics.length, tabsBefore);
        },
      );
    });
  });
}
