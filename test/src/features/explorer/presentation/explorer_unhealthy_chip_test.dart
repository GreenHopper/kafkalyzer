import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/services/topic_list_preferences_service.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMetadataService implements KafkaMetadataService {
  final List<TopicMetadata> topics;

  _FakeMetadataService(this.topics);

  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async =>
      true;

  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async => topics;

  @override
  Future<List<TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) async => [
    for (final t in topics)
      TopicConfigResult(
        topic: t,
        status: TopicConfigStatus.available,
        entries: const [],
      ),
  ];

  @override
  Future<ClusterOverview> fetchClusterOverview({
    required ClusterProfile profile,
  }) async => const ClusterOverview(
    brokers: [BrokerEndpoint(id: 1, host: 'localhost', port: 9092)],
    clusterId: 'cid',
    controllerId: 1,
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSchemaService implements SchemaRegistryService {
  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClusterService implements ClusterService {
  final List<ClusterProfile> clusters;
  _FakeClusterService(this.clusters);

  @override
  Future<List<ClusterProfile>> loadClusters() async => clusters;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfileTools implements ClusterProfileTools {
  @override
  List<BootstrapServerIssue> validateBootstrapServers(String input) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'sidebar shows unhealthy filter chip after showUnhealthyTopicsOnly and clears on delete',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const profile = ClusterProfile(
        name: 'test-cluster',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.disabled,
      );

      final topics = const [
        TopicMetadata(
          name: 'healthy-orders',
          partitionCount: 3,
          replicationFactor: 3,
          underReplicatedPartitions: 0,
          leaderlessPartitions: 0,
        ),
        TopicMetadata(
          name: 'broken-payments',
          partitionCount: 3,
          replicationFactor: 3,
          underReplicatedPartitions: 1,
          leaderlessPartitions: 0,
        ),
      ];

      getIt.registerLazySingleton<Logger>(() => Logger(level: Level.off));
      getIt.registerSingleton<KafkaMetadataService>(
        _FakeMetadataService(topics),
      );
      getIt.registerSingleton<SchemaRegistryService>(_FakeSchemaService());
      getIt.registerSingleton<ClusterService>(_FakeClusterService([profile]));
      getIt.registerSingleton<ClusterProfileTools>(_FakeProfileTools());
      getIt.registerSingleton<RecentTopicsService>(RecentTopicsService());
      getIt.registerSingleton<TopicListPreferencesService>(
        TopicListPreferencesService(),
      );
      getIt.registerSingleton<TopicController>(TopicController());
      getIt.registerSingleton<SchemaController>(SchemaController());
      getIt.registerSingleton<ClusterOverviewController>(
        ClusterOverviewController(),
      );
      final clusterList = ClusterListController();
      await clusterList.loadClusters();
      getIt.registerSingleton<ClusterListController>(clusterList);
      final activeController = ActiveConnectionController();
      getIt.registerSingleton<ActiveConnectionController>(activeController);

      await activeController.connect(profile);
      await getIt<TopicController>().fetchTopics(profile);
      expect(activeController.error, isNull);
      expect(activeController.topics.length, 2);
      expect(activeController.topicListView.visibleTopics.length, 2);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: [Locale('en')],
          home: Scaffold(body: ExplorerView()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TopicListItem), findsNWidgets(2));

      Finder findTopicItem(String name) => find.byWidgetPredicate(
        (w) => w is TopicListItem && w.topic.name == name,
      );

      expect(find.byKey(const Key('topic_unhealthy_only_chip')), findsNothing);
      expect(findTopicItem('healthy-orders'), findsOneWidget);
      expect(findTopicItem('broken-payments'), findsOneWidget);

      activeController.showUnhealthyTopicsOnly();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('topic_unhealthy_only_chip')),
        findsOneWidget,
      );
      expect(find.text('Only unhealthy topics (1)'), findsOneWidget);
      expect(findTopicItem('healthy-orders'), findsNothing);
      expect(findTopicItem('broken-payments'), findsOneWidget);

      // Tap delete icon on the InputChip
      final deleteIcon = find
          .descendant(
            of: find.byKey(const Key('topic_unhealthy_only_chip')),
            matching: find.byType(Icon),
          )
          .last;
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(activeController.unhealthyTopicsOnly, isFalse);
      expect(find.byKey(const Key('topic_unhealthy_only_chip')), findsNothing);
      expect(findTopicItem('healthy-orders'), findsOneWidget);
      expect(findTopicItem('broken-payments'), findsOneWidget);
    },
  );
}
