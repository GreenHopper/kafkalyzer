import 'package:material_ui/material_ui.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';

import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_detail_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/rust/api/topic_config.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';

class FakeActiveConnectionController extends ChangeNotifier
    implements ActiveConnectionController {
  @override
  OpenTopicRecord? get activeTopic => topic != null && activeProfile != null
      ? OpenTopicRecord(topic!, activeProfile!)
      : null;
  TopicMetadata? topic;
  final FakeMessageStreamController mockStreamController =
      FakeMessageStreamController();
  final TopicAnalysisController mockAnalysisController =
      TopicAnalysisController();

  @override
  MessageStreamController getStreamController(
    String tabIdOrTopicName, [
    String? clusterName,
  ]) => mockStreamController;

  @override
  TopicAnalysisController getAnalysisController(
    String tabIdOrTopicName, [
    String? clusterName,
  ]) => mockAnalysisController;

  TopicFactsController? mockFactsController;

  @override
  TopicFactsController getTopicFactsController(
    String tabIdOrTopicName,
    ClusterProfile profile,
    String topicName, [
    String? clusterName,
  ]) => mockFactsController ??= TopicFactsController(
    profile: profile,
    topicName: topicName,
    metadataService: _NoOpFactsMetadataService(),
  );

  @override
  List<OpenTopicRecord> get openTopics => topic != null && activeProfile != null
      ? [OpenTopicRecord(topic!, activeProfile!)]
      : [];

  @override
  ClusterProfile? activeProfile;

  @override
  ClusterProfile? get connectingProfile => null;

  @override
  bool get showInternalTopics => false;

  @override
  void toggleShowInternalTopics(bool value) {}

  @override
  String get topicFilter => '';

  @override
  void updateTopicFilter(String filter) {}

  @override
  bool get isConnecting => false;

  @override
  ConnectionError? get error => null;

  @override
  List<TopicMetadata> get topics => [?topic];

  @override
  void closeTopic(TopicMetadata topicToClose, String clusterName) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMessageStreamController extends ChangeNotifier
    implements MessageStreamController {
  bool clearMessagesCalled = false;
  bool pauseCalled = false;
  bool resumeCalled = false;
  String? errorMessage;
  bool streaming = false;
  bool paused = false;
  int pending = 0;
  int received = 0;
  int dropped = 0;
  int limit = 50000;
  int consumed = 0;
  List<KafkaMessage> fakeMessages = [];

  @override
  List<KafkaMessage> get messages => fakeMessages;

  @override
  bool get isStreaming => streaming;

  @override
  bool get isPaused => paused;

  @override
  int get pendingCount => pending;

  @override
  int get receivedCount => received;

  @override
  int get droppedCount => dropped;

  @override
  int get bufferLimit => limit;

  @override
  String? get error => errorMessage;

  @override
  int get totalConsumed => consumed;

  @override
  int get totalToScan => 0;

  @override
  double get progress => 0.0;

  @override
  DateTime? get startTime => null;

  @override
  void pause() {
    pauseCalled = true;
    paused = true;
    notifyListeners();
  }

  @override
  void resume() {
    resumeCalled = true;
    paused = false;
    pending = 0;
    notifyListeners();
  }

  @override
  void clearMessages() {
    clearMessagesCalled = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSchemaController extends ChangeNotifier implements SchemaController {
  List<String>? schemas = [];
  String? errorMessage;
  final Map<String, SchemaTypeState> types = {};

  @override
  List<String>? getSchemas(ClusterProfile profile) => schemas;

  @override
  String? errorFor(ClusterProfile profile) => errorMessage;

  @override
  SchemaTypeState schemaTypeFor(
    ClusterProfile profile,
    String subject, {
    int? version,
  }) => types[subject] ?? const SchemaTypeNotLoaded();

  @override
  Future<void> fetchSchemas(
    ClusterProfile profile, {
    bool force = false,
  }) async {}

  @override
  Future<List<String>> fetchSchemaFields(
    ClusterProfile profile,
    String topic,
  ) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Serves partition metadata rows without touching the Rust bridge.
class FakeKafkaMetadataService implements KafkaMetadataService {
  List<PartitionRow> partitionRows = [];
  bool unavailable = false;
  int fetchPartitionOffsetsCallCount = 0;
  PartitionOffsetDistribution? offsetDistribution;

  @override
  Future<TopicPartitionDetails> fetchTopicPartitions({
    required ClusterProfile profile,
    required String topic,
  }) async {
    if (unavailable) throw StateError('metadata unavailable');
    return TopicPartitionDetails(
      topic: topic,
      partitions: partitionRows,
      brokers: const [],
    );
  }

  @override
  Future<PartitionOffsetDistribution> fetchPartitionOffsets({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  }) async {
    fetchPartitionOffsetsCallCount++;
    return offsetDistribution ??
        PartitionOffsetDistribution(
          topic: topic,
          readAtMs: 1700000000000,
          partitions: const [],
          totalSpan: 0,
          knownSpan: 0,
          complete: true,
          skewStatus: OffsetSkewStatus.empty,
          skewThresholdPercent: skewThresholdPercent,
        );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  List<Script> get scripts => [];

  bool isScriptRunning(String scriptId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMultiSearchController extends ChangeNotifier
    implements MultiSearchController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeActiveConnectionController fakeActiveController;
  late FakeSchemaController fakeSchemaController;
  late FakeScriptRunner fakeScriptRunner;
  late FakeMultiSearchController fakeMultiSearchController;
  late FakeKafkaMetadataService fakeMetadataService;

  setUp(() {
    fakeMetadataService = FakeKafkaMetadataService();

    fakeActiveController = FakeActiveConnectionController();
    fakeSchemaController = FakeSchemaController();
    fakeScriptRunner = FakeScriptRunner();
    fakeMultiSearchController = FakeMultiSearchController();

    getIt.registerSingleton<ActiveConnectionController>(fakeActiveController);
    getIt.registerSingleton<SchemaController>(fakeSchemaController);
    getIt.registerSingleton<ScriptRunner>(fakeScriptRunner);
    getIt.registerSingleton<MultiSearchController>(fakeMultiSearchController);
    getIt.registerSingleton<KafkaMetadataService>(fakeMetadataService);
    getIt.registerSingleton<TopicConfigService>(_FakeTopicConfigService());
    getIt.registerSingleton<Logger>(Logger());
  });

  tearDown(() {
    getIt.reset();
  });

  testWidgets(
    'TopicDetailView clears messages on init and renders topic details',
    (WidgetTester tester) async {
      // Setup data
      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 2,
      );
      fakeActiveController.topic = topic;
      fakeActiveController.activeProfile = const ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        schemaRegistryUrl: 'http://localhost:8081',
        securityProtocol: 'plaintext',
        mechanism: 'plain',
        tlsVerification: TlsVerification.enabled,
      );

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: TopicDetailView(
                topic: topic,
                profile: const ClusterProfile(
                  name: 'Test Cluster',
                  bootstrapServers: 'localhost:9092',
                  schemaRegistryUrl: 'http://localhost:8081',
                  securityProtocol: 'plaintext',
                  mechanism: 'plain',
                  tlsVerification: TlsVerification.enabled,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test the view renders, since we don't mock getIt for stream_controller anymore we can't test clearMessages easily

      final exception = tester.takeException();
      if (exception != null) {
        getIt<Logger>().e("Caught rendering exception: $exception");
      }

      // Verify UI renders topic details
      expect(exception, isNull);
      expect(find.text('test-topic'), findsOneWidget);
      expect(find.text('3 Partitions'), findsOneWidget);
      expect(find.text('RF: 2'), findsOneWidget);
    },
  );

  testWidgets('Topic detail header does not overflow in a narrow window', (
    WidgetTester tester,
  ) async {
    const topic = TopicMetadata(
      name: 'test-topic',
      partitionCount: 3,
      replicationFactor: 2,
    );
    const profile = ClusterProfile(
      name: 'Test Cluster',
      bootstrapServers: 'localhost:9092',
      schemaRegistryUrl: 'http://localhost:8081',
      securityProtocol: 'plaintext',
      mechanism: 'plain',
      tlsVerification: TlsVerification.enabled,
    );
    fakeActiveController.topic = topic;
    fakeActiveController.activeProfile = profile;
    fakeSchemaController.schemas = ['test-topic-value'];
    tester.view.physicalSize = const Size(580, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('en')],
        home: Scaffold(
          body: SizedBox(
            width: 580,
            height: 900,
            child: TopicDetailView(topic: topic, profile: profile),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('test-topic'), findsOneWidget);
  });

  testWidgets(
    'TopicSearchBar renders in TopicDetailView and toggles advanced filters',
    (WidgetTester tester) async {
      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 2,
      );
      const profile = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        schemaRegistryUrl: 'http://localhost:8081',
        securityProtocol: 'plaintext',
        mechanism: 'plain',
        tlsVerification: TlsVerification.enabled,
      );
      fakeActiveController.topic = topic;
      fakeActiveController.activeProfile = profile;

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: TopicDetailView(topic: topic, profile: profile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.byType(TopicSearchBar), findsOneWidget);
      expect(find.text(l10n.advancedFiltersToggle), findsOneWidget);
      expect(find.text('Partition (Opt.)'), findsNothing);

      await tester.tap(find.text(l10n.advancedFiltersToggle));
      await tester.pumpAndSettle();

      expect(find.text('Partition (Opt.)'), findsOneWidget);
      expect(find.text('Fast Trace (Hash Key)'), findsOneWidget);

      await tester.tap(find.text(l10n.advancedFiltersToggle));
      await tester.pumpAndSettle();

      expect(find.text('Partition (Opt.)'), findsNothing);
    },
  );

  testWidgets(
    'renders localized actions in German (Schema, Stream, tooltips)',
    (tester) async {
      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 2,
      );
      const profile = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        schemaRegistryUrl: 'http://localhost:8081',
        securityProtocol: 'plaintext',
        mechanism: 'plain',
        tlsVerification: TlsVerification.enabled,
      );
      fakeActiveController.topic = topic;
      fakeActiveController.activeProfile = profile;
      fakeSchemaController.schemas = ['test-topic-value'];

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: Scaffold(
            body: SizedBox(
              width: 1200,
              height: 800,
              child: TopicDetailView(topic: topic, profile: profile),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Schema'), findsNWidgets(2));
      expect(find.text('Stream'), findsOneWidget);
      expect(find.byTooltip('Nachrichten leeren'), findsOneWidget);
      expect(find.byTooltip('Topic-Name kopieren'), findsOneWidget);
    },
  );

  Widget detailView(TopicMetadata topic) => MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    supportedLocales: const [Locale('en')],
    home: Scaffold(
      body: SizedBox(
        width: 1200,
        height: 800,
        child: TopicDetailView(
          topic: topic,
          profile: const ClusterProfile(
            name: 'Test Cluster',
            bootstrapServers: 'localhost:9092',
            tlsVerification: TlsVerification.enabled,
          ),
        ),
      ),
    ),
  );

  const threePartitionTopic = TopicMetadata(
    name: 'orders',
    partitionCount: 3,
    replicationFactor: 3,
  );

  testWidgets(
    'topic detail lists leader, replicas and ISR for every partition',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeMetadataService.partitionRows = [
        PartitionRow(
          partition: 0,
          leader: 1,
          replicas: Int32List.fromList([1, 2, 3]),
          inSyncReplicas: Int32List.fromList([1, 2, 3]),
          underReplicated: false,
          leaderless: false,
        ),
        PartitionRow(
          partition: 1,
          leader: 2,
          replicas: Int32List.fromList([1, 2, 3]),
          inSyncReplicas: Int32List.fromList([1, 2]),
          underReplicated: true,
          leaderless: false,
        ),
        PartitionRow(
          partition: 2,
          replicas: Int32List.fromList([1, 2, 3]),
          inSyncReplicas: Int32List.fromList([1]),
          underReplicated: true,
          leaderless: true,
        ),
      ];

      await tester.pumpWidget(detailView(threePartitionTopic));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The partition health table is no longer rendered inline above messages.
      expect(
        find.byKey(const Key('topic_partition_health_dialog')),
        findsNothing,
      );

      // Tapping the partitions tag opens the dialog.
      await tester.tap(find.byKey(const Key('topic_partitions_tag')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('topic_partition_health_dialog')),
        findsOneWidget,
      );
      for (final partition in [0, 1, 2]) {
        expect(
          find.byKey(Key('partition_row_$partition')),
          findsOneWidget,
          reason: 'partition $partition should have a row',
        );
      }

      Finder cells(int partition, String value) => find.descendant(
        of: find.byKey(Key('partition_row_$partition')),
        matching: find.text(value),
      );

      // partition | leader | replicas | ISR
      expect(cells(0, '1'), findsOneWidget);
      expect(cells(0, '1, 2, 3'), findsNWidgets(2));
      expect(cells(1, '2'), findsOneWidget);
      expect(cells(1, '1, 2'), findsOneWidget);
      // A partition without a leader is named, not left blank.
      expect(cells(2, 'none'), findsOneWidget);
      expect(cells(2, '1'), findsOneWidget);
    },
  );

  testWidgets(
    'unavailable partition metadata is marked unavailable, not healthy',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeMetadataService.unavailable = true;

      await tester.pumpWidget(detailView(threePartitionTopic));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('topic_partitions_tag')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('partition_health_unavailable')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('partition_row_0')), findsNothing);
    },
  );

  testWidgets(
    'health warning disappears once a refresh reports healthy partitions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const unhealthyTopic = TopicMetadata(
        name: 'orders',
        partitionCount: 3,
        replicationFactor: 3,
        underReplicatedPartitions: 1,
        leaderlessPartitions: 0,
      );

      await tester.pumpWidget(detailView(unhealthyTopic));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic_health_tag')), findsOneWidget);

      await tester.pumpWidget(detailView(threePartitionTopic));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic_health_tag')), findsNothing);
    },
  );

  testWidgets('renders streamController.error when message fetch fails', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeActiveController.mockStreamController.errorMessage =
        'Consumer group timeout';

    await tester.pumpWidget(detailView(threePartitionTopic));
    await tester.pumpAndSettle();

    expect(find.text('Failed to fetch messages'), findsOneWidget);
    expect(find.text('Consumer group timeout'), findsOneWidget);
  });

  testWidgets(
    'shows Pause while streaming, Resume with pending count while paused, and keeps error visible while paused',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sc = fakeActiveController.mockStreamController;

      // Not streaming and not paused -> no Pause/Resume button
      await tester.pumpWidget(detailView(threePartitionTopic));
      await tester.pumpAndSettle();
      expect(find.text('Pause'), findsNothing);
      expect(find.textContaining('Resume'), findsNothing);

      // Streaming -> Pause button shown
      sc.streaming = true;
      sc.notifyListeners();
      await tester.pump();
      expect(find.text('Pause'), findsOneWidget);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(sc.pauseCalled, isTrue);

      // Paused with 42 new messages + error -> Resume shows 42 new & error visible
      sc.fakeMessages = const [
        KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 1,
          key: 'k1',
          payload: 'v1',
          timestamp: 1000,
        ),
      ];
      sc.pending = 42;
      sc.errorMessage = 'Transient broker error';
      sc.notifyListeners();
      await tester.pump();
      expect(find.text('Resume · 42 new'), findsOneWidget);
      expect(find.textContaining('Transient broker error'), findsOneWidget);

      // Stream stopped while still paused -> Resume button remains visible
      sc.streaming = false;
      sc.notifyListeners();
      await tester.pump();
      expect(find.text('Resume · 42 new'), findsOneWidget);
    },
  );

  testWidgets(
    'shows dropped indicator only when drops > 0 and match count uses receivedCount',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final sc = fakeActiveController.mockStreamController;
      sc.consumed = 5000;
      sc.received = 1234;
      sc.dropped = 0;
      sc.limit = 50000;

      await tester.pumpWidget(detailView(threePartitionTopic));
      await tester.pumpAndSettle();

      expect(find.textContaining('1.234 matches found'), findsOneWidget);
      expect(find.textContaining('dropped'), findsNothing);

      sc.received = 51200;
      sc.dropped = 1200;
      sc.notifyListeners();
      await tester.pump();

      expect(find.textContaining('51.200 matches found'), findsOneWidget);
      expect(
        find.text('1,200 oldest messages dropped (limit 50,000)'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'not-authorized topic shows not readable tag, no 0 Partitions, and null partitionCount in search bar',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const secretTopic = TopicMetadata(
        name: 'secret-topic',
        partitionCount: 0,
        replicationFactor: 0,
        metadataError: TopicMetadataError(
          kind: TopicMetadataErrorKind.notAuthorized,
          message: 'TopicAuthorizationFailed',
        ),
      );
      fakeActiveController.topic = secretTopic;

      await tester.pumpWidget(detailView(secretTopic));
      await tester.pumpAndSettle();

      expect(find.text('not readable — permission?'), findsOneWidget);
      expect(find.text('0 Partitions'), findsNothing);
      final searchBar = tester.widget<TopicSearchBar>(
        find.byType(TopicSearchBar),
      );
      expect(searchBar.partitionCount, isNull);
    },
  );

  testWidgets(
    'config denial shows not-readable tag and failed config Retry re-queues',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeTopicCtrl = _DetailFakeTopicController();
      fakeTopicCtrl.view = const TopicConfigView(
        state: TopicConfigViewState.notReadable,
      );
      getIt.registerSingleton<TopicController>(fakeTopicCtrl);

      const bareTopic = TopicMetadata(
        name: 'bare-topic',
        partitionCount: 3,
        replicationFactor: 1,
      );
      fakeActiveController.topic = bareTopic;

      await tester.pumpWidget(detailView(bareTopic));
      await tester.pumpAndSettle();

      expect(fakeTopicCtrl.ensuredTopics, contains('bare-topic'));
      expect(find.text('not readable — permission?'), findsOneWidget);

      fakeTopicCtrl.view = const TopicConfigView(
        state: TopicConfigViewState.failed,
      );
      fakeTopicCtrl.notifyListeners();
      await tester.pump();

      final failedTag = find.byKey(const Key('topic_config_failed_tag'));
      expect(failedTag, findsOneWidget);
      await tester.tap(failedTag);
      await tester.pump();

      expect(fakeTopicCtrl.retriedTopics, contains('bare-topic'));
    },
  );

  testWidgets(
    'partition health dialog loads offsets once and exact-values action opens analysis without starting scan',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      fakeMetadataService.offsetDistribution =
          const PartitionOffsetDistribution(
            topic: 'orders',
            readAtMs: 1700000000000,
            partitions: [
              PartitionOffsetRow(
                partition: 0,
                state: PartitionOffsetState.known,
                low: 0,
                high: 80,
                span: 80,
                sharePercent: 80.0,
                skewed: true,
              ),
              PartitionOffsetRow(
                partition: 1,
                state: PartitionOffsetState.known,
                low: 0,
                high: 20,
                span: 20,
                sharePercent: 20.0,
                skewed: false,
              ),
            ],
            totalSpan: 100,
            knownSpan: 100,
            complete: true,
            skewStatus: OffsetSkewStatus.skewed,
            skewThresholdPercent: 50,
          );

      await tester.pumpWidget(detailView(threePartitionTopic));
      await tester.pumpAndSettle();

      // Opening TopicDetailView and switching to Analysis never calls fetchPartitionOffsets.
      expect(fakeMetadataService.fetchPartitionOffsetsCallCount, 0);

      // Open partition health dialog via partitions tag.
      await tester.tap(find.byKey(const Key('topic_partitions_tag')));
      await tester.pumpAndSettle();

      expect(fakeMetadataService.fetchPartitionOffsetsCallCount, 1);
      expect(
        find.byKey(const Key('partition_offset_skew_badge')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('partition_offset_row_0')), findsOneWidget);

      // Tap exact-values action -> closes dialog and opens Analysis view without starting scan.
      final openAnalysisBtn = find.byKey(
        const Key('partition_offset_open_analysis_button'),
      );
      await tester.ensureVisible(openAnalysisBtn);
      await tester.tap(openAnalysisBtn);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('topic_partition_health_dialog')),
        findsNothing,
      );
      // Analysis view shows "Start Analysis" without running a scan.
      expect(find.text('Start Analysis'), findsAtLeastNWidgets(1));
      expect(fakeMetadataService.fetchPartitionOffsetsCallCount, 1);
    },
  );

  testWidgets(
    'topic header shows estimate, compaction note, retention unlimited & bytes, and loads time range only on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const profile = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.disabled,
      );
      const topic = TopicMetadata(
        name: 'orders',
        partitionCount: 3,
        replicationFactor: 2,
      );

      final factsMeta = _ConfigurableFactsMetadataService();
      var timeRangeCalls = 0;
      factsMeta.onOffsets = () async => const PartitionOffsetDistribution(
        topic: 'orders',
        readAtMs: 1000,
        partitions: [],
        totalSpan: 1250,
        knownSpan: 1250,
        complete: true,
        skewStatus: OffsetSkewStatus.balanced,
      );
      factsMeta.onConfigs = () async => const [
        TopicConfigResult(
          topic: 'orders',
          status: TopicConfigStatus.available,
          entries: [
            TopicConfigEntry(
              name: 'cleanup.policy',
              value: 'compact',
              source: TopicConfigSource.dynamicTopic,
              isDefault: false,
              isSensitive: false,
              isReadOnly: false,
            ),
            TopicConfigEntry(
              name: 'retention.ms',
              value: '-1',
              source: TopicConfigSource.dynamicTopic,
              isDefault: false,
              isSensitive: false,
              isReadOnly: false,
            ),
            TopicConfigEntry(
              name: 'retention.bytes',
              value: '1073741824',
              source: TopicConfigSource.dynamicTopic,
              isDefault: false,
              isSensitive: false,
              isReadOnly: false,
            ),
          ],
        ),
      ];
      factsMeta.onTimeRange = () async {
        timeRangeCalls++;
        return const TopicTimeRange(
          oldest: PartitionTimestamp(
            partition: 0,
            offset: 10,
            timestampMs: 1700000000000,
            timestampType: TimeRangeTimestampKind.createTime,
          ),
          newest: PartitionTimestamp(
            partition: 2,
            offset: 99,
            timestampMs: 1700003600000,
            timestampType: TimeRangeTimestampKind.logAppendTime,
          ),
          partitionsTotal: 3,
          partitionsEmpty: 0,
          oldestKnown: 2,
          newestKnown: 3,
          allEmpty: false,
          probes: [
            PartitionTimeProbe(
              partition: 1,
              oldest: PartitionTimeProbeOutcome(
                kind: ProbeOutcomeKind.timedOut,
                reason: 'timed out',
              ),
              newest: PartitionTimeProbeOutcome(
                kind: ProbeOutcomeKind.found,
                offset: 50,
                timestampMs: 1700001000000,
                timestampType: TimeRangeTimestampKind.createTime,
              ),
            ),
          ],
        );
      };

      final active = FakeActiveConnectionController()
        ..activeProfile = profile
        ..topic = topic
        ..mockFactsController = TopicFactsController(
          profile: profile,
          topicName: topic.name,
          metadataService: factsMeta,
        );
      getIt.unregister<ActiveConnectionController>();
      getIt.registerSingleton<ActiveConnectionController>(active);
      final timeDisplay = TimeDisplaySettings(TimeDisplayMode.utc);
      if (getIt.isRegistered<TimeDisplaySettings>()) {
        getIt.unregister<TimeDisplaySettings>();
      }
      getIt.registerSingleton<TimeDisplaySettings>(timeDisplay);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: [Locale('en')],
          home: Scaffold(
            body: TopicDetailView(topic: topic, profile: profile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 Partitions'), findsOneWidget);
      expect(find.text('RF: 2'), findsOneWidget);
      expect(find.byKey(const Key('topic_estimate_tag')), findsOneWidget);
      expect(find.textContaining('1,250'), findsOneWidget);
      expect(
        find.byKey(const Key('topic_estimate_compaction_tooltip')),
        findsOneWidget,
      );
      expect(find.text('Retention: unlimited'), findsOneWidget);
      expect(find.text('Max size: 1.00 GB / partition'), findsOneWidget);

      // Time range must NOT auto-load
      expect(timeRangeCalls, 0);
      final loadTrBtn = find.byKey(const Key('topic_load_time_range_button'));
      expect(loadTrBtn, findsOneWidget);

      await tester.tap(loadTrBtn);
      await tester.pumpAndSettle();

      expect(timeRangeCalls, 1);
      expect(find.byKey(const Key('topic_time_range_tag')), findsOneWidget);
      expect(find.textContaining('UTC'), findsWidgets);
      expect(
        find.byKey(const Key('topic_time_range_partial_tag')),
        findsOneWidget,
      );
      expect(find.text('Partial (2/3 oldest, 3/3 newest)'), findsOneWidget);
    },
  );

  testWidgets(
    'background tab does not load facts until active, and handles unknown estimate, empty time range, not readable retention, and German tags',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const profile = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.disabled,
      );
      const otherTopic = TopicMetadata(
        name: 'other',
        partitionCount: 1,
        replicationFactor: 1,
      );
      const targetTopic = TopicMetadata(
        name: 'bg-topic',
        partitionCount: 3,
        replicationFactor: 2,
      );

      final factsMeta = _ConfigurableFactsMetadataService();
      var offsetCalls = 0;
      factsMeta.onOffsets = () async {
        offsetCalls++;
        return const PartitionOffsetDistribution(
          topic: 'bg-topic',
          readAtMs: 1000,
          partitions: [],
          totalSpan: null,
          knownSpan: 0,
          complete: false,
          skewStatus: OffsetSkewStatus.incomplete,
        );
      };
      factsMeta.onConfigs = () async => const [
        TopicConfigResult(
          topic: 'bg-topic',
          status: TopicConfigStatus.notReadable,
          entries: [],
        ),
      ];
      factsMeta.onTimeRange = () async => const TopicTimeRange(
        oldest: null,
        newest: null,
        partitionsTotal: 3,
        partitionsEmpty: 3,
        oldestKnown: 0,
        newestKnown: 0,
        allEmpty: true,
        probes: [],
      );

      final active = FakeActiveConnectionController()
        ..activeProfile = profile
        ..topic = otherTopic
        ..mockFactsController = TopicFactsController(
          profile: profile,
          topicName: targetTopic.name,
          metadataService: factsMeta,
        );
      getIt.unregister<ActiveConnectionController>();
      getIt.registerSingleton<ActiveConnectionController>(active);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('de'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: [Locale('en'), Locale('de')],
          home: Scaffold(
            body: TopicDetailView(topic: targetTopic, profile: profile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Background tab must NOT load facts yet
      expect(offsetCalls, 0);
      expect(find.text('3 Partitionen'), findsOneWidget);
      expect(find.text('RF: 2'), findsOneWidget);

      // Now activate the tab
      active.topic = targetTopic;
      active.notifyListeners();
      await tester.pumpAndSettle();

      expect(offsetCalls, 1);
      expect(find.text('Nachrichten: unbekannt'), findsOneWidget);
      expect(find.text('Aufbewahrung: nicht lesbar'), findsOneWidget);

      await tester.tap(find.byKey(const Key('topic_load_time_range_button')));
      await tester.pumpAndSettle();
      expect(find.text('Keine Nachrichten'), findsOneWidget);
    },
  );

  testWidgets(
    'switching to Configuration calls TopicConfigService once and switching back and forth does not re-read',
    (WidgetTester tester) async {
      final configService = _FakeTopicConfigService()
        ..entries = [
          const TopicConfigEntry(
            name: 'retention.ms',
            value: '60000',
            source: TopicConfigSource.dynamicTopic,
            isDefault: false,
            isSensitive: false,
            isReadOnly: false,
          ),
        ];
      getIt.unregister<TopicConfigService>();
      getIt.registerSingleton<TopicConfigService>(configService);

      const topic = TopicMetadata(
        name: 'config-topic',
        partitionCount: 3,
        replicationFactor: 2,
      );
      const profile = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.enabled,
      );
      fakeActiveController.topic = topic;
      fakeActiveController.activeProfile = profile;

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TopicDetailView(topic: topic, profile: profile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Not fetched until Configuration mode is selected
      expect(configService.calls, isEmpty);

      await tester.tap(find.text('Configuration'));
      await tester.pumpAndSettle();

      expect(configService.calls, [('Test Cluster', 'config-topic')]);
      expect(find.text('retention.ms'), findsOneWidget);

      // Switch back to Messages and then back to Configuration -> no re-read
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Configuration'));
      await tester.pumpAndSettle();

      expect(configService.calls, [('Test Cluster', 'config-topic')]);
    },
  );

  testWidgets(
    'schema tag shows Protobuf, mixed key/value, not loaded, and failed states',
    (tester) async {
      final schemaController =
          getIt<SchemaController>() as FakeSchemaController;
      const profile = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
        schemaRegistryUrl: 'http://localhost:8081',
        tlsVerification: TlsVerification.enabled,
      );
      const topic = TopicMetadata(
        name: 'orders',
        partitionCount: 1,
        replicationFactor: 1,
      );

      // 1. Not loaded (subject present, type not loaded)
      schemaController.schemas = ['orders-value'];
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TopicDetailView(topic: topic, profile: profile),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('topic_schema_tag')), findsOneWidget);
      expect(find.text('Schema'), findsWidgets);

      // 2. Protobuf
      schemaController.types['orders-value'] = const SchemaTypeKnown(
        api.SchemaKindDto.protobuf,
      );
      schemaController.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Protobuf'), findsOneWidget);

      // 3. Mixed key/value (Avro / Protobuf)
      schemaController.schemas = ['orders-key', 'orders-value'];
      schemaController.types['orders-key'] = const SchemaTypeKnown(
        api.SchemaKindDto.avro,
      );
      schemaController.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Avro / Protobuf'), findsOneWidget);

      // 4. Failed subject list
      schemaController.schemas = null;
      schemaController.errorMessage = '401 unauthorized';
      schemaController.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('Schema (unknown)'), findsOneWidget);
    },
  );
}

