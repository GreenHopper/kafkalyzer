import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/command_palette_dialog.dart';
import 'package:kafkalyzer/src/features/navigation/command_palette/palette_sources.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_editor.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/features/settings/presentation/settings_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/features/cluster/data/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/projected_column.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/table_column_config.dart';
import 'package:kafkalyzer/src/features/messages/presentation/views/messages_table_view.dart';
import 'package:kafkalyzer/src/features/messages/presentation/widgets/message_inspector_panel.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/explorer/presentation/explorer_view_test.mocks.dart'
    as explorer_mocks;
import '../features/settings/presentation/settings_view_test.mocks.dart'
    as settings_mocks;
import '../rust/api/json_path_test_stub.dart';
import '../rust/api/rust_mocks.mocks.dart';

final _min24TapTargetGuideline = MinimumTapTargetGuideline(
  size: const Size(24, 24),
  link: 'accessibility-and-l10n-sweep',
);

class _QuietLogger extends Logger {
  @override
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}

  @override
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

class _FakeMessageStreamController extends ChangeNotifier
    implements MessageStreamController {
  @override
  List<KafkaMessage> get messages => const [];
  @override
  bool get isStreaming => false;
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
  double get progress => 0.0;
  @override
  DateTime? get startTime => null;
  @override
  void clearMessages() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTopicAnalysisController extends ChangeNotifier
    implements TopicAnalysisController {
  @override
  bool get isAnalyzing => false;
  @override
  TopicAnalysisProgress? get progress => null;
  @override
  TopicAnalysisReport? get report => null;
  @override
  String? get error => null;
  @override
  DateTime? get startTime => null;
  @override
  AnalysisScope get scope =>
      const AnalysisScope(limitFrom: ScopeLimitFrom.newest);
  @override
  double get progressRatio => 0.0;
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
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKafkaMetadataService implements KafkaMetadataService {
  List<ConsumerGroupLag> lags = const [];

  @override
  Future<api.TopicPartitionDetails> fetchTopicPartitions({
    required ClusterProfile profile,
    required String topic,
  }) async => api.TopicPartitionDetails(
    topic: topic,
    partitions: const [],
    brokers: const [],
  );

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroups({
    required ClusterProfile profile,
  }) async => lags;

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroupLags({
    required ClusterProfile profile,
    required List<String> groupIds,
  }) async => lags;

  @override
  Future<ConsumerGroupLag> fetchConsumerGroupLag({
    required ClusterProfile profile,
    required String groupId,
  }) async => lags.firstWhere((l) => l.groupId == groupId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _verifyGuidelines(WidgetTester tester) async {
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(_min24TapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
}

Widget _host(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  const testProfile = ClusterProfile(
    name: 'prod-cluster',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
  );

  const testTopic = api.TopicMetadata(
    name: 'orders.events',
    partitionCount: 3,
    replicationFactor: 1,
  );

  final testMessage = KafkaMessage(
    topic: 'orders.events',
    partition: 1,
    offset: 42,
    timestamp: 1695888000000,
    key: 'order-1',
    payload: '{"orderId":"1","status":"OK"}',
    headers: const [KafkaHeader(key: 'trace-id', value: 'abc-123')],
  );

  final mockRustApi = MockKafkalyzerRustLibApi();

  setUpAll(() {
    KafkalyzerRustLib.initMock(api: mockRustApi);
    stubJsonPathResolver(mockRustApi);
    when(
      mockRustApi.crateApiProfileToolsAllowedExtraProperties(),
    ).thenReturn(const []);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    getIt.registerSingleton<Logger>(_QuietLogger());
    getIt.registerSingleton<RecentTopicsService>(RecentTopicsService());
    getIt.registerSingleton<AppearanceSettings>(AppearanceSettings());
    getIt.registerSingleton<SessionRestoreService>(SessionRestoreService());
  });

  tearDown(() async {});

  final themes = <String, ThemeData>{
    'light': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.light,
      ),
    ),
    'dark': ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.indigo,
        brightness: Brightness.dark,
      ),
    ),
  };

  for (final entry in themes.entries) {
    final themeName = entry.key;
    final theme = entry.value;

    group('A11y guidelines ($themeName)', () {
      testWidgets('1. Explorer with open topic tab', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockClusters = explorer_mocks.MockClusterListController();
        final mockActive = explorer_mocks.MockActiveConnectionController();
        final mockTopics = explorer_mocks.MockTopicController();

        final registry = explorer_mocks.MockTopicViewControllerRegistry();

        when(mockTopics.viewControllers).thenReturn(registry);
        when(mockTopics.topicListenable).thenReturn(mockTopics);
        final mockSchemas = explorer_mocks.MockSchemaController();
        final streamCtrl = _FakeMessageStreamController();
        final analysisCtrl = _FakeTopicAnalysisController();
        final tab = OpenTopicRecord(testTopic, testProfile, id: 'tab-1');

        when(mockClusters.isLoading).thenReturn(false);
        when(mockClusters.isLoading).thenReturn(false);
        when(mockClusters.clusters).thenReturn([testProfile]);
        when(mockActive.activeProfile).thenReturn(testProfile);
        when(mockActive.isConnecting).thenReturn(false);
        when(mockActive.connectingProfile).thenReturn(null);
        when(mockTopics.showInternalTopics).thenReturn(false);
        when(mockTopics.showStreamTopics).thenReturn(false);
        when(mockActive.error).thenReturn(null);
        when(mockTopics.topicFilter).thenReturn('');
        when(mockTopics.topics(any)).thenReturn([testTopic]);
        when(mockTopics.topicListQuery).thenReturn(const TopicListQuery());
        when(mockTopics.topicFilterMode).thenReturn(TopicFilterMode.substring);
        when(mockTopics.topicSortOrder).thenReturn(TopicSortOrder.name);
        when(mockTopics.groupTopicsByPrefix).thenReturn(false);
        when(mockTopics.favouriteTopics).thenReturn(const <String>{});
        when(mockTopics.topicPreferencesUnreadable).thenReturn(false);
        when(mockTopics.topicPreferencesWriteBlocked).thenReturn(false);
        when(
          mockTopics.topicListView(any),
        ).thenReturn(buildTopicListView([testTopic], const TopicListQuery()));
        when(mockActive.openTopics).thenReturn([tab]);
        when(mockActive.activeTopic).thenReturn(tab);
        when(mockActive.unrestoredTopics).thenReturn(const []);
        when(registry.stream(any)).thenReturn(streamCtrl);
        when(registry.analysis(any)).thenReturn(analysisCtrl);
        when(mockTopics.unhealthyTopicsOnly).thenReturn(false);
        when(registry.facts(any, any, any)).thenReturn(
          TopicFactsController(profile: testProfile, topicName: testTopic.name),
        );
        when(mockTopics.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopics.getTopics(testProfile)).thenReturn([testTopic]);
        when(mockTopics.fetchedAt(testProfile)).thenReturn(null);
        when(mockTopics.findTopic(any, any)).thenReturn(null);
        when(
          mockTopics.configFor(any, any),
        ).thenReturn(const TopicConfigView.loading());
        when(mockTopics.isLoading(testProfile)).thenReturn(false);
        when(mockTopics.errorFor(any)).thenReturn(null);
        when(mockSchemas.isLoading(any)).thenReturn(false);
        when(mockSchemas.getSchemas(any)).thenReturn(const []);
        when(mockSchemas.errorFor(any)).thenReturn(null);

        getIt.registerSingleton<ClusterListController>(mockClusters);
        getIt.registerSingleton<ActiveConnectionController>(mockActive);
        getIt.registerSingleton<TopicController>(mockTopics);
        getIt.registerSingleton<SchemaController>(mockSchemas);
        getIt.registerSingleton<KafkaMetadataService>(
          _FakeKafkaMetadataService(),
        );

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_host(theme, const ExplorerView()));
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('2. MessagesTableView with projected column', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        const config = TableColumnConfig(
          projectedColumns: [ProjectedColumn(path: 'status', label: 'status')],
        );

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            theme,
            MessagesTableView(
              messages: [testMessage],
              columnConfig: config,
              onRemoveProjectedColumn: (_) {},
              onToggleColumnVisibility: (_) {},
            ),
          ),
        );
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('3. MessageInspectorPanel', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockSchemas = explorer_mocks.MockSchemaController();
        getIt.registerSingleton<SchemaController>(mockSchemas);

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            theme,
            MessageInspectorPanel(
              message: testMessage,
              onClose: () {},
              dockPosition: InspectorDockPosition.bottom,
              onToggleDockPosition: () {},
              onJumpToOriginalMessage: (topic, partition, offset) {},
            ),
          ),
        );
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('4. ConsumerLagView with loaded groups', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockClusters = explorer_mocks.MockClusterListController();
        final mockActive = explorer_mocks.MockActiveConnectionController();
        final mockTopics = explorer_mocks.MockTopicController();

        final registry = explorer_mocks.MockTopicViewControllerRegistry();

        when(mockTopics.viewControllers).thenReturn(registry);
        when(mockTopics.topicListenable).thenReturn(mockTopics);
        final mockSettings = settings_mocks.MockSettingsService();
        final fakeMetadata = _FakeKafkaMetadataService()
          ..lags = const [
            ConsumerGroupLag(
              groupId: 'billing-cg',
              state: 'Stable',
              protocolType: 'consumer',
              partitionLags: [],
              membersCount: 1,
              topicsCount: 1,
              members: [],
              unassignedPartitions: [],
              ownershipKnown: true,
            ),
          ];

        when(mockClusters.isLoading).thenReturn(false);
        when(mockClusters.clusters).thenReturn([testProfile]);
        when(mockSettings.lagWarnThreshold()).thenAnswer((_) async => 100);
        when(mockActive.activeProfile).thenReturn(testProfile);
        when(mockActive.isConnecting).thenReturn(false);
        when(mockActive.error).thenReturn(null);
        when(mockTopics.hasCachedTopics(testProfile)).thenReturn(true);
        when(mockTopics.isLoading(testProfile)).thenReturn(false);
        when(mockTopics.getTopics(testProfile)).thenReturn([testTopic]);

        getIt.registerSingleton<ClusterListController>(mockClusters);
        getIt.registerSingleton<ActiveConnectionController>(mockActive);
        getIt.registerSingleton<TopicController>(mockTopics);
        getIt.registerSingleton<SettingsService>(mockSettings);
        getIt.registerSingleton<KafkaMetadataService>(fakeMetadata);

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_host(theme, const ConsumerLagView()));
        await tester.pumpAndSettle();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('5. ClusterConfigDialog', (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            theme,
            const SingleChildScrollView(
              child: ClusterConfigDialog(existingNames: ['other']),
            ),
          ),
        );
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('6. SettingsView', (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockClusters = settings_mocks.MockClusterListController();
        final mockActive = settings_mocks.MockActiveConnectionController();
        final mockSettings = settings_mocks.MockSettingsService();

        when(mockClusters.isLoading).thenReturn(false);
        when(mockClusters.clusters).thenReturn([testProfile]);
        when(mockActive.activeProfile).thenReturn(testProfile);

        getIt.registerSingleton<ClusterListController>(mockClusters);
        getIt.registerSingleton<ActiveConnectionController>(mockActive);
        getIt.registerSingleton<SettingsService>(mockSettings);

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(_host(theme, const SettingsView()));
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('7. ScriptEditor', (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final mockClusters = explorer_mocks.MockClusterListController();
        final mockTopics = explorer_mocks.MockTopicController();

        final registry = explorer_mocks.MockTopicViewControllerRegistry();

        when(mockTopics.viewControllers).thenReturn(registry);
        when(mockTopics.topicListenable).thenReturn(mockTopics);
        when(mockClusters.clusters).thenReturn([testProfile]);
        when(mockTopics.getTopics(testProfile)).thenReturn([testTopic]);

        getIt.registerSingleton<ClusterListController>(mockClusters);
        getIt.registerSingleton<TopicController>(mockTopics);

        final script = Script(
          id: 's1',
          name: 'Trace Order',
          variables: [const ScriptVariable(name: 'orderId')],
          steps: [
            const ScriptStep(
              id: 'st1',
              name: 'Check Orders',
              clusterName: 'prod-cluster',
              topicNames: ['orders.events'],
            ),
          ],
        );

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(theme, ScriptEditor(script: script, onSave: (_) {})),
        );
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('8. TopicSearchBar', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final quickFilter = TextEditingController();
        final field = TextEditingController();
        final maxResults = TextEditingController(text: '200');
        final partition = TextEditingController();
        final startOffset = TextEditingController();
        final startTimestamp = TextEditingController();
        final endOffset = TextEditingController();
        final endTimestamp = TextEditingController();
        addTearDown(() {
          quickFilter.dispose();
          field.dispose();
          maxResults.dispose();
          partition.dispose();
          startOffset.dispose();
          startTimestamp.dispose();
          endOffset.dispose();
          endTimestamp.dispose();
        });

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            theme,
            TopicSearchBar(
              scanMode: TopicScanMode.latestN,
              onScanModeChanged: (_) {},
              quickFilterController: quickFilter,
              fieldController: field,
              filterType: FilterType.contains,
              onFilterTypeChanged: (_) {},
              searchScope: SearchScope.both,
              onSearchScopeChanged: (_) {},
              limitResults: true,
              onLimitResultsChanged: (_) {},
              maxResultsController: maxResults,
              partitionController: partition,
              fastTraceEnabled: false,
              onFastTraceEnabledChanged: (_) {},
              partitionCount: 3,
              startStrategy: MultiSearchStartStrategy.latest,
              onStartStrategyChanged: (_) {},
              startOffsetController: startOffset,
              startTimestampController: startTimestamp,
              endStrategy: MultiSearchEndStrategy.latest,
              onEndStrategyChanged: (_) {},
              endOffsetController: endOffset,
              endTimestampController: endTimestamp,
              onStart: () {},
            ),
          ),
        );
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });

      testWidgets('9. CommandPaletteDialog', (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final snapshot = PaletteSnapshot(
          l10n: AppLocalizationsEn(),
          clusters: const [testProfile],
          activeProfile: testProfile,
          topics: const [testTopic],
          openTopicNames: const {},
          consumerGroupIds: null,
          scripts: const [],
          onSelectDestination: (_) {},
          onOpenCluster: (_) async {},
          onOpenTopic: (_) {},
          onOpenConsumerGroup: (_) {},
          onOpenScript: (_) {},
        );

        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          _host(
            theme,
            Builder(
              builder: (ctx) => CommandPaletteDialog(
                rootContext: ctx,
                snapshotOverride: snapshot,
              ),
            ),
          ),
        );
        await tester.pump();

        await _verifyGuidelines(tester);
        semantics.dispose();
      });
    });
  }
}
