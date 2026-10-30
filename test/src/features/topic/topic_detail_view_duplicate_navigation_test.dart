import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/topic_search_bar.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/features/topic/topic_detail_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';

class _RecordingStreamController extends ChangeNotifier
    implements MessageStreamController {
  bool startStreamingCalled = false;
  List<String>? lastFilterTerms;
  FilterType? lastFilterType;
  SearchScope? lastSearchScope;
  int? lastStartPartition;
  int? lastStartOffset;
  int? lastMaxResults;
  bool? lastStartFromTail;

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
  void clearMessages() {}

  @override
  Future<void> stopStreaming() async {}

  @override
  Future<void> startStreaming(
    ClusterProfile profile,
    String topic, {
    List<String>? filterTerms,
    String? filterField,
    required FilterType filterType,
    required SearchScope searchScope,
    bool fastTraceEnabled = false,
    int? startOffset,
    int? startTimestamp,
    int? startPartition,
    int? maxResults,
    int? endOffset,
    int? endTimestamp,
    bool runForever = true,
    bool startFromTail = false,
  }) async {
    startStreamingCalled = true;
    lastFilterTerms = filterTerms;
    lastFilterType = filterType;
    lastSearchScope = searchScope;
    lastStartPartition = startPartition;
    lastStartOffset = startOffset;
    lastMaxResults = maxResults;
    lastStartFromTail = startFromTail;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveConnectionController extends ChangeNotifier
    implements ActiveConnectionController {
  final _RecordingStreamController streamController =
      _RecordingStreamController();
  final TopicAnalysisController analysisController = TopicAnalysisController();
  TopicMetadata? topic;
  @override
  ClusterProfile? activeProfile;

  @override
  MessageStreamController getStreamController(
    String tabIdOrTopicName, [
    String? clusterName,
  ]) => streamController;

  @override
  TopicAnalysisController getAnalysisController(
    String tabIdOrTopicName, [
    String? clusterName,
  ]) => analysisController;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSchemaController extends ChangeNotifier implements SchemaController {
  @override
  List<String>? getSchemas(ClusterProfile profile) => [];

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

class _FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeKafkaMetadataService implements KafkaMetadataService {
  @override
  Future<TopicPartitionDetails> fetchTopicPartitions({
    required ClusterProfile profile,
    required String topic,
  }) async {
    return TopicPartitionDetails(
      topic: topic,
      partitions: const [],
      brokers: const [],
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMultiSearchController extends ChangeNotifier
    implements MultiSearchController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeActiveConnectionController fakeActiveController;
  late _FakeSchemaController fakeSchemaController;
  late _FakeScriptRunner fakeScriptRunner;

  const testProfile = ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
  );

  const testTopic = TopicMetadata(
    name: 'test-topic',
    partitionCount: 4,
    replicationFactor: 1,
  );

  setUp(() {
    getIt.reset();
    fakeActiveController = _FakeActiveConnectionController();
    fakeActiveController.topic = testTopic;
    fakeActiveController.activeProfile = testProfile;

    fakeSchemaController = _FakeSchemaController();
    fakeScriptRunner = _FakeScriptRunner();

    getIt.registerSingleton<ActiveConnectionController>(fakeActiveController);
    getIt.registerSingleton<SchemaController>(fakeSchemaController);
    getIt.registerSingleton<ScriptRunner>(fakeScriptRunner);
    getIt.registerSingleton<MultiSearchController>(
      _FakeMultiSearchController(),
    );
    getIt.registerSingleton<KafkaMetadataService>(_FakeKafkaMetadataService());
    getIt.registerSingleton<Logger>(Logger());
  });

  tearDown(() {
    getIt.reset();
  });

  Widget buildTestView() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TopicDetailView(topic: testTopic, profile: testProfile),
      ),
    );
  }

  testWidgets(
    'filters keyed duplicates across all partitions from earliest offset',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Switch to Analysis tab
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pumpAndSettle();

      // Trigger duplicate navigation callback directly on TopicAnalysisView
      final analysisViewFinder = find.byType(TopicAnalysisView);
      expect(analysisViewFinder, findsOneWidget);
      final topicAnalysisView = tester.widget<TopicAnalysisView>(
        analysisViewFinder,
      );

      const target = DuplicateNavigationTarget(
        key: 'cor-uuid-999',
        payloadPreview: '{"status":"COMPLETED"}',
        count: 12,
        samplePartition: 1,
        sampleOffset: 145155,
        scope: DuplicateDetectionScope.payloadOnly,
        filterOccurrences: true,
      );

      topicAnalysisView.onNavigateToTarget!(target);
      await tester.pumpAndSettle();

      // Verify that view switched back to Messages
      final searchBarFinder = find.byType(TopicSearchBar);
      expect(searchBarFinder, findsOneWidget);
      final searchBar = tester.widget<TopicSearchBar>(searchBarFinder);

      // Verify quick filter prefilled with key
      expect(searchBar.quickFilterController.text, equals('cor-uuid-999'));
      expect(searchBar.searchScope, equals(SearchScope.key));
      expect(searchBar.filterType, equals(FilterType.exact));

      // Verify partition is cleared to search across all topic partitions
      expect(searchBar.partitionController.text, isEmpty);

      // Verify scan mode set to offsetEarliest
      expect(searchBar.scanMode, equals(TopicScanMode.offsetEarliest));
      expect(
        searchBar.startStrategy,
        equals(MultiSearchStartStrategy.earliest),
      );
      expect(searchBar.startOffsetController.text, equals('0'));

      // Verify stream started with topic-wide earliest settings
      final streamCtrl = fakeActiveController.streamController;
      expect(streamCtrl.startStreamingCalled, isTrue);
      expect(streamCtrl.lastFilterTerms, equals(['cor-uuid-999']));
      expect(streamCtrl.lastSearchScope, equals(SearchScope.key));
      expect(streamCtrl.lastFilterType, equals(FilterType.exact));
      expect(streamCtrl.lastStartPartition, isNull);
      expect(streamCtrl.lastStartOffset, equals(0));
      expect(streamCtrl.lastStartFromTail, isFalse);
    },
  );

  testWidgets(
    'filters unkeyed duplicates using payload substring across all partitions',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      // Switch to Analysis tab
      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pumpAndSettle();

      final analysisViewFinder = find.byType(TopicAnalysisView);
      final topicAnalysisView = tester.widget<TopicAnalysisView>(
        analysisViewFinder,
      );

      const target = DuplicateNavigationTarget(
        key: null,
        payloadPreview: '{"event":"ORDER_CREATED","amount":150}',
        count: 8,
        samplePartition: 3,
        sampleOffset: 5000,
        scope: DuplicateDetectionScope.payloadOnly,
        filterOccurrences: true,
      );

      topicAnalysisView.onNavigateToTarget!(target);
      await tester.pumpAndSettle();

      final searchBarFinder = find.byType(TopicSearchBar);
      final searchBar = tester.widget<TopicSearchBar>(searchBarFinder);

      expect(
        searchBar.quickFilterController.text,
        equals('{"event":"ORDER_CREATED","amount":150}'),
      );
      expect(searchBar.searchScope, equals(SearchScope.value));
      expect(searchBar.filterType, equals(FilterType.contains));
      expect(searchBar.partitionController.text, isEmpty);
      expect(searchBar.scanMode, equals(TopicScanMode.offsetEarliest));

      final streamCtrl = fakeActiveController.streamController;
      expect(streamCtrl.startStreamingCalled, isTrue);
      expect(
        streamCtrl.lastFilterTerms,
        equals(['{"event":"ORDER_CREATED"', '"amount":150}']),
      );
      expect(streamCtrl.lastSearchScope, equals(SearchScope.value));
      expect(streamCtrl.lastFilterType, equals(FilterType.contains));
      expect(streamCtrl.lastStartPartition, isNull);
      expect(streamCtrl.lastStartOffset, equals(0));
    },
  );

  testWidgets(
    'jumps to exact sample coordinates when filterOccurrences is false',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestView());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.analytics_outlined));
      await tester.pumpAndSettle();

      final analysisViewFinder = find.byType(TopicAnalysisView);
      final topicAnalysisView = tester.widget<TopicAnalysisView>(
        analysisViewFinder,
      );

      const target = DuplicateNavigationTarget(
        key: 'cor-uuid-999',
        payloadPreview: '{"status":"COMPLETED"}',
        count: 12,
        samplePartition: 2,
        sampleOffset: 8888,
        scope: DuplicateDetectionScope.payloadOnly,
        filterOccurrences: false,
      );

      topicAnalysisView.onNavigateToTarget!(target);
      await tester.pumpAndSettle();

      final searchBarFinder = find.byType(TopicSearchBar);
      final searchBar = tester.widget<TopicSearchBar>(searchBarFinder);

      expect(searchBar.partitionController.text, equals('2'));
      expect(searchBar.startOffsetController.text, equals('8888'));
      expect(searchBar.scanMode, equals(TopicScanMode.offsetEarliest));
      expect(
        searchBar.startStrategy,
        equals(MultiSearchStartStrategy.customOffset),
      );

      final streamCtrl = fakeActiveController.streamController;
      expect(streamCtrl.startStreamingCalled, isTrue);
      expect(streamCtrl.lastStartPartition, equals(2));
      expect(streamCtrl.lastStartOffset, equals(8888));
    },
  );
}