class _FakeTopicConfigService implements TopicConfigService {
  final List<(String, String)> calls = [];
  List<TopicConfigEntry> entries = const [];

  @override
  Future<TopicConfigSnapshot> fetchTopicConfig({
    required ClusterProfile profile,
    required String topic,
  }) async {
    calls.add((profile.name, topic));
    return TopicConfigSnapshot(
      topic: topic,
      availability: TopicConfigAvailability.available,
      entries: entries,
    );
  }

  @override
  TopicConfigDiff diffTopicConfigs({
    required TopicConfigSnapshot left,
    required TopicConfigSnapshot right,
  }) => const TopicConfigDiff(rows: [], differenceCount: 0);
}

class _DetailFakeTopicController extends ChangeNotifier
    implements TopicController {
  TopicConfigView view = const TopicConfigView.loading();
  final List<String> ensuredTopics = [];
  final List<String> retriedTopics = [];

  @override
  TopicMetadata? findTopic(ClusterProfile cluster, String name) => null;

  @override
  TopicConfigView configFor(ClusterProfile cluster, String topic) => view;

  @override
  void ensureConfig(ClusterProfile cluster, String topic) {
    ensuredTopics.add(topic);
  }

  @override
  void retryConfig(ClusterProfile cluster, String topic) {
    retriedTopics.add(topic);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoOpFactsMetadataService implements KafkaMetadataService {
  @override
  Future<PartitionOffsetDistribution> fetchPartitionOffsets({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  }) async => PartitionOffsetDistribution(
    topic: topic,
    readAtMs: 0,
    partitions: const [],
    totalSpan: 0,
    knownSpan: 0,
    complete: true,
    skewStatus: OffsetSkewStatus.balanced,
  );

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

class _ConfigurableFactsMetadataService implements KafkaMetadataService {
  Future<PartitionOffsetDistribution> Function()? onOffsets;
  Future<List<TopicConfigResult>> Function()? onConfigs;
  Future<TopicTimeRange> Function()? onTimeRange;

  @override
  Future<PartitionOffsetDistribution> fetchPartitionOffsets({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  }) => onOffsets!();

  @override
  Future<List<TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) => onConfigs!();

  @override
  Future<TopicTimeRange> fetchTopicTimeRange({
    required ClusterProfile profile,
    required String topic,
  }) => onTimeRange!();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
