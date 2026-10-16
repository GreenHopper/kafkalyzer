import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/cluster_overview_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';

void main() {
  late RecentTopicsService recentTopicsService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    final prefs = await SharedPreferences.getInstance();
    recentTopicsService = RecentTopicsService(prefs: prefs);
    GetIt.instance.registerSingleton<RecentTopicsService>(recentTopicsService);
  });



  final testCluster = ClusterProfile(
    name: 'TEST-CLUSTER',
    bootstrapServers: 'localhost:9092',
    securityProtocol: 'plaintext',
    mechanism: 'plain',
    schemaRegistryUrl: 'http://localhost:8081',
  );

  Widget buildWidget({
    ClusterProfile? profile,
    int topicCount = 42,
    bool isLoading = false,
    ValueChanged<String>? onSelectTopic,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ClusterOverviewView(
          profile: profile ?? testCluster,
          topicCount: topicCount,
          isLoading: isLoading,
          onSelectTopic: onSelectTopic ?? (_) {},
        ),
      ),
    );
  }

  testWidgets('renders cluster metrics and information correctly', (
    tester,
  ) async {
    await tester.pumpWidget(buildWidget(topicCount: 15));
    await tester.pump();

    expect(find.text('TEST-CLUSTER'), findsOneWidget);
    expect(find.text('localhost:9092'), findsOneWidget);
    expect(find.text('PLAINTEXT'), findsOneWidget);
    expect(find.text('15 Topics'), findsOneWidget);
    expect(find.text('Schema Registry Connected'), findsOneWidget);
  });

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
        onSelectTopic: (topic) {
          selectedTopic = topic;
        },
      ),
    );
    await tester.pump();

    expect(
      find.text('Recent Topics in TEST-CLUSTER'),
      findsOneWidget,
    );
    expect(find.text('analytics-events'), findsOneWidget);
    expect(find.text('hidden-events'), findsNothing);

    await tester.tap(find.text('analytics-events'));
    await tester.pump();
    expect(selectedTopic, 'analytics-events');
  });
}
