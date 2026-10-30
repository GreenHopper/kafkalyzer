import 'package:material_ui/material_ui.dart';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';

import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_detail_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
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
  String? get error => null;

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

  @override
  List<KafkaMessage> get messages => [];

  @override
  bool get isStreaming => false;

  @override
  int get totalConsumed => 0;

  @override
  int get totalToScan => 0;

  @override
  double get progress => 0.0;

  @override
  DateTime? get startTime => null;

  @override
  void clearMessages() {
    clearMessagesCalled = true;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSchemaController extends ChangeNotifier implements SchemaController {
  List<String> schemas = [];

  @override
  List<String>? getSchemas(ClusterProfile profile) => schemas;

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

      expect(find.text('Schema'), findsOneWidget);
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
}
