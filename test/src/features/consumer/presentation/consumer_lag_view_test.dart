import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;

class FakeKafkaMetadataService implements KafkaMetadataService {
  List<ConsumerGroupLag> lags = [];
  bool shouldFail = false;

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerLags({
    required ClusterProfile profile,
  }) async {
    if (shouldFail) {
      throw Exception("Failed to fetch lags");
    }
    return lags;
  }

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroups({
    required ClusterProfile profile,
  }) async {
    if (shouldFail) {
      throw Exception("Failed to fetch groups");
    }
    return lags
        .map(
          (l) => ConsumerGroupLag(
            groupId: l.groupId,
            state: l.state,
            protocolType: l.protocolType,
            partitionLags: const [],
          ),
        )
        .toList();
  }

  @override
  Future<ConsumerGroupLag> fetchConsumerGroupLag({
    required ClusterProfile profile,
    required String groupId,
  }) async {
    if (shouldFail) {
      throw Exception("Failed to fetch lag");
    }
    return lags.firstWhere((l) => l.groupId == groupId);
  }

  @override
  Future<List<api.TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async {
    return [];
  }

  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async {
    return true;
  }
}

class FakeClusterListController extends ChangeNotifier
    implements ClusterListController {
  @override
  List<ClusterProfile> get clusters => [];

  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeKafkaMetadataService fakeMetadataService;
  late ActiveConnectionController activeConnectionController;
  late TopicController topicController;
  late FakeClusterListController fakeClusterListController;

  final testProfile = const ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
  );

  setUp(() {
    final getIt = GetIt.instance;
    getIt.reset();

    fakeMetadataService = FakeKafkaMetadataService();
    getIt.registerSingleton<Logger>(Logger());
    getIt.registerSingleton<KafkaMetadataService>(fakeMetadataService);

    topicController = TopicController();
    getIt.registerSingleton<TopicController>(topicController);

    fakeClusterListController = FakeClusterListController();
    getIt.registerSingleton<ClusterListController>(fakeClusterListController);

    activeConnectionController = ActiveConnectionController();
    getIt.registerSingleton<ActiveConnectionController>(
      activeConnectionController,
    );
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: const ConsumerLagView(),
    );
  }

  testWidgets('shows select cluster warning when no active cluster', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Please select a cluster'), findsOneWidget);
  });

  testWidgets('shows lags list when cluster is connected', (tester) async {
    fakeMetadataService.lags = [
      const ConsumerGroupLag(
        groupId: 'test-group',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'test-topic',
            partition: 0,
            logEndOffset: 100,
            currentOffset: 90,
            lag: 10,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Trigger connection
    await activeConnectionController.connect(testProfile);

    // Wait for groups fetch to finish and render list
    await tester.pump();
    await tester.pumpAndSettle();

    // Wait for lag details fetch to finish
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('test-group'), findsOneWidget);
    expect(find.text('Stable'), findsOneWidget);
    expect(find.text('Lag: 10'), findsOneWidget);
  });

  testWidgets('shows fetch status stats and sorts groups', (tester) async {
    fakeMetadataService.lags = [
      const ConsumerGroupLag(
        groupId: 'group-b',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'topic-1',
            partition: 0,
            logEndOffset: 100,
            currentOffset: 50,
            lag: 50,
          ),
        ],
      ),
      const ConsumerGroupLag(
        groupId: 'group-a',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'topic-1',
            partition: 0,
            logEndOffset: 100,
            currentOffset: 90,
            lag: 10,
          ),
        ],
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Trigger connection
    await activeConnectionController.connect(testProfile);

    // Wait for groups fetch to finish and render list
    await tester.pump();
    await tester.pumpAndSettle();

    // Wait for lag details fetch to finish
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify stats message is displayed
    expect(
      find.textContaining('Successfully loaded 2 consumer groups'),
      findsOneWidget,
    );

    // Verify default sort (Name A-Z): group-a should be first, then group-b
    var listTiles = find.byType(ExpansionTile);
    expect(listTiles, findsNWidgets(2));

    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(0), matching: find.text('group-a')),
      ),
      isNotNull,
    );
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(1), matching: find.text('group-b')),
      ),
      isNotNull,
    );

    // Change sort dropdown to Name (Z-A)
    final dropdownFinder = find.byType(
      DropdownButtonFormField<ConsumerGroupSortType>,
    );
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // Tap "Name (Z-A)" option
    await tester.tap(find.text('Name (Z-A)').last);
    await tester.pumpAndSettle();

    // Verify sort (Name Z-A): group-b should be first, then group-a
    listTiles = find.byType(ExpansionTile);
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(0), matching: find.text('group-b')),
      ),
      isNotNull,
    );
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(1), matching: find.text('group-a')),
      ),
      isNotNull,
    );

    // Change sort dropdown to Lag (Ascending)
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lag (Ascending)').last);
    await tester.pumpAndSettle();

    // Verify sort (Lag Ascending: 10 then 50): group-a should be first
    listTiles = find.byType(ExpansionTile);
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(0), matching: find.text('group-a')),
      ),
      isNotNull,
    );
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(1), matching: find.text('group-b')),
      ),
      isNotNull,
    );

    // Change sort dropdown to Lag (Descending)
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lag (Descending)').last);
    await tester.pumpAndSettle();

    // Verify sort (Lag Descending: 50 then 10): group-b should be first
    listTiles = find.byType(ExpansionTile);
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(0), matching: find.text('group-b')),
      ),
      isNotNull,
    );
    expect(
      tester.widget<Text>(
        find.descendant(of: listTiles.at(1), matching: find.text('group-a')),
      ),
      isNotNull,
    );
  });
}
