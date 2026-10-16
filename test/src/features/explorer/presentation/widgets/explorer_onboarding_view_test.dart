import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/widgets/explorer_onboarding_view.dart';
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
    name: 'PROD',
    bootstrapServers: 'kafka-prod:9092',
    securityProtocol: 'sasl_ssl',
    mechanism: 'scram_sha_512',
    schemaRegistryUrl: 'http://registry:8081',
  );

  Widget buildWidget({
    List<ClusterProfile> clusters = const [],
    VoidCallback? onAddCluster,
    ValueChanged<ClusterProfile>? onSelectCluster,
    void Function(String, String)? onSelectRecentTopic,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ExplorerOnboardingView(
          clusters: clusters,
          onAddCluster: onAddCluster ?? () {},
          onSelectCluster: onSelectCluster ?? (_) {},
          onSelectRecentTopic: onSelectRecentTopic ?? (_, _) {},
        ),
      ),
    );
  }

  testWidgets('renders welcome header and empty guide when no clusters', (
    tester,
  ) async {
    bool addCalled = false;
    await tester.pumpWidget(
      buildWidget(
        clusters: [],
        onAddCluster: () {
          addCalled = true;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Kafkalyzer'), findsOneWidget);
    expect(find.text('No clusters configured yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Add Cluster'));
    await tester.pump();
    expect(addCalled, isTrue);
  });

  testWidgets('renders cluster cards and connects on tap', (tester) async {
    ClusterProfile? selected;
    await tester.pumpWidget(
      buildWidget(
        clusters: [testCluster],
        onSelectCluster: (c) {
          selected = c;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PROD'), findsOneWidget);
    expect(find.text('kafka-prod:9092'), findsOneWidget);
    expect(find.text('SASL_SSL'), findsOneWidget);
    expect(find.text('Schema Registry Connected'), findsOneWidget);

    await tester.tap(find.text('Connect'));
    await tester.pump();
    expect(selected?.name, 'PROD');
  });

  testWidgets('renders recent topics when available', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.runAsync(() async {
      await recentTopicsService.recordVisit(
        clusterName: 'PROD',
        topicName: 'orders-topic',
      );
    });

    String? selectedCluster;
    String? selectedTopic;

    await tester.pumpWidget(
      buildWidget(
        clusters: [testCluster],
        onSelectRecentTopic: (c, t) {
          selectedCluster = c;
          selectedTopic = t;
        },
      ),
    );
    await tester.pump();

    expect(find.text('Recently Viewed Topics'), findsOneWidget);
    expect(find.text('orders-topic'), findsOneWidget);

    await tester.tap(find.text('orders-topic'));
    await tester.pump();
    expect(selectedCluster, 'PROD');
    expect(selectedTopic, 'orders-topic');
  });
}
