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
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/widgets/kpi_card.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/topic_partition_table.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:shared_preferences/shared_preferences.dart';

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
        .map<ConsumerGroupLag>(
          (l) => ConsumerGroupLag(
            groupId: l.groupId,
            state: l.state,
            protocolType: l.protocolType,
            partitionLags: const [],
            membersCount: l.membersCount,
            topicsCount: l.topicsCount,
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
    await Future.delayed(const Duration(milliseconds: 10));
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
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
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
        membersCount: 2,
        topicsCount: 1,
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
        membersCount: 3,
        topicsCount: 1,
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
      ),
      const ConsumerGroupLag(
        groupId: 'group-empty',
        state: 'Empty',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 0,
        topicsCount: 0,
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
      ),
      const ConsumerGroupLag(
        groupId: 'group-a',
        state: 'Empty',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 20,
        topicsCount: 2,
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
          ),
          TopicPartitionLag(
            topic: 'topic-z',
            partition: 0,
            logEndOffset: 200,
            currentOffset: 180,
            lag: 20,
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
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
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
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
      'consumer_max_concurrent_queries': 3,
    });

    tester.view.physicalSize = const Size(1000, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    fakeMetadataService.lags = List.generate(
      4,
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
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
      ),
    );

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    // Trigger connection
    await activeConnectionController.connect(testProfile);

    // Pump to resolve fetchConsumerGroups and trigger build
    await tester.pump();

    // Pump to render list and trigger post-frame callbacks
    await tester.pump();

    // Pump to run _loadGroupLag's synchronous setState
    // (adds first 3 to _loadingGroupIds, queues others)
    await tester.pump();

    // Expect 3 loading indicators (with strokeWidth == 2)
    final loadingSpinners = find.byWidgetPredicate(
      (widget) =>
          widget is CircularProgressIndicator && widget.strokeWidth == 2,
    );
    expect(loadingSpinners, findsNWidgets(3));

    // Wait for everything to resolve
    await tester.pumpAndSettle();

    // Verify all 4 resolved and show Lag: 10
    expect(find.text('Lag: 10'), findsNWidgets(4));
    expect(loadingSpinners, findsNothing);
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
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
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
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
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
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
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
            ),
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 80,
              lag: 20,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
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
            ),
            TopicPartitionLag(
              topic: 'test-topic',
              partition: 1,
              logEndOffset: 100,
              currentOffset: 82,
              lag: 18,
            ),
          ],
          membersCount: 1,
          topicsCount: 1,
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
          ),
        ],
        membersCount: 2000,
        topicsCount: 1500,
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
          ),
        ],
        membersCount: 1,
        topicsCount: 1,
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
}
