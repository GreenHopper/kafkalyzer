import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/cluster_overview_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';

class _FakeMetadataService implements KafkaMetadataService {
  Future<ClusterOverview> Function(ClusterProfile profile)? onFetchOverview;

  @override
  Future<ClusterOverview> fetchClusterOverview({
    required ClusterProfile profile,
  }) {
    return onFetchOverview!(profile);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTopicController extends ChangeNotifier implements TopicController {
  int fetchTopicsCallCount = 0;

  @override
  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    fetchTopicsCallCount++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late RecentTopicsService recentTopicsService;
  late _FakeMetadataService fakeMetadata;
  late _FakeTopicController fakeTopicCtrl;
  late ClusterOverviewController overviewController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    recentTopicsService = RecentTopicsService(prefs: prefs);
    GetIt.instance.registerSingleton<RecentTopicsService>(recentTopicsService);

    fakeMetadata = _FakeMetadataService();
    fakeMetadata.onFetchOverview = (_) async => const ClusterOverview(
      brokers: [
        BrokerEndpoint(id: 3, host: 'broker-3.internal', port: 9092),
        BrokerEndpoint(id: 1, host: 'broker-1.internal', port: 9092),
        BrokerEndpoint(id: 2, host: 'broker-2.internal', port: 9092),
      ],
      clusterId: 'MkU3OEVBNTcwNTJENDM2Qg',
      controllerId: 2,
    );
    fakeTopicCtrl = _FakeTopicController();
    overviewController = ClusterOverviewController(
      metadataService: fakeMetadata,
      topicController: fakeTopicCtrl,
    );
  });

  final testCluster = ClusterProfile(
    name: 'TEST-CLUSTER',
    bootstrapServers: 'localhost:9092',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
    schemaRegistryUrl: 'http://localhost:8081',
    tlsVerification: TlsVerification.enabled,
  );

  List<TopicMetadata> sampleTopics({int unhealthy = 0, int unknownHealth = 0}) {
    return [
      const TopicMetadata(
        name: 'orders',
        partitionCount: 12,
        replicationFactor: 3,
        underReplicatedPartitions: 0,
        leaderlessPartitions: 0,
      ),
      const TopicMetadata(
        name: '__consumer_offsets',
        partitionCount: 50,
        replicationFactor: 3,
        underReplicatedPartitions: 0,
        leaderlessPartitions: 0,
      ),
      if (unhealthy > 0)
        TopicMetadata(
          name: 'payments',
          partitionCount: 6,
          replicationFactor: 3,
          underReplicatedPartitions: unhealthy,
          leaderlessPartitions: 1,
        ),
      if (unknownHealth > 0)
        const TopicMetadata(
          name: 'mystery',
          partitionCount: 3,
          replicationFactor: 1,
          underReplicatedPartitions: null,
          leaderlessPartitions: null,
        ),
    ];
  }

