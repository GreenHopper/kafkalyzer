import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/ui/widgets/error_banner.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/subject_browser_list.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as schema_api;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';

@GenerateMocks([
  ClusterListController,
  ActiveConnectionController,
  TopicController,
  SchemaController,
])
import 'explorer_view_test.mocks.dart';

/// The topic detail view loads partition health through this service; the
/// explorer tests only need the call to resolve.
class FakeMetadataService implements KafkaMetadataService {
  @override
  Future<TopicPartitionDetails> fetchTopicPartitions({
    required ClusterProfile profile,
    required String topic,
  }) async => TopicPartitionDetails(
    topic: topic,
    partitions: const [],
    brokers: const [],
  );

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

void main() {
  late MockClusterListController mockClusterListController;
  late MockActiveConnectionController mockActiveConnectionController;
  late MockTopicController mockTopicController;
  late MockSchemaController mockSchemaController;
  late FakeMessageStreamController fakeStreamController;
  late FakeTopicAnalysisController fakeAnalysisController;

  final testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    schemaRegistryUrl: 'http://localhost:8081',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
    tlsVerification: TlsVerification.enabled,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockClusterListController = MockClusterListController();
    mockActiveConnectionController = MockActiveConnectionController();
    // Use FixedMockTopicController to handle missing hasCachedTopics stub in generated mocks
    mockTopicController = FixedMockTopicController();
    mockSchemaController = FixedMockSchemaController();

    final getIt = GetIt.instance;
    getIt.registerLazySingleton<Logger>(() => MockLogger());
    getIt.registerSingleton<ClusterListController>(mockClusterListController);
    getIt.registerSingleton<ActiveConnectionController>(
      mockActiveConnectionController,
    );
    getIt.registerSingleton<TopicController>(mockTopicController);
    getIt.registerSingleton<SchemaController>(mockSchemaController);
    getIt.registerSingleton<RecentTopicsService>(RecentTopicsService());
    getIt.registerSingleton<KafkaMetadataService>(FakeMetadataService());
    getIt.registerSingleton<ClusterOverviewController>(
      ClusterOverviewController(),
    );

    // Stub ChangeNotifier methods to prevent watch_it hangs
    when(mockActiveConnectionController.addListener(any)).thenReturn(null);
    when(mockActiveConnectionController.removeListener(any)).thenReturn(null);
    when(mockActiveConnectionController.hasListeners).thenReturn(false);

    when(mockClusterListController.addListener(any)).thenReturn(null);
    when(mockClusterListController.removeListener(any)).thenReturn(null);
    when(mockClusterListController.hasListeners).thenReturn(false);

    when(mockTopicController.addListener(any)).thenReturn(null);
    when(mockTopicController.removeListener(any)).thenReturn(null);
    when(mockTopicController.hasListeners).thenReturn(false);

    when(mockSchemaController.addListener(any)).thenReturn(null);
    when(mockSchemaController.removeListener(any)).thenReturn(null);
    when(mockSchemaController.hasListeners).thenReturn(false);
    when(mockSchemaController.getSchemas(any)).thenReturn([]);
    when(mockSchemaController.isLoading(any)).thenReturn(false);
    when(mockTopicController.hasCachedTopics(any)).thenReturn(false);
    when(mockTopicController.getTopics(any)).thenReturn(const []);
    when(mockTopicController.findTopic(any, any)).thenReturn(null);
    when(mockTopicController.isLoading(any)).thenReturn(false);
    when(mockTopicController.fetchedAt(any)).thenReturn(null);
    when(
      mockTopicController.configFor(any, any),
    ).thenReturn(const TopicConfigView.loading());
    when(mockActiveConnectionController.topics).thenReturn(const []);
    when(
      mockActiveConnectionController.topicListQuery,
    ).thenReturn(const TopicListQuery());
    when(
      mockActiveConnectionController.topicFilterMode,
    ).thenReturn(TopicFilterMode.substring);
    when(
      mockActiveConnectionController.topicSortOrder,
    ).thenReturn(TopicSortOrder.name);
    when(mockActiveConnectionController.groupTopicsByPrefix).thenReturn(false);
    when(
      mockActiveConnectionController.favouriteTopics,
    ).thenReturn(const <String>{});
    when(
      mockActiveConnectionController.topicPreferencesUnreadable,
    ).thenReturn(false);
    when(
      mockActiveConnectionController.topicPreferencesWriteBlocked,
    ).thenReturn(false);
    when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
    when(mockActiveConnectionController.unhealthyTopicsOnly).thenReturn(false);
    when(
      mockActiveConnectionController.getTopicFactsController(
        any,
        any,
        any,
        any,
      ),
    ).thenAnswer(
      (inv) => TopicFactsController(
        profile: inv.positionalArguments[1] as ClusterProfile,
        topicName: inv.positionalArguments[2] as String,
      ),
    );
    when(mockActiveConnectionController.topicListView).thenAnswer(
      (_) => buildTopicListView(
        mockActiveConnectionController.topics,
        mockActiveConnectionController.topicListQuery,
      ),
    );
    fakeStreamController = FakeMessageStreamController();
    when(
      mockActiveConnectionController.getStreamController(any),
    ).thenReturn(fakeStreamController);
    when(
      mockActiveConnectionController.getStreamController(any, any),
    ).thenReturn(fakeStreamController);
    fakeAnalysisController = FakeTopicAnalysisController();
    when(
      mockActiveConnectionController.getAnalysisController(any),
    ).thenReturn(fakeAnalysisController);
    when(
      mockActiveConnectionController.getAnalysisController(any, any),
    ).thenReturn(fakeAnalysisController);
    when(
      mockActiveConnectionController.openTopic(
        topic: anyNamed('topic'),
        profile: anyNamed('profile'),
        forceNew: anyNamed('forceNew'),
      ),
    ).thenReturn(null);
    when(mockActiveConnectionController.connectingProfile).thenReturn(null);
    when(mockActiveConnectionController.unrestoredTopics).thenReturn(const []);
  });

  void stubIdleSidebarState() {
    when(mockClusterListController.isLoading).thenReturn(false);
    when(mockClusterListController.clusters).thenReturn([testProfile]);
    when(mockActiveConnectionController.activeProfile).thenReturn(null);
    when(mockActiveConnectionController.connectingProfile).thenReturn(null);
    when(mockActiveConnectionController.isConnecting).thenReturn(false);
    when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
    when(mockActiveConnectionController.error).thenReturn(null);
    when(mockActiveConnectionController.topicFilter).thenReturn('');
  }

  Widget createWidgetUnderTest({Locale? locale, ThemeData? theme}) {
    return MaterialApp(
      locale: locale,
      theme: theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: const Scaffold(body: ExplorerView()),
    );
  }

  group('ExplorerView', () {
    testWidgets('renders list of clusters', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump(); // Use pump instead of pumpAndSettle to avoid hangs

      expect(find.text('CLUSTERS'), findsOneWidget); // Sidebar header
      expect(find.text('test-cluster'), findsWidgets);
      expect(
        find.byType(ExplorerOnboardingView),
        findsOneWidget,
      ); // Onboarding state
    });

    testWidgets('shows topics when cluster is active', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.topics).thenReturn([
        const TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ]);
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.getTopics(testProfile)).thenReturn([
        const TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ]);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('test-topic'), findsOneWidget);
    });

    testWidgets('selects cluster on tap', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(mockActiveConnectionController.activeProfile).thenReturn(null);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.tap(find.text('test-cluster').first);
      await tester.pump();

      verify(mockActiveConnectionController.connect(testProfile)).called(1);
      verify(mockSchemaController.fetchSchemas(testProfile)).called(1);
    });

    testWidgets(
      'shows progress indicator next to connecting cluster in sidebar and disables repeat tap',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(mockActiveConnectionController.activeProfile).thenReturn(null);
        when(
          mockActiveConnectionController.connectingProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(true);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsWidgets);

        await tester.tap(find.text('test-cluster').first);
        await tester.pump();

        verifyNever(mockActiveConnectionController.connect(any));
      },
    );

    testWidgets('filtering updates topics', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockActiveConnectionController.topics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'filter');
      await tester.pump();

      verify(
        mockActiveConnectionController.updateTopicFilter('filter'),
      ).called(1);
    });

    testWidgets('toggle internal topics and stream topics via filter chips', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockActiveConnectionController.topics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final internalChip = find.widgetWithText(FilterChip, 'Internal Topics');
      final streamChip = find.widgetWithText(FilterChip, 'Stream Topics');

      expect(internalChip, findsOneWidget);
      expect(streamChip, findsOneWidget);

      await tester.tap(internalChip);
      await tester.pump();

      verify(
        mockActiveConnectionController.toggleShowInternalTopics(true),
      ).called(1);

      await tester.tap(streamChip);
      await tester.pump();

      verify(
        mockActiveConnectionController.toggleShowStreamTopics(true),
      ).called(1);
    });

    testWidgets(
      'displays disambiguated tab titles when multiple tabs are open for same topic',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const topic = TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        );

        final tab1 = OpenTopicRecord(topic, testProfile, id: 'tab-1');
        final tab2 = OpenTopicRecord(topic, testProfile, id: 'tab-2');

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn([topic]);
        when(
          mockActiveConnectionController.openTopics,
        ).thenReturn([tab1, tab2]);
        when(mockActiveConnectionController.activeTopic).thenReturn(tab1);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);
        when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('test-topic (1)'), findsOneWidget);
        expect(find.text('test-topic (2)'), findsOneWidget);
      },
    );

    testWidgets('allows opening a new tab from topic list item', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 1,
        replicationFactor: 1,
      );

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.topics).thenReturn([topic]);
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final openInNewTabButton = find.byTooltip('Open in New Tab');
      expect(openInNewTabButton, findsOneWidget);
      await tester.tap(openInNewTabButton);
      await tester.pump();

      verify(
        mockActiveConnectionController.openTopic(
          topic: topic,
          profile: testProfile,
          forceNew: true,
        ),
      ).called(1);
    });

    testWidgets(
      'double-clicking a topic list item triggers streamTopicWithDefaults',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const topic = TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        );

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn([topic]);
        when(mockActiveConnectionController.openTopics).thenReturn([]);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);
        when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);
        when(
          mockActiveConnectionController.streamTopicWithDefaults(
            topic,
            testProfile,
          ),
        ).thenReturn(null);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        final topicItem = find.text('test-topic');
        expect(topicItem, findsOneWidget);

        await tester.tap(topicItem);
        await tester.pump(const Duration(milliseconds: 50));
        await tester.tap(topicItem);
        await tester.pumpAndSettle();

        verify(
          mockActiveConnectionController.streamTopicWithDefaults(
            topic,
            testProfile,
          ),
        ).called(1);
      },
    );

    testWidgets('allows duplicating and closing a tab from the tab bar', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 1,
        replicationFactor: 1,
      );

      final tab1 = OpenTopicRecord(topic, testProfile, id: 'tab-1');

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.topics).thenReturn([topic]);
      when(mockActiveConnectionController.openTopics).thenReturn([tab1]);
      when(mockActiveConnectionController.activeTopic).thenReturn(tab1);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Duplicate tab
      final duplicateButton = find.byTooltip('Duplicate Tab');
      expect(duplicateButton, findsOneWidget);
      await tester.tap(duplicateButton);
      await tester.pump();

      verify(
        mockActiveConnectionController.openTopic(
          topic: topic,
          profile: testProfile,
          forceNew: true,
        ),
      ).called(1);

      // Close tab (no active operation — closes immediately)
      final closeButton = find.byTooltip('Close Tab');
      expect(closeButton, findsWidgets);
      await tester.tap(closeButton.first);
      await tester.pump();

      verify(mockActiveConnectionController.closeTopicTab('tab-1')).called(1);
    });

    testWidgets(
      'shows progress indicator in tab bar when analysis is running',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const topic = TopicMetadata(
          name: 'test-topic',
          partitionCount: 1,
          replicationFactor: 1,
        );

        final tab1 = OpenTopicRecord(topic, testProfile, id: 'tab-1');

        // Set analysis to running state
        fakeAnalysisController.startAnalysisTest(0.5);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn([topic]);
        when(mockActiveConnectionController.openTopics).thenReturn([tab1]);
        when(mockActiveConnectionController.activeTopic).thenReturn(tab1);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);
        when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        // The tab should show a LinearProgressIndicator for the analysis
        expect(find.byType(LinearProgressIndicator), findsWidgets);
      },
    );

    testWidgets('shows close confirmation dialog when analysis is running', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 1,
        replicationFactor: 1,
      );

      final tab1 = OpenTopicRecord(topic, testProfile, id: 'tab-1');

      // Set analysis to running state
      fakeAnalysisController.startAnalysisTest(0.3);

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.topics).thenReturn([topic]);
      when(mockActiveConnectionController.openTopics).thenReturn([tab1]);
      when(mockActiveConnectionController.activeTopic).thenReturn(tab1);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Tap close button
      final closeButton = find.byTooltip('Close Tab');
      await tester.tap(closeButton.first);
      await tester.pumpAndSettle();

      // Dialog should appear
      expect(find.text('Operation in Progress'), findsOneWidget);

      // Tap Cancel — tab should NOT close
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(mockActiveConnectionController.closeTopicTab('tab-1'));

      // Tap close button again, this time confirm
      await tester.tap(closeButton.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      verify(mockActiveConnectionController.closeTopicTab('tab-1')).called(1);
    });

    testWidgets('closes tab immediately when no operation is running', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 1,
        replicationFactor: 1,
      );

      final tab1 = OpenTopicRecord(topic, testProfile, id: 'tab-1');

      when(mockClusterListController.isLoading).thenReturn(false);
      when(mockClusterListController.clusters).thenReturn([testProfile]);
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.isConnecting).thenReturn(false);
      when(mockActiveConnectionController.showInternalTopics).thenReturn(false);
      when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
      when(
        mockActiveConnectionController.unhealthyTopicsOnly,
      ).thenReturn(false);
      when(
        mockActiveConnectionController.getTopicFactsController(
          any,
          any,
          any,
          any,
        ),
      ).thenAnswer(
        (inv) => TopicFactsController(
          profile: inv.positionalArguments[1] as ClusterProfile,
          topicName: inv.positionalArguments[2] as String,
        ),
      );
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.topics).thenReturn([topic]);
      when(mockActiveConnectionController.openTopics).thenReturn([tab1]);
      when(mockActiveConnectionController.activeTopic).thenReturn(tab1);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      // Tap close button — no dialog should appear
      final closeButton = find.byTooltip('Close Tab');
      await tester.tap(closeButton.first);
      await tester.pump();

      // No dialog
      expect(find.text('Operation in Progress'), findsNothing);

      // Tab should close immediately
      verify(mockActiveConnectionController.closeTopicTab('tab-1')).called(1);
    });

    testWidgets('collapses and expands topic sidebar via toggle buttons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      stubIdleSidebarState();

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(); // allow SharedPreferences load

      expect(find.text('CLUSTERS'), findsOneWidget);
      expect(
        find.byKey(const Key('explorer_collapse_sidebar')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('explorer_collapse_sidebar')));
      await tester.pumpAndSettle();

      expect(find.text('CLUSTERS'), findsNothing);
      expect(find.byKey(const Key('explorer_expand_sidebar')), findsOneWidget);

      await tester.tap(find.byKey(const Key('explorer_expand_sidebar')));
      await tester.pumpAndSettle();

      expect(find.text('CLUSTERS'), findsOneWidget);
      expect(
        find.byKey(const Key('explorer_collapse_sidebar')),
        findsOneWidget,
      );
    });

    testWidgets('Ctrl+B toggles topic sidebar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      stubIdleSidebarState();

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      expect(find.text('CLUSTERS'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('CLUSTERS'), findsNothing);
      expect(find.byKey(const Key('explorer_expand_sidebar')), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('CLUSTERS'), findsOneWidget);
    });

    testWidgets('persists topic sidebar collapsed preference', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      stubIdleSidebarState();

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      await tester.tap(find.byKey(const Key('explorer_collapse_sidebar')));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ExplorerView.sidebarCollapsedPrefKey), isTrue);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      expect(find.text('CLUSTERS'), findsNothing);
      expect(find.byKey(const Key('explorer_expand_sidebar')), findsOneWidget);
    });

    testWidgets('resizes topic sidebar by dragging handle and persists width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      stubIdleSidebarState();

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      final handleFinder = find.byKey(
        const Key('explorer_sidebar_resize_handle'),
      );
      expect(handleFinder, findsOneWidget);

      final sidebarFinder = find.byKey(const Key('explorer_sidebar_container'));
      expect(sidebarFinder, findsOneWidget);

      expect(
        tester.getSize(sidebarFinder).width,
        equals(ExplorerView.defaultSidebarWidth),
      );

      // Drag right by 80px -> 360 + 80 = 440
      await tester.drag(handleFinder, const Offset(80, 0));
      await tester.pumpAndSettle();

      expect(tester.getSize(sidebarFinder).width, equals(440.0));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getDouble(ExplorerView.sidebarWidthPrefKey), equals(440.0));

      // Drag left by 500px -> should clamp to minSidebarWidth (260)
      await tester.drag(handleFinder, const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(sidebarFinder).width,
        equals(ExplorerView.minSidebarWidth),
      );
      expect(
        prefs.getDouble(ExplorerView.sidebarWidthPrefKey),
        equals(ExplorerView.minSidebarWidth),
      );

      // Drag right by 800px -> should clamp to maxSidebarWidth (700)
      await tester.drag(handleFinder, const Offset(800, 0));
      await tester.pumpAndSettle();

      expect(
        tester.getSize(sidebarFinder).width,
        equals(ExplorerView.maxSidebarWidth),
      );
      expect(
        prefs.getDouble(ExplorerView.sidebarWidthPrefKey),
        equals(ExplorerView.maxSidebarWidth),
      );
    });

    testWidgets('restores topic sidebar width from preferences', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      stubIdleSidebarState();

      SharedPreferences.setMockInitialValues({
        ExplorerView.sidebarWidthPrefKey: 480.0,
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump();

      final sidebarFinder = find.byKey(const Key('explorer_sidebar_container'));
      expect(tester.getSize(sidebarFinder).width, equals(480.0));
    });

    testWidgets(
      'shows InsecureTlsBadge on sidebar cluster entry and NOT on open topic tabs',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const disabledProfile = ClusterProfile(
          name: 'insecure-cluster',
          bootstrapServers: 'b:9093',
          securityProtocol: 'SSL',
          tlsVerification: TlsVerification.disabled,
        );
        const topic1 = TopicMetadata(
          name: 'orders',
          partitionCount: 1,
          replicationFactor: 1,
        );
        const topic2 = TopicMetadata(
          name: 'payments',
          partitionCount: 1,
          replicationFactor: 1,
        );
        final record1 = OpenTopicRecord(topic1, disabledProfile, id: 'tab-1');
        final record2 = OpenTopicRecord(topic2, disabledProfile, id: 'tab-2');
        final recordEnabled = OpenTopicRecord(
          topic1,
          testProfile,
          id: 'tab-enabled',
        );
        final streamCtrl = FakeMessageStreamController();
        final analysisCtrl = FakeTopicAnalysisController();

        when(mockClusterListController.isLoading).thenReturn(false);
        when(
          mockClusterListController.clusters,
        ).thenReturn([disabledProfile, testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(disabledProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(
          mockActiveConnectionController.topics,
        ).thenReturn([topic1, topic2]);
        when(
          mockActiveConnectionController.openTopics,
        ).thenReturn([record1, record2, recordEnabled]);
        when(mockActiveConnectionController.activeTopic).thenReturn(record1);
        when(
          mockActiveConnectionController.getStreamController(any),
        ).thenReturn(streamCtrl);
        when(
          mockActiveConnectionController.getAnalysisController(any),
        ).thenReturn(analysisCtrl);
        when(
          mockTopicController.hasCachedTopics(disabledProfile),
        ).thenReturn(true);
        when(
          mockTopicController.getTopics(disabledProfile),
        ).thenReturn([topic1, topic2]);
        when(mockTopicController.isLoading(disabledProfile)).thenReturn(false);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump();

        final sidebarFinder = find.byKey(
          const Key('explorer_sidebar_container'),
        );
        // Exactly one InsecureTlsBadge is shown, and it lives in the sidebar
        // cluster entry — none of the open topic tabs render it.
        expect(find.byType(InsecureTlsBadge), findsOneWidget);
        expect(
          find.descendant(
            of: sidebarFinder,
            matching: find.byType(InsecureTlsBadge),
          ),
          findsOneWidget,
        );

        // When the sidebar is dragged to its minimum width (260 px),
        // the badge switches to icon-only mode (icon + semantics preserved).
        final handleFinder = find.byKey(
          const Key('explorer_sidebar_resize_handle'),
        );
        await tester.drag(handleFinder, const Offset(-500, 0));
        await tester.pumpAndSettle();

        final badge = tester.widget<InsecureTlsBadge>(
          find.byType(InsecureTlsBadge),
        );
        expect(badge.iconOnly, isTrue);
        expect(find.byIcon(Icons.gpp_bad_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'displays topicController.errorFor in sidebar with retry action',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn([]);
        when(mockActiveConnectionController.openTopics).thenReturn([]);
        when(
          mockTopicController.hasCachedTopics(testProfile),
        ).thenReturn(false);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);
        when(mockTopicController.getTopics(testProfile)).thenReturn(null);
        (mockTopicController as FixedMockTopicController).mockError =
            'Metadata broker down';

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(find.text('Failed to load topics'), findsOneWidget);
        expect(find.text('Metadata broker down'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();
        verify(
          mockTopicController.fetchTopics(testProfile, force: true),
        ).called(1);
      },
    );

    testWidgets(
      'displays schemaController.errorFor in sidebar when subject fetch fails',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn([]);
        when(mockActiveConnectionController.openTopics).thenReturn([]);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);
        when(mockTopicController.getTopics(testProfile)).thenReturn([]);
        (mockSchemaController as FixedMockSchemaController).mockError =
            '401 Unauthorized';

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(
          find.text('Failed to load schemas: 401 Unauthorized'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'explorer refresh button meets 40x40 hit area under compact density and has German tooltip',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn(const []);
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.getTopics(testProfile)).thenReturn(const []);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);

        await tester.pumpWidget(
          createWidgetUnderTest(
            locale: const Locale('de'),
            theme: ThemeData(visualDensity: VisualDensity.compact),
          ),
        );
        await tester.pump();

        final refreshButton = find.byTooltip('Aktualisieren');
        expect(refreshButton, findsOneWidget);
        final size = tester.getSize(refreshButton);
        expect(size.width, greaterThanOrEqualTo(40.0));
        expect(size.height, greaterThanOrEqualTo(40.0));
      },
    );

    testWidgets(
      'tab close IconButton has tooltip, >= 24x24 hit area, and receives keyboard focus',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const topic = TopicMetadata(
          name: 'orders-topic',
          partitionCount: 3,
          replicationFactor: 1,
        );
        final tab1 = OpenTopicRecord(topic, testProfile, id: 'tab-1');
        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(mockActiveConnectionController.error).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn([topic]);
        when(mockActiveConnectionController.openTopics).thenReturn([tab1]);
        when(mockActiveConnectionController.activeTopic).thenReturn(tab1);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.getTopics(testProfile)).thenReturn([topic]);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);

        await tester.pumpWidget(
          createWidgetUnderTest(locale: const Locale('de')),
        );
        await tester.pump();

        final closeButton = find.byTooltip('Tab schließen').first;
        expect(closeButton, findsOneWidget);
        final size = tester.getSize(closeButton);
        expect(size.width, greaterThanOrEqualTo(24.0));
        expect(size.height, greaterThanOrEqualTo(24.0));

        final iconButtonFinder = find
            .ancestor(of: closeButton, matching: find.byType(IconButton))
            .first;
        final iconButtonWidget = tester.widget<IconButton>(iconButtonFinder);
        expect(iconButtonWidget.tooltip, 'Tab schließen');
        final focusable = tester.element(
          find
              .descendant(of: iconButtonFinder, matching: find.byType(Focus))
              .first,
        );
        Focus.of(focusable).requestFocus();
        await tester.pump();
        expect(Focus.of(focusable).hasFocus, isTrue);
      },
    );

    testWidgets(
      'connection error shows ErrorBanner in German, dismisses on close, and re-appears on next failure',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        ConnectionError? currentError = const ConnectionError(
          kind: ConnectionErrorKind.connectionRefused,
          detail: 'tcp://localhost:9092 refused',
        );
        when(mockClusterListController.isLoading).thenReturn(false);
        when(mockClusterListController.clusters).thenReturn([testProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.isConnecting).thenReturn(false);
        when(
          mockActiveConnectionController.showInternalTopics,
        ).thenReturn(false);
        when(mockActiveConnectionController.showStreamTopics).thenReturn(false);
        when(
          mockActiveConnectionController.unhealthyTopicsOnly,
        ).thenReturn(false);
        when(
          mockActiveConnectionController.getTopicFactsController(
            any,
            any,
            any,
            any,
          ),
        ).thenAnswer(
          (inv) => TopicFactsController(
            profile: inv.positionalArguments[1] as ClusterProfile,
            topicName: inv.positionalArguments[2] as String,
          ),
        );
        when(
          mockActiveConnectionController.error,
        ).thenAnswer((_) => currentError);
        when(mockActiveConnectionController.clearError()).thenAnswer((_) {
          currentError = null;
        });
        when(mockActiveConnectionController.topicFilter).thenReturn('');
        when(mockActiveConnectionController.topics).thenReturn(const []);
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.getTopics(testProfile)).thenReturn(const []);
        when(mockTopicController.isLoading(testProfile)).thenReturn(false);

        await tester.pumpWidget(
          createWidgetUnderTest(locale: const Locale('de')),
        );
        await tester.pump();

        expect(find.byType(ErrorBanner), findsOneWidget);
        expect(find.text('Verbindung abgelehnt'), findsOneWidget);
        expect(find.text('tcp://localhost:9092 refused'), findsOneWidget);

        await tester.tap(find.byTooltip('Schließen'));
        await tester.pump();
        verify(mockActiveConnectionController.clearError()).called(1);
        tester.element(find.byType(ExplorerView)).markNeedsBuild();
        await tester.pump();
        expect(find.byType(ErrorBanner), findsNothing);

        currentError = const ConnectionError(
          kind: ConnectionErrorKind.tlsVerificationFailed,
          detail: 'self-signed cert',
        );
        tester.element(find.byType(ExplorerView)).markNeedsBuild();
        await tester.pump();

        expect(find.byType(ErrorBanner), findsOneWidget);
        expect(
          find.text('TLS-Zertifikatsprüfung fehlgeschlagen'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows relative age text in German locale', (tester) async {
      stubIdleSidebarState();
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.openTopics).thenReturn(const []);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(
        mockTopicController.fetchedAt(testProfile),
      ).thenReturn(DateTime.now().subtract(const Duration(minutes: 5)));

      await tester.pumpWidget(
        createWidgetUnderTest(locale: const Locale('de')),
      );
      await tester.pump();

      expect(find.byKey(const Key('topic_list_age_label')), findsOneWidget);
      expect(find.text('vor 5 Min. aktualisiert'), findsOneWidget);
    });

    testWidgets('refresh button stays enabled while schema registry loads', (
      tester,
    ) async {
      stubIdleSidebarState();
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.openTopics).thenReturn(const []);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockSchemaController.isLoading(testProfile)).thenReturn(true);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final btn = tester.widget<IconButton>(
        find.byKey(const Key('explorer_refresh_topics_button')),
      );
      expect(btn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('explorer_refresh_topics_button')));
      await tester.pump();
      verify(
        mockTopicController.fetchTopics(testProfile, force: true),
      ).called(1);
    });

    testWidgets(
      'old topic list stays visible during refresh with inline progress',
      (tester) async {
        stubIdleSidebarState();
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopicController.isLoading(testProfile)).thenReturn(true);
        const cachedTopic = TopicMetadata(
          name: 'cached-orders',
          partitionCount: 3,
          replicationFactor: 1,
        );
        when(mockActiveConnectionController.topics).thenReturn([cachedTopic]);
        when(
          mockTopicController.getTopics(testProfile),
        ).thenReturn([cachedTopic]);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(
          find.byKey(const Key('topic_list_refresh_progress')),
          findsOneWidget,
        );
        expect(find.text('cached-orders'), findsOneWidget);
      },
    );

    testWidgets(
      'failed refresh with cached list shows inline notice and Retry',
      (tester) async {
        stubIdleSidebarState();
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        (mockTopicController as FixedMockTopicController).mockError = 'timeout';
        const cachedTopic = TopicMetadata(
          name: 'cached-orders',
          partitionCount: 3,
          replicationFactor: 1,
        );
        when(mockActiveConnectionController.topics).thenReturn([cachedTopic]);
        when(
          mockTopicController.getTopics(testProfile),
        ).thenReturn([cachedTopic]);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        expect(
          find.byKey(const Key('topic_list_refresh_error_notice')),
          findsOneWidget,
        );
        expect(find.text('Refresh failed: timeout'), findsOneWidget);
        expect(find.text('cached-orders'), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pump();
        verify(
          mockTopicController.fetchTopics(testProfile, force: true),
        ).called(1);
      },
    );

    testWidgets('shows invalid pattern error for invalid regex', (
      tester,
    ) async {
      stubIdleSidebarState();
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.openTopics).thenReturn(const []);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(
        mockActiveConnectionController.topicFilterMode,
      ).thenReturn(TopicFilterMode.regex);
      when(mockActiveConnectionController.topicFilter).thenReturn('[unclosed');
      when(mockActiveConnectionController.topicListQuery).thenReturn(
        const TopicListQuery(text: '[unclosed', mode: TopicFilterMode.regex),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(find.text('Invalid pattern'), findsOneWidget);
    });

    testWidgets('shows hidden count chip and calls showAllTopics on tap', (
      tester,
    ) async {
      stubIdleSidebarState();
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.openTopics).thenReturn(const []);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      const internalTopic = TopicMetadata(
        name: '__consumer_offsets',
        partitionCount: 50,
        replicationFactor: 1,
      );
      const visibleTopic = TopicMetadata(
        name: 'orders',
        partitionCount: 3,
        replicationFactor: 1,
      );
      when(
        mockActiveConnectionController.topics,
      ).thenReturn([internalTopic, visibleTopic]);
      when(
        mockTopicController.getTopics(testProfile),
      ).thenReturn([internalTopic, visibleTopic]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final chip = find.byKey(const Key('topic_hidden_count_chip'));
      expect(chip, findsOneWidget);
      expect(find.text('1 hidden · Show all'), findsOneWidget);

      await tester.tap(chip);
      await tester.pump();
      verify(mockActiveConnectionController.showAllTopics()).called(1);
    });

    testWidgets(
      'renders collapsible group headers and DLQ badges in grouped mode',
      (tester) async {
        stubIdleSidebarState();
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(testProfile);
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
        when(
          mockActiveConnectionController.groupTopicsByPrefix,
        ).thenReturn(true);
        when(
          mockActiveConnectionController.topicListQuery,
        ).thenReturn(const TopicListQuery(groupByPrefix: true));
        const topics = [
          TopicMetadata(
            name: 'orders.created',
            partitionCount: 3,
            replicationFactor: 1,
          ),
          TopicMetadata(
            name: 'orders.created-dlq',
            partitionCount: 1,
            replicationFactor: 1,
          ),
        ];
        when(mockActiveConnectionController.topics).thenReturn(topics);
        when(mockTopicController.getTopics(testProfile)).thenReturn(topics);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();

        final groupHeader = find.byKey(const Key('topic_group_header_orders'));
        expect(groupHeader, findsOneWidget);
        expect(find.text('DLQ'), findsOneWidget);

        await tester.tap(groupHeader);
        await tester.pump();
        verify(
          mockActiveConnectionController.toggleGroupCollapsed('orders'),
        ).called(1);
      },
    );

    testWidgets('pins favourites section at the top of the topic list', (
      tester,
    ) async {
      stubIdleSidebarState();
      when(
        mockActiveConnectionController.activeProfile,
      ).thenReturn(testProfile);
      when(mockActiveConnectionController.openTopics).thenReturn(const []);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(
        mockActiveConnectionController.favouriteTopics,
      ).thenReturn(const {'zebra'});
      when(
        mockActiveConnectionController.topicListQuery,
      ).thenReturn(const TopicListQuery(favourites: {'zebra'}));
      const topics = [
        TopicMetadata(name: 'alpha', partitionCount: 1, replicationFactor: 1),
        TopicMetadata(name: 'zebra', partitionCount: 1, replicationFactor: 1),
      ];
      when(mockActiveConnectionController.topics).thenReturn(topics);
      when(mockTopicController.getTopics(testProfile)).thenReturn(topics);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      expect(
        find.byKey(const Key('topic_favourites_section_header')),
        findsOneWidget,
      );
      expect(find.text('Favourites (1)'), findsOneWidget);
      expect(
        find.byKey(const Key('topic_favourite_button_zebra')),
        findsNWidgets(2),
      );
    });

    testWidgets(
      'tapping recent topic calls openTopicByName and shows loaded partition count',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        provideDummy<SchemaTypeState>(const SchemaTypeNotLoaded());
        stubIdleSidebarState();
        ClusterProfile? connectedProfile;
        final openTabs = <OpenTopicRecord>[];
        when(
          mockActiveConnectionController.activeProfile,
        ).thenAnswer((_) => connectedProfile);
        when(
          mockActiveConnectionController.openTopics,
        ).thenAnswer((_) => openTabs);
        when(
          mockActiveConnectionController.activeTopic,
        ).thenAnswer((_) => openTabs.isEmpty ? null : openTabs.first);
        when(mockActiveConnectionController.connect(testProfile)).thenAnswer((
          _,
        ) async {
          connectedProfile = testProfile;
        });
        await tester.runAsync(() async {
          final prefs = await SharedPreferences.getInstance();
          final svc = RecentTopicsService(prefs: prefs);
          await svc.recordVisit(
            clusterName: testProfile.name,
            topicName: 'recent-missing',
          );
          GetIt.instance.unregister<RecentTopicsService>();
          GetIt.instance.registerSingleton<RecentTopicsService>(svc);
        });

        when(
          mockActiveConnectionController.openTopicByName(
            testProfile,
            'recent-missing',
            forceNew: false,
          ),
        ).thenAnswer((_) async {
          final record = OpenTopicRecord(
            const TopicMetadata(
              name: 'recent-missing',
              partitionCount: 12,
              replicationFactor: 2,
            ),
            testProfile,
          );
          openTabs.add(record);
          return record;
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.text('recent-missing'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        verify(
          mockActiveConnectionController.openTopicByName(
            testProfile,
            'recent-missing',
            forceNew: false,
          ),
        ).called(1);
        tester.element(find.byType(ExplorerView)).markNeedsBuild();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('12 Partitions'), findsOneWidget);
      },
    );

    testWidgets(
      'failing openTopicByName from recent topic opens no tab and shows Retry SnackBar',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        provideDummy<SchemaTypeState>(const SchemaTypeNotLoaded());
        stubIdleSidebarState();
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockActiveConnectionController.activeTopic).thenReturn(null);
        when(
          mockActiveConnectionController.connect(testProfile),
        ).thenAnswer((_) async {});
        await tester.runAsync(() async {
          final prefs = await SharedPreferences.getInstance();
          final svc = RecentTopicsService(prefs: prefs);
          await svc.recordVisit(
            clusterName: testProfile.name,
            topicName: 'broken-topic',
          );
          GetIt.instance.unregister<RecentTopicsService>();
          GetIt.instance.registerSingleton<RecentTopicsService>(svc);
        });

        when(
          mockActiveConnectionController.openTopicByName(
            testProfile,
            'broken-topic',
            forceNew: false,
          ),
        ).thenThrow(Exception('broker unreachable'));

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        await tester.tap(find.text('broken-topic'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
        verifyNever(
          mockActiveConnectionController.openTopic(
            topic: anyNamed('topic'),
            profile: anyNamed('profile'),
            forceNew: anyNamed('forceNew'),
          ),
        );
      },
    );

    testWidgets(
      'Topics | Subjects switcher swaps sidebar, preserves topic filter, and opens SchemaViewerDialog',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        provideDummy<SchemaTypeState>(const SchemaTypeNotLoaded());
        stubIdleSidebarState();

        const srProfile = ClusterProfile(
          name: 'prod-sr',
          bootstrapServers: 'localhost:9092',
          schemaRegistryUrl: 'https://sr.internal:8081',
          tlsVerification: TlsVerification.enabled,
        );
        when(mockClusterListController.clusters).thenReturn([srProfile]);
        when(
          mockActiveConnectionController.activeProfile,
        ).thenReturn(srProfile);
        when(mockActiveConnectionController.openTopics).thenReturn(const []);
        when(mockActiveConnectionController.activeTopic).thenReturn(null);
        when(mockActiveConnectionController.topicFilter).thenReturn('orders');
        when(mockSchemaController.errorObjectFor(srProfile)).thenReturn(null);
        when(
          mockSchemaController.globalCompatibilityFor(srProfile),
        ).thenReturn('BACKWARD');
        when(mockTopicController.getTopics(srProfile)).thenReturn([
          const TopicMetadata(
            name: 'orders',
            partitionCount: 1,
            replicationFactor: 1,
          ),
        ]);
        when(
          mockSchemaController.getSchemas(srProfile),
        ).thenReturn(['orders-value']);
        when(
          mockSchemaController.associatedTopics(srProfile, ['orders']),
        ).thenReturn(const [
          schema_api.SubjectAssociationDto(
            subject: 'orders-value',
            topic: 'orders',
            side: schema_api.TopicSideDto.value,
            onCluster: true,
          ),
        ]);
        when(
          mockSchemaController.schemaTypeFor(srProfile, 'orders-value'),
        ).thenReturn(const SchemaTypeNotLoaded());
        when(
          mockSchemaController.fetchGlobalCompatibility(srProfile),
        ).thenAnswer((_) async => 'BACKWARD');
        when(
          mockSchemaController.fetchSchemaVersions(srProfile, 'orders-value'),
        ).thenAnswer((_) async => [1]);
        when(
          mockSchemaController.fetchSubjectSchemaView(
            srProfile,
            'orders-value',
            version: 1,
          ),
        ).thenAnswer(
          (_) async => const schema_api.SubjectSchemaViewDto(
            schema: schema_api.SubjectSchemaDto(
              subject: 'orders-value',
              version: 1,
              id: 1,
              schemaType: schema_api.SchemaKindDto.protobuf,
              schema: 'syntax = "proto3"; message Order {}',
              references: [],
            ),
            fields: schema_api.SchemaFieldModelDto(
              kind: schema_api.SchemaKindDto.protobuf,
              messages: ['Order'],
              fields: [],
              truncated: false,
            ),
          ),
        );
        when(
          mockSchemaController.fetchSubjectCompatibility(
            srProfile,
            'orders-value',
          ),
        ).thenAnswer((_) async => null);
        when(
          mockSchemaController.getAssociatedTopics('orders-value', ['orders']),
        ).thenAnswer((_) async => ['orders']);

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('explorer_browse_mode_switcher')),
          findsOneWidget,
        );

        // Switch to Subjects mode
        await tester.tap(find.text('Subjects'));
        await tester.pumpAndSettle();
        expect(find.byType(SubjectBrowserList), findsOneWidget);
        expect(find.text('orders-value'), findsOneWidget);

        // Tap subject -> opens SchemaViewerDialog with initialSubject
        await tester.tap(find.text('orders-value'));
        await tester.pumpAndSettle();
        expect(find.byType(SchemaViewerDialog), findsOneWidget);
        expect(find.text('Schema: orders-value'), findsOneWidget);

        // Close dialog and switch back to Topics -> topic filter preserved
        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Topics'));
        await tester.pumpAndSettle();
        expect(find.byType(SubjectBrowserList), findsNothing);
        expect(find.text('orders'), findsWidgets);
      },
    );
  });
}

