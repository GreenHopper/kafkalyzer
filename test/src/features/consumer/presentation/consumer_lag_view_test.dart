import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/widgets/kpi_card.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/topic_partition_table.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/widgets/group_lag_badge.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/widgets/lag_trend.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';

class FakeKafkaMetadataService implements KafkaMetadataService {
  List<ConsumerGroupLag> lags = [];
  bool shouldFail = false;
  int fetchConsumerGroupsCallCount = 0;
  List<List<String>> fetchConsumerGroupLagsCalls = [];
  int inFlightChunkCalls = 0;
  int maxConcurrentChunkCalls = 0;
  Completer<void>? groupsCompleter;
  Completer<void>? chunkCompleter;
  Set<String> failingGroupIds = {};
  Duration chunkDelay = const Duration(milliseconds: 10);

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
    fetchConsumerGroupsCallCount++;
    if (groupsCompleter != null) {
      await groupsCompleter!.future;
    }
    if (shouldFail) {
      throw Exception("Failed to fetch groups");
    }
    return lags
        .map<ConsumerGroupLag>(
          (l) => ConsumerGroupLag(
            groupId: l.groupId,
            state: l.state,
            protocolType: l.protocolType,
            partitionLags: const [],
            membersCount: l.membersCount,
            topicsCount: l.topicsCount,
            members: l.members,
            unassignedPartitions: l.unassignedPartitions,
            ownershipKnown: l.ownershipKnown,
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
    await Future.delayed(chunkDelay);
    if (failingGroupIds.contains(groupId)) {
      return ConsumerGroupLag(
        groupId: groupId,
        state: 'Empty',
        protocolType: 'consumer',
        partitionLags: const [],
        membersCount: 0,
        topicsCount: 0,
        members: const [],
        unassignedPartitions: const [],
        ownershipKnown: false,
        lagError: 'Broker timeout for $groupId',
      );
    }
    return lags.firstWhere((l) => l.groupId == groupId);
  }

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroupLags({
    required ClusterProfile profile,
    required List<String> groupIds,
  }) async {
    fetchConsumerGroupLagsCalls.add(List.of(groupIds));
    inFlightChunkCalls++;
    if (inFlightChunkCalls > maxConcurrentChunkCalls) {
      maxConcurrentChunkCalls = inFlightChunkCalls;
    }
    try {
      if (chunkCompleter != null) {
        await chunkCompleter!.future;
      }
      if (shouldFail) {
        throw Exception("Failed to fetch lags");
      }
      await Future.delayed(chunkDelay);
      return groupIds.map((id) {
        if (failingGroupIds.contains(id)) {
          return ConsumerGroupLag(
            groupId: id,
            state: 'Empty',
            protocolType: 'consumer',
            partitionLags: const [],
            membersCount: 0,
            topicsCount: 0,
            members: const [],
            unassignedPartitions: const [],
            ownershipKnown: false,
            lagError: 'Broker timeout for $id',
          );
        }
        return lags.firstWhere((l) => l.groupId == id);
      }).toList();
    } finally {
      inFlightChunkCalls--;
    }
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

ConsumerGroupLag _groupWithLag(int lag) => ConsumerGroupLag(
  groupId: 'test-group',
  state: 'Stable',
  protocolType: 'consumer',
  partitionLags: [
    TopicPartitionLag(
      topic: 'test-topic',
      partition: 0,
      logEndOffset: 1000,
      currentOffset: 1000 - lag,
      lag: lag,
      status: PartitionLagStatus.known,
    ),
  ],
  membersCount: 1,
  topicsCount: 1,
  members: const [],
  unassignedPartitions: const [],
  ownershipKnown: true,
);

/// Readings the trend of `groupId` currently retains.
List<int> _retainedReadings(WidgetTester tester, String groupId) => tester
    .widget<LagTrend>(find.byKey(Key('group_lag_trend_$groupId')))
    .readings;

void main() {
  late FakeKafkaMetadataService fakeMetadataService;
  late ActiveConnectionController activeConnectionController;
  late TopicController topicController;
  late FakeClusterListController fakeClusterListController;

  final testProfile = const ClusterProfile(
    name: 'test-cluster',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
  );

  setUp(() {
    final getIt = GetIt.instance;
    getIt.reset();

    fakeMetadataService = FakeKafkaMetadataService();
    getIt.registerSingleton<Logger>(Logger());
    getIt.registerSingleton<KafkaMetadataService>(fakeMetadataService);
    getIt.registerSingleton<SettingsService>(SettingsService());

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
        ...GlobalMaterialLocalizations.delegates,
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

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
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

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 2,
        topicsCount: 1,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
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

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 3,
        topicsCount: 1,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
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
  });

  testWidgets('filters by state and shows search statistics', (tester) async {
    fakeMetadataService.lags = [
      const ConsumerGroupLag(
        groupId: 'group-stable',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 1,
        topicsCount: 1,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
      ),
      const ConsumerGroupLag(
        groupId: 'group-empty',
        state: 'Empty',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 0,
        topicsCount: 0,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    await activeConnectionController.connect(testProfile);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    final kpiCardFinder = find.widgetWithText(KpiCard, 'Consumer Groups');
    expect(kpiCardFinder, findsOneWidget);
    expect(
      find.descendant(of: kpiCardFinder, matching: find.text('2')),
      findsOneWidget,
    );

    final stateDropdownFinder = find.byType(DropdownButtonFormField<String>);
    expect(stateDropdownFinder, findsOneWidget);
    await tester.tap(stateDropdownFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stable').last);
    await tester.pumpAndSettle();

    expect(find.text('group-stable'), findsOneWidget);
    expect(find.text('group-empty'), findsNothing);
    expect(
      find.descendant(of: kpiCardFinder, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: kpiCardFinder, matching: find.text('of 2')),
      findsOneWidget,
    );
  });

  testWidgets('sorts by clicking column headers', (tester) async {
    fakeMetadataService.lags = [
      const ConsumerGroupLag(
        groupId: 'group-b',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 10,
        topicsCount: 5,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
      ),
      const ConsumerGroupLag(
        groupId: 'group-a',
        state: 'Empty',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 20,
        topicsCount: 2,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    await activeConnectionController.connect(testProfile);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump();
    await tester.pumpAndSettle();

    var expansionTiles = find.byType(ExpansionTile);
    expect(
      tester.widget<Text>(
        find.descendant(
          of: expansionTiles.at(0),
          matching: find.text('group-a'),
        ),
      ),
      isNotNull,
    );

    await tester.tap(find.text('Consumers'));
    await tester.pumpAndSettle();

    expansionTiles = find.byType(ExpansionTile);
    expect(
      tester.widget<Text>(
        find.descendant(
          of: expansionTiles.at(0),
          matching: find.text('group-b'),
        ),
      ),
      isNotNull,
    );

    await tester.tap(find.text('Consumers'));
    await tester.pumpAndSettle();

    expansionTiles = find.byType(ExpansionTile);
    expect(
      tester.widget<Text>(
        find.descendant(
          of: expansionTiles.at(0),
          matching: find.text('group-a'),
        ),
      ),
      isNotNull,
    );
  });

  testWidgets('configures refresh interval via dropdown', (tester) async {
    fakeMetadataService.lags = [];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    final refreshDropdown = find.byType(DropdownButtonFormField<int>);
    expect(refreshDropdown, findsOneWidget);

    await tester.tap(refreshDropdown);
    await tester.pumpAndSettle();

    await tester.tap(find.text('5s').last);
    await tester.pumpAndSettle();

    final dropdownState = tester.state<FormFieldState<int>>(refreshDropdown);
    expect(dropdownState.value, equals(5));
  });

  testWidgets('groups partitions by topic and supports partition sorting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeMetadataService.lags = [
      const ConsumerGroupLag(
        groupId: 'test-group',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'topic-z',
            partition: 1,
            logEndOffset: 100,
            currentOffset: 95,
            lag: 5,

            status: PartitionLagStatus.known,
          ),
          TopicPartitionLag(
            topic: 'topic-z',
            partition: 0,
            logEndOffset: 200,
            currentOffset: 180,
            lag: 20,

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
      ),
    ];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    await activeConnectionController.connect(testProfile);
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.pump();
    await tester.pumpAndSettle();

    await tester.tap(find.text('test-group'));
    await tester.pumpAndSettle();

    expect(find.text('topic-z'), findsOneWidget);
    expect(find.text('Lag: 25'), findsNWidgets(2));

    await tester.tap(find.text('topic-z'));
    await tester.pumpAndSettle();

    expect(find.text('Partition'), findsOneWidget);
    expect(find.text('Log End Offset'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(TopicPartitionTable),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(TopicPartitionTable),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('preserves cached lag value during refresh/re-fetch', (
    tester,
  ) async {
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

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
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

    expect(find.text('Lag: 10'), findsOneWidget);

    // Now trigger refresh by changing interval dropdown
    final refreshDropdown = find.byType(DropdownButtonFormField<int>);
    await tester.tap(refreshDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15s').last);
    await tester.pump(); // Start fetching groups
    await tester.pump(); // Start loading lag details

    // Use cached lag value
    expect(find.text('Lag: 10'), findsOneWidget);

    // Verify tiny loading indicator is present
    final loadingProgressIndicator = find.byWidgetPredicate(
      (widget) =>
          widget is CircularProgressIndicator && widget.strokeWidth == 1.5,
    );
    expect(loadingProgressIndicator, findsOneWidget);

    // Let the detail fetch resolve
    await tester.pumpAndSettle();
    expect(find.text('Lag: 10'), findsOneWidget);
    expect(loadingProgressIndicator, findsNothing);
  });

  testWidgets('limits concurrent lag queries and processes them via queue', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'consumer_max_concurrent_queries': 2,
    });

    fakeMetadataService.lags = List.generate(
      45,
      (i) => ConsumerGroupLag(
        groupId: 'group-$i',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'topic-1',
            partition: 0,
            logEndOffset: 100,
            currentOffset: 90,
            lag: 10,
            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
        members: const [],
        unassignedPartitions: const [],
        ownershipKnown: true,
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    expect(fakeMetadataService.maxConcurrentChunkCalls, lessThanOrEqualTo(2));
    expect(fakeMetadataService.fetchConsumerGroupLagsCalls.length, 3);
    expect(
      fakeMetadataService.fetchConsumerGroupLagsCalls.expand((c) => c).length,
      45,
    );
  });

  testWidgets('defaults refresh interval to 30s', (tester) async {
    fakeMetadataService.lags = [];
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    final refreshDropdown = find.byType(DropdownButtonFormField<int>);
    expect(refreshDropdown, findsOneWidget);
    final dropdownState = tester.state<FormFieldState<int>>(refreshDropdown);
    expect(dropdownState.value, equals(30));
  });

  testWidgets(
    'calculates and displays committed offset delta (Processed) column',
    (tester) async {
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

              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: [],
          unassignedPartitions: [],
          ownershipKnown: true,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await activeConnectionController.connect(testProfile);
      await tester.pumpAndSettle();

      await tester.pump();
      await tester.pumpAndSettle();

      // On first load, delta is not available (displays "-")
      expect(find.text('-'), findsOneWidget);
      expect(find.textContaining('Change:'), findsNothing);

      // Update committed offset from 90 to 95 (+5 delta)
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
              currentOffset: 95,
              lag: 5,

              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: [],
          unassignedPartitions: [],
          ownershipKnown: true,
        ),
      ];

      // Trigger refresh by changing interval dropdown
      final refreshDropdown = find.byType(DropdownButtonFormField<int>);
      await tester.tap(refreshDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15s').last);
      await tester.pump(); // Fetch group overview
      await tester.pump(); // Fetch group details
      await tester.pumpAndSettle();

      // Verify "-5" delta is displayed (lag decreased, messages processed)
      expect(find.text('-5'), findsOneWidget);
      expect(find.text('Change: -5'), findsOneWidget);

      // Now update lag to increase (e.g. lag goes from 5 to 12)
      fakeMetadataService.lags = [
        const ConsumerGroupLag(
          groupId: 'test-group',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 0,
              logEndOffset: 107,
              currentOffset: 95,
              lag: 12,

              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: [],
          unassignedPartitions: [],
          ownershipKnown: true,
        ),
      ];

      // Trigger another refresh by changing interval dropdown to 5s
      await tester.tap(refreshDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('5s').last);
      await tester.pump(); // Fetch group overview
      await tester.pump(); // Fetch group details
      await tester.pumpAndSettle();

      // Verify "+7" delta is displayed (lag increased by 7)
      expect(find.text('+7'), findsOneWidget);
      expect(find.text('Change: +7'), findsOneWidget);
    },
  );

  testWidgets(
    'calculates and displays topic and partition deltas in detail widgets',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

              status: PartitionLagStatus.known,
            ),
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 80,
              lag: 20,

              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: [],
          unassignedPartitions: [],
          ownershipKnown: true,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await activeConnectionController.connect(testProfile);
      await tester.pumpAndSettle();

      await tester.pump();
      await tester.pumpAndSettle();

      // Expand group card
      await tester.tap(find.text('test-group'));
      await tester.pumpAndSettle();

      // Expand topic card
      await tester.tap(find.text('test-topic'));
      await tester.pumpAndSettle();

      // Verify initial deltas are "-" (group, topic, and 2 partitions)
      expect(find.text('-'), findsNWidgets(4));

      // Update lag values (partition 0: 10 -> 3 (-7), partition 1: 20 -> 18 (-2))
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
              currentOffset: 97,
              lag: 3,

              status: PartitionLagStatus.known,
            ),
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 82,
              lag: 18,

              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: [],
          unassignedPartitions: [],
          ownershipKnown: true,
        ),
      ];

      // Trigger refresh by changing interval dropdown to 15s
      final refreshDropdown = find.byType(DropdownButtonFormField<int>);
      await tester.tap(refreshDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('15s').last);
      await tester.pump(); // Fetch group overview
      await tester.pump(); // Fetch group details
      await tester.pumpAndSettle();

      // Verify deltas:
      // Group delta: -9
      // Topic delta: -9
      // Partition 0 delta: -7
      // Partition 1 delta: -2
      expect(find.text('-9'), findsNWidgets(2));
      expect(find.text('-7'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);

      // Test partition sorting on delta column
      final processedHeader = find.descendant(
        of: find.byType(TopicPartitionTable),
        matching: find.text('Processed'),
      );
      await tester.tap(processedHeader);
      await tester.pumpAndSettle();

      // Click again for descending sort
      await tester.tap(processedHeader);
      await tester.pumpAndSettle();
    },
  );

  testWidgets('formats numbers with thousands separators based on locale', (
    tester,
  ) async {
    fakeMetadataService.lags = [
      const ConsumerGroupLag(
        groupId: 'test-group',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'test-topic',
            partition: 0,
            logEndOffset: 1000000,
            currentOffset: 900000,
            lag: 100000,

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 2000,
        topicsCount: 1500,
        members: [],
        unassignedPartitions: [],
        ownershipKnown: true,
      ),
    ];

    // Build with English locale
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: const [Locale('en')],
        locale: const Locale('en'),
        home: const ConsumerLagView(),
      ),
    );
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    await tester.pump();
    await tester.pumpAndSettle();

    // 2,000 for consumers, 1,500 for topics, 100,000 for lag
    expect(find.text('2,000'), findsOneWidget);
    expect(find.text('1,500'), findsOneWidget);
    expect(find.text('Lag: 100,000'), findsOneWidget);
  });

  testWidgets('widget unmounting stops background queue', (tester) async {
    SharedPreferences.setMockInitialValues({
      'consumer_max_concurrent_queries': 3,
    });

    fakeMetadataService.lags = List.generate(
      5,
      (i) => ConsumerGroupLag(
        groupId: 'group-$i',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'topic-1',
            partition: 0,
            logEndOffset: 100,
            currentOffset: 90,
            lag: 10,

            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
        members: const [],
        unassignedPartitions: const [],
        ownershipKnown: true,
      ),
    );

    final controller = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      ValueListenableBuilder<bool>(
        valueListenable: controller,
        builder: (context, show, _) {
          return MaterialApp(
            localizationsDelegates: const [
              AppLocalizations.delegate,
              ...GlobalMaterialLocalizations.delegates,
            ],
            supportedLocales: const [Locale('en')],
            home: show ? const ConsumerLagView() : const SizedBox(),
          );
        },
      ),
    );
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pump();
    await tester.pump(); // Starts loading first 3

    controller.value = false;
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
  });

  testWidgets('five refreshes retain five readings for the trend', (
    tester,
  ) async {
    fakeMetadataService.lags = [_groupWithLag(10)];
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    // One reading after the first load: too few to draw a trend.
    expect(_retainedReadings(tester, 'test-group'), [10]);
    expect(find.byKey(const Key('lag_trend')), findsNothing);

    final refreshDropdown = find.byType(DropdownButtonFormField<int>);
    await tester.tap(refreshDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5s').last);
    await tester.pumpAndSettle();

    for (var i = 1; i < 4; i++) {
      fakeMetadataService.lags = [_groupWithLag(10 + i * 100)];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    expect(_retainedReadings(tester, 'test-group').length, 5);
  });

  testWidgets('the retained trend history never exceeds 20 readings', (
    tester,
  ) async {
    fakeMetadataService.lags = [_groupWithLag(10)];
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    final refreshDropdown = find.byType(DropdownButtonFormField<int>);
    await tester.tap(refreshDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5s').last);
    await tester.pumpAndSettle();

    for (var i = 1; i < 26; i++) {
      fakeMetadataService.lags = [_groupWithLag(10 + i * 10)];
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    }

    expect(_retainedReadings(tester, 'test-group').length, 20);
  });

  testWidgets('switching to another cluster starts with an empty history', (
    tester,
  ) async {
    fakeMetadataService.lags = [_groupWithLag(10)];
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    final refreshDropdown = find.byType(DropdownButtonFormField<int>);
    await tester.tap(refreshDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('5s').last);
    await tester.pumpAndSettle();
    fakeMetadataService.lags = [_groupWithLag(210)];
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(
      _retainedReadings(tester, 'test-group').length,
      greaterThanOrEqualTo(2),
    );

    await activeConnectionController.connect(
      const ClusterProfile(
        name: 'other-cluster',
        bootstrapServers: 'other:9092',
        tlsVerification: TlsVerification.enabled,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('lag_trend')), findsNothing);
  });

  testWidgets('a group at 8000 is marked at threshold 5000', (tester) async {
    SharedPreferences.setMockInitialValues({
      'consumer_lag_warn_threshold': 5000,
    });
    fakeMetadataService.lags = [_groupWithLag(8000)];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    final badge = tester.widget<GroupLagBadge>(find.byType(GroupLagBadge));
    expect(badge.warnThreshold, 5000);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });

  testWidgets('a group at 1200 is not marked at threshold 5000', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'consumer_lag_warn_threshold': 5000,
    });
    fakeMetadataService.lags = [_groupWithLag(1200)];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('a disabled threshold marks nothing', (tester) async {
    SharedPreferences.setMockInitialValues({'consumer_lag_warn_threshold': 0});
    fakeMetadataService.lags = [_groupWithLag(999999)];

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets(
    'single-flight refresh skips overlapping timer tick and cluster switch discards late results',
    (tester) async {
      SharedPreferences.setMockInitialValues({'consumer_refresh_interval': 5});
      final completer = Completer<void>();
      fakeMetadataService.groupsCompleter = completer;
      fakeMetadataService.lags = [
        ConsumerGroupLag(
          groupId: 'old-cluster-group',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [
            TopicPartitionLag(
              topic: 't',
              partition: 0,
              logEndOffset: 10,
              currentOffset: 5,
              lag: 5,
              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: const [],
          unassignedPartitions: const [],
          ownershipKnown: true,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await activeConnectionController.connect(testProfile);
      await tester.pump();

      expect(fakeMetadataService.fetchConsumerGroupsCallCount, 1);

      // Advance past the 5s timer while the first fetch is still in flight.
      await tester.pump(const Duration(seconds: 6));
      expect(fakeMetadataService.fetchConsumerGroupsCallCount, 1);

      // Switch to a new cluster while the old fetch is still pending.
      final newCluster = ClusterProfile(
        name: 'other-cluster',
        bootstrapServers: 'other:9092',
        tlsVerification: TlsVerification.enabled,
      );
      fakeMetadataService.groupsCompleter = null;
      fakeMetadataService.lags = [
        ConsumerGroupLag(
          groupId: 'new-cluster-group',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [
            TopicPartitionLag(
              topic: 't',
              partition: 0,
              logEndOffset: 20,
              currentOffset: 10,
              lag: 10,
              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: const [],
          unassignedPartitions: const [],
          ownershipKnown: true,
        ),
      ];
      await activeConnectionController.connect(newCluster);
      await tester.pump();

      // Complete the stale first request; its results must be discarded.
      completer.complete();
      await tester.pumpAndSettle();

      expect(find.text('new-cluster-group'), findsOneWidget);
      expect(find.text('old-cluster-group'), findsNothing);
    },
  );

  testWidgets('eager chunked loading loads all 40 groups even off-screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeMetadataService.lags = List.generate(
      40,
      (i) => ConsumerGroupLag(
        groupId: 'eager-group-${i.toString().padLeft(2, '0')}',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 'topic-1',
            partition: 0,
            logEndOffset: 100,
            currentOffset: 90,
            lag: 10,
            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
        members: const [],
        unassignedPartitions: const [],
        ownershipKnown: true,
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();
    await activeConnectionController.connect(testProfile);
    await tester.pumpAndSettle();

    expect(fakeMetadataService.fetchConsumerGroupLagsCalls.length, 2);
    expect(
      fakeMetadataService.fetchConsumerGroupLagsCalls.expand((c) => c).length,
      40,
    );
    expect(find.text('400'), findsOneWidget);
  });

  testWidgets(
    'KPI shows loaded progress while loading, Total incomplete on error, and sorts unknown last',
    (tester) async {
      final chunkGate = Completer<void>();
      fakeMetadataService.chunkCompleter = chunkGate;
      fakeMetadataService.lags = List.generate(
        25,
        (i) => ConsumerGroupLag(
          groupId: 'grp-${i.toString().padLeft(2, '0')}',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [
            TopicPartitionLag(
              topic: 't',
              partition: 0,
              logEndOffset: 100,
              currentOffset: 100 - (i + 1),
              lag: i + 1,
              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: const [],
          unassignedPartitions: const [],
          ownershipKnown: true,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await activeConnectionController.connect(testProfile);
      await tester.pump();
      await tester.pump();

      // While chunks are still pending, progress is shown (0 of 25 loaded)
      expect(find.text('0 of 25 loaded'), findsOneWidget);

      // Fail one group and release gate
      fakeMetadataService.failingGroupIds = {'grp-00'};
      fakeMetadataService.chunkCompleter = null;
      chunkGate.complete();
      await tester.pumpAndSettle();

      expect(find.text('Total incomplete'), findsOneWidget);
      expect(find.text('Error'), findsWidgets);

      // Sort by Lag ascending: grp-01 (lag 2) < grp-02 (lag 3), and grp-00 (unknown) is at the bottom
      await tester.tap(find.text('Total Lag').last);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('grp-01')).dy,
        lessThan(tester.getTopLeft(find.text('grp-02')).dy),
      );
      final listScrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('grp-00'),
        300,
        scrollable: listScrollable,
      );
      expect(
        tester.getTopLeft(find.text('grp-24')).dy,
        lessThan(tester.getTopLeft(find.text('grp-00')).dy),
      );

      // Sort by Lag descending: grp-24 (lag 25) > grp-23 (lag 24), and grp-00 (unknown) is still at the bottom
      await tester.tap(find.text('Total Lag').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('grp-24'),
        -300,
        scrollable: listScrollable,
      );
      expect(
        tester.getTopLeft(find.text('grp-24')).dy,
        lessThan(tester.getTopLeft(find.text('grp-23')).dy),
      );
      await tester.scrollUntilVisible(
        find.text('grp-00'),
        300,
        scrollable: listScrollable,
      );
      expect(
        tester.getTopLeft(find.text('grp-01')).dy,
        lessThan(tester.getTopLeft(find.text('grp-00')).dy),
      );
    },
  );

  testWidgets(
    'failed group shows Error badge, expands error card, and retries only that group',
    (tester) async {
      fakeMetadataService.failingGroupIds = {'bad-group'};
      fakeMetadataService.lags = [
        ConsumerGroupLag(
          groupId: 'good-group',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [
            TopicPartitionLag(
              topic: 't',
              partition: 0,
              logEndOffset: 100,
              currentOffset: 95,
              lag: 5,
              status: PartitionLagStatus.known,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
          members: const [],
          unassignedPartitions: const [],
          ownershipKnown: true,
        ),
        ConsumerGroupLag(
          groupId: 'bad-group',
          state: 'Empty',
          protocolType: 'consumer',
          partitionLags: const [],
          membersCount: 0,
          topicsCount: 0,
          members: const [],
          unassignedPartitions: const [],
          ownershipKnown: false,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await activeConnectionController.connect(testProfile);
      await tester.pumpAndSettle();

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Lag: 5'), findsOneWidget);

      // Expand bad-group to see error card and retry button
      await tester.tap(find.text('bad-group'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('group_lag_error_card')), findsOneWidget);
      expect(
        find.textContaining('Broker timeout for bad-group'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('group_lag_retry_button')), findsOneWidget);

      // Clear failure and retry only bad-group
      fakeMetadataService.fetchConsumerGroupLagsCalls.clear();
      fakeMetadataService.failingGroupIds.clear();
      fakeMetadataService.lags[1] = ConsumerGroupLag(
        groupId: 'bad-group',
        state: 'Empty',
        protocolType: 'consumer',
        partitionLags: [
          TopicPartitionLag(
            topic: 't',
            partition: 0,
            logEndOffset: 50,
            currentOffset: 40,
            lag: 10,
            status: PartitionLagStatus.known,
          ),
        ],
        membersCount: 0,
        topicsCount: 1,
        members: const [],
        unassignedPartitions: const [],
        ownershipKnown: false,
      );

      await tester.tap(find.byKey(const Key('group_lag_retry_button')));
      await tester.pumpAndSettle();

      expect(fakeMetadataService.fetchConsumerGroupLagsCalls, [
        ['bad-group'],
      ]);
      expect(find.text('Error'), findsNothing);
      expect(find.text('Lag: 10'), findsWidgets);
    },
  );
}
