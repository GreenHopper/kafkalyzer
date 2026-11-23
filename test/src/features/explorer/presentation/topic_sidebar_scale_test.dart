import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_list_item.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/services/topic_store.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/features/cluster/data/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_list_preferences_service.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ScaleFakeMetadataService implements KafkaMetadataService {
  final List<TopicMetadata> topics;

  _ScaleFakeMetadataService(this.topics);

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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScaleFakeSchemaService implements SchemaRegistryService {
  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScaleFakeProfileTools implements ClusterProfileTools {
  @override
  List<BootstrapServerIssue> validateBootstrapServers(String value) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ScaleFakeClusterService extends ClusterService {
  final List<ClusterProfile> profiles;

  _ScaleFakeClusterService(this.profiles);

  @override
  Future<List<ClusterProfile>> loadClusters() async => profiles;
}

void main() {
  testWidgets(
    'sidebar with 10 000 topics renders <= 60 TopicListItems and recomputes once per typed char',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      await getIt.reset();

      const profile = ClusterProfile(
        name: 'scale-cluster',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.enabled,
      );

      final allTopics = List.generate(
        10000,
        (i) => TopicMetadata(
          name: 'domain.team-${i % 20}.topic-${i.toString().padLeft(5, '0')}',
          partitionCount: (i % 6) + 1,
          replicationFactor: 1,
        ),
      );

      getIt.registerLazySingleton<Logger>(() => Logger(level: Level.off));
      getIt.registerSingleton<KafkaMetadataService>(
        _ScaleFakeMetadataService(allTopics),
      );
      getIt.registerSingleton<SchemaRegistryService>(_ScaleFakeSchemaService());
      getIt.registerSingleton<ClusterService>(
        _ScaleFakeClusterService([profile]),
      );
      getIt.registerSingleton<ClusterProfileTools>(_ScaleFakeProfileTools());
      getIt.registerSingleton<RecentTopicsService>(RecentTopicsService());
      getIt.registerSingleton<TopicListPreferencesService>(
        TopicListPreferencesService(),
      );
      getIt.registerSingleton<TopicController>(TopicController());
      getIt.registerLazySingleton<TopicStore>(() => getIt<TopicController>());
      getIt.registerSingleton<SchemaController>(SchemaController());
      final clusterList = ClusterListController();
      await clusterList.loadClusters();
      getIt.registerSingleton<ClusterListController>(clusterList);
      final activeController = ActiveConnectionController();
      getIt.registerSingleton<ActiveConnectionController>(activeController);

      await activeController.connect(profile);
      await getIt<TopicController>().fetchTopics(profile);
      expect(activeController.error, isNull);
      expect(activeController.activeProfile, isNotNull);
      expect(
        getIt<TopicController>().topicListView(profile).visibleTopics.length,
        10000,
      );

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
      await tester.pump();

      final initialItems = find.byType(TopicListItem).evaluate().length;
      expect(initialItems, greaterThan(0));
      expect(initialItems, lessThanOrEqualTo(60));

      final computationsBeforeType = getIt<TopicController>().viewComputations;
      await tester.enterText(
        find.byKey(const Key('topic_filter_text_field')),
        '9',
      );
      await tester.pump();

      final afterTypeItems = find.byType(TopicListItem).evaluate().length;
      expect(afterTypeItems, lessThanOrEqualTo(60));
      expect(
        getIt<TopicController>().viewComputations,
        equals(computationsBeforeType + 1),
      );
    },
  );
}