class FixedMockTopicController extends MockTopicController {
  String? mockError;

  @override
  bool hasCachedTopics(ClusterProfile? cluster) {
    return super.noSuchMethod(
          Invocation.method(#hasCachedTopics, [cluster]),
          returnValue: false,
          returnValueForMissingStub: false,
        )
        as bool;
  }

  @override
  String? errorFor(ClusterProfile? cluster) => mockError;
}

class FixedMockSchemaController extends MockSchemaController {
  String? mockError;

  @override
  String? errorFor(ClusterProfile? cluster) => mockError;
}

class MockLogger extends Logger {
  @override
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

class FakeMessageStreamController extends ChangeNotifier
    implements MessageStreamController {
  bool streaming = false;
  double _progress = 0.0;
  DateTime? _startTime;

  @override
  List<KafkaMessage> get messages => [];

  @override
  bool get isStreaming => streaming;

  @override
  bool get isPaused => false;

  @override
  String? get error => null;

  @override
  int get droppedCount => 0;

  @override
  int get receivedCount => 0;

  @override
  int get totalConsumed => 0;

  @override
  int get totalToScan => 0;

  @override
  double get progress => _progress;

  @override
  DateTime? get startTime => _startTime;

  @override
  void clearMessages() {}

  void startStreamingTest(double progress) {
    streaming = true;
    _progress = progress;
    _startTime = DateTime.now().subtract(const Duration(seconds: 30));
    notifyListeners();
  }

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

class FakeTopicAnalysisController extends ChangeNotifier
    implements TopicAnalysisController {
  bool analyzing = false;
  double _progressRatio = 0.0;
  DateTime? _startTime;

  @override
  bool get isAnalyzing => analyzing;

  @override
  TopicAnalysisProgress? get progress => null;

  @override
  TopicAnalysisReport? get report => null;

  @override
  String? get error => null;

  @override
  DateTime? get startTime => _startTime;

  @override
  AnalysisScope get scope =>
      const AnalysisScope(limitFrom: ScopeLimitFrom.newest);

  @override
  double get progressRatio => _progressRatio;

  @override
  int get scannedMessages => 0;

  @override
  int get totalMessagesToScan => 0;

  @override
  double get messagesPerSecond => 0.0;

  @override
  void clear() {}

  @override
  Future<void> stopAnalysis() async {}

  void startAnalysisTest(double progressRatio) {
    analyzing = true;
    _progressRatio = progressRatio;
    _startTime = DateTime.now().subtract(const Duration(seconds: 30));
    notifyListeners();
  }

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
