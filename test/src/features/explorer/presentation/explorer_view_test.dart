import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/explorer_view.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

@GenerateMocks([
  ClusterListController,
  ActiveConnectionController,
  TopicController,
  SchemaController,
])
import 'explorer_view_test.mocks.dart';

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
  );

  setUp(() {
    mockClusterListController = MockClusterListController();
    mockActiveConnectionController = MockActiveConnectionController();
    // Use FixedMockTopicController to handle missing hasCachedTopics stub in generated mocks
    mockTopicController = FixedMockTopicController();
    mockSchemaController = MockSchemaController();

    final getIt = GetIt.instance;
    getIt.reset();
    getIt.registerLazySingleton<Logger>(() => MockLogger());
    getIt.registerSingleton<ClusterListController>(mockClusterListController);
    getIt.registerSingleton<ActiveConnectionController>(
      mockActiveConnectionController,
    );
    getIt.registerSingleton<TopicController>(mockTopicController);
    getIt.registerSingleton<SchemaController>(mockSchemaController);

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
    when(mockTopicController.isLoading(any)).thenReturn(false);
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
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
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
      expect(find.text('test-cluster'), findsOneWidget);
      expect(
        find.text('Select a cluster to view topics'),
        findsOneWidget,
      ); // Empty state
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
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      await tester.tap(find.text('test-cluster'));
      await tester.pump();

      verify(mockActiveConnectionController.connect(testProfile)).called(1);
      verify(mockSchemaController.fetchSchemas(testProfile)).called(1);
    });

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

    testWidgets('toggle internal topics', (tester) async {
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
      when(mockActiveConnectionController.error).thenReturn(null);
      when(mockActiveConnectionController.topicFilter).thenReturn('');
      when(mockActiveConnectionController.openTopics).thenReturn([]);
      when(mockActiveConnectionController.topics).thenReturn([]);
      when(mockTopicController.hasCachedTopics(testProfile)).thenReturn(true);
      when(mockTopicController.isLoading(testProfile)).thenReturn(false);
      when(mockTopicController.getTopics(testProfile)).thenReturn([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();

      final switches = find.byType(Switch);
      expect(switches, findsWidgets);
      await tester.tap(switches.first);
      await tester.pump();

      verify(
        mockActiveConnectionController.toggleShowInternalTopics(true),
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
  });
}

class FixedMockTopicController extends MockTopicController {
  @override
  bool hasCachedTopics(ClusterProfile? cluster) {
    return super.noSuchMethod(
          Invocation.method(#hasCachedTopics, [cluster]),
          returnValue: false,
          returnValueForMissingStub: false,
        )
        as bool;
  }
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
  int? get maxMessages => null;

  @override
  bool get sampleFromLatest => true;

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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