  Widget buildWidget({
    ClusterProfile? profile,
    List<TopicMetadata>? topics,
    bool isLoading = false,
    ValueChanged<String>? onSelectTopic,
    VoidCallback? onShowUnhealthyTopics,
    Locale? locale,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ClusterOverviewView(
          profile: profile ?? testCluster,
          topics: topics,
          isLoading: isLoading,
          onSelectTopic: onSelectTopic ?? (_) {},
          onShowUnhealthyTopics: onShowUnhealthyTopics,
          overviewController: overviewController,
        ),
      ),
    );
  }

  testWidgets(
    'renders brokers ordered by id, cluster id, controller, and totals',
    (tester) async {
      await tester.pumpWidget(buildWidget(topics: sampleTopics()));
      await tester.pumpAndSettle();

      expect(find.text('TEST-CLUSTER'), findsOneWidget);
      expect(find.text('localhost:9092'), findsOneWidget);
      expect(find.text('PLAINTEXT'), findsOneWidget);
      expect(find.text('Schema Registry Connected'), findsOneWidget);

      expect(find.text('Brokers (3)'), findsOneWidget);
      expect(
        find.textContaining('MkU3OEVBNTcwNTJENDM2Qg', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Broker 2 (broker-2.internal:9092)'), findsOneWidget);
      expect(find.text('Broker 2'), findsOneWidget);

      final y1 = tester.getTopLeft(find.text('broker-1.internal:9092')).dy;
      final y2 = tester.getTopLeft(find.text('broker-2.internal:9092')).dy;
      final y3 = tester.getTopLeft(find.text('broker-3.internal:9092')).dy;
      expect(y1, lessThan(y2));
      expect(y2, lessThan(y3));

      expect(find.text('2 Topics'), findsOneWidget);
      expect(find.text('62 Partitions'), findsOneWidget);
      expect(
        find.text('All topics fully replicated (0 unhealthy)'),
        findsOneWidget,
      );
    },
  );

  testWidgets('never shows 0 Topics when topics failed (null) or loading', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget(topics: null, isLoading: false));
    await tester.pumpAndSettle();

    expect(find.text('0 Topics'), findsNothing);
    expect(find.text('Topic & partition totals: unknown'), findsOneWidget);
    expect(find.text('Replication health: unknown'), findsOneWidget);

    await tester.pumpWidget(buildWidget(topics: null, isLoading: true));
    await tester.pump();
    expect(find.text('0 Topics'), findsNothing);
    expect(find.text('Loading topic totals…'), findsOneWidget);
    expect(find.text('Replication health: loading…'), findsOneWidget);
  });

  testWidgets('hides cluster id when absent and shows unknown controller', (
    tester,
  ) async {
    fakeMetadata.onFetchOverview = (_) async => const ClusterOverview(
      brokers: [BrokerEndpoint(id: 1, host: 'b1', port: 9092)],
      clusterId: null,
      controllerId: null,
    );

    await tester.pumpWidget(buildWidget(topics: sampleTopics()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Cluster ID', findRichText: true), findsNothing);
    expect(find.textContaining('Controller:'), findsOneWidget);
    expect(find.text('unknown'), findsOneWidget);
  });

  testWidgets('shows broker error and retries on button tap', (tester) async {
    var calls = 0;
    fakeMetadata.onFetchOverview = (_) async {
      calls++;
      if (calls == 1) {
        throw Exception('broker timeout');
      }
      return const ClusterOverview(
        brokers: [BrokerEndpoint(id: 1, host: 'recovered', port: 9092)],
        clusterId: 'cid',
        controllerId: 1,
      );
    };

    await tester.pumpWidget(buildWidget(topics: sampleTopics()));
    await tester.pumpAndSettle();

    expect(find.textContaining('broker timeout'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cluster_overview_brokers_retry')));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('recovered:9092'), findsOneWidget);
  });

  testWidgets('shows not-readable notice on authorization error', (
    tester,
  ) async {
    fakeMetadata.onFetchOverview = (_) async {
      throw Exception('TopicAuthorizationFailed');
    };

    await tester.pumpWidget(buildWidget(topics: sampleTopics()));
    await tester.pumpAndSettle();

    expect(find.text('Brokers not readable — permission?'), findsOneWidget);
  });

  testWidgets(
    'shows unhealthy drill-down button when > 0 and omits when 0, plus separate unknown health count',
    (tester) async {
      var drillDownTapped = 0;
      await tester.pumpWidget(
        buildWidget(
          topics: sampleTopics(unhealthy: 2, unknownHealth: 1),
          onShowUnhealthyTopics: () => drillDownTapped++,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 topic with unhealthy partitions'), findsOneWidget);
      expect(find.text('2 under-replicated, 1 leaderless'), findsOneWidget);
      expect(find.text('1 topic with unknown health'), findsOneWidget);

      final drillBtn = find.byTooltip('Filter topic list to unhealthy topics');
      expect(drillBtn, findsOneWidget);
      await tester.ensureVisible(drillBtn);
      await tester.tap(drillBtn);
      await tester.pump();
      expect(drillDownTapped, 1);

      // Healthy cluster: no drill-down button
      await tester.pumpWidget(
        buildWidget(
          topics: sampleTopics(unhealthy: 0),
          onShowUnhealthyTopics: () => drillDownTapped++,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip('Filter topic list to unhealthy topics'),
        findsNothing,
      );
    },
  );

  testWidgets('renders recent topics for this cluster and handles tap', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await recentTopicsService.recordVisit(
        clusterName: 'TEST-CLUSTER',
        topicName: 'analytics-events',
      );
      // Another cluster topic should not show up
      await recentTopicsService.recordVisit(
        clusterName: 'OTHER-CLUSTER',
        topicName: 'hidden-events',
      );
    });

    String? selectedTopic;
    await tester.pumpWidget(
      buildWidget(
        topics: sampleTopics(),
        onSelectTopic: (topic) {
          selectedTopic = topic;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recent Topics in TEST-CLUSTER'), findsOneWidget);
    expect(find.text('analytics-events'), findsOneWidget);
    expect(find.text('hidden-events'), findsNothing);

    await tester.ensureVisible(find.text('analytics-events'));
    await tester.tap(find.text('analytics-events'));
    await tester.pump();
    expect(selectedTopic, 'analytics-events');
  });

  testWidgets('renders German labels when locale is de', (tester) async {
    const profileWithoutRegistry = ClusterProfile(
      name: 'NO-REG',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.enabled,
    );
    await tester.pumpWidget(
      buildWidget(
        profile: profileWithoutRegistry,
        topics: sampleTopics(unhealthy: 1),
        onShowUnhealthyTopics: () {},
        locale: const Locale('de'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Broker (3)'), findsOneWidget);
    expect(find.text('3 Topics'), findsOneWidget);
    expect(find.text('1 Topic mit fehlerhaften Partitionen'), findsOneWidget);
    expect(find.text('Optionale Metadaten-Registry'), findsOneWidget);
  });
}
