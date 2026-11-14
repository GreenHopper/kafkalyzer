import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/cluster_dropdown.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:material_ui/material_ui.dart';

class _StubClusterService extends ClusterService {
  List<ClusterProfile> stored;
  _StubClusterService(this.stored);

  @override
  Future<List<ClusterProfile>> loadClusters() async => List.of(stored);

  @override
  Future<bool> saveClusters(List<ClusterProfile> clusters) async {
    stored = List.of(clusters);
    return true;
  }
}

class _StubTopicController extends TopicController {
  @override
  bool hasCachedTopics(ClusterProfile cluster) => false;

  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) => null;
}

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'EnvironmentTagChip renders label and semantics, hides when untagged',
    (tester) async {
      const tagged = ClusterProfile(
        name: 'orders-prod',
        bootstrapServers: 'b1:9093',
        tlsVerification: TlsVerification.enabled,
        environmentLabel: 'PROD',
        environmentColor: 'red',
      );
      const untagged = ClusterProfile(
        name: 'local',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.enabled,
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                EnvironmentTagChip(profile: tagged),
                EnvironmentTagChip(profile: untagged),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROD'), findsOneWidget);
      expect(find.bySemanticsLabel('Environment: PROD'), findsOneWidget);
    },
  );

  testWidgets(
    'EnvironmentBanner shows active cluster label and name when tagged',
    (tester) async {
      const tagged = ClusterProfile(
        name: 'orders-prod',
        bootstrapServers: 'b1:9093',
        tlsVerification: TlsVerification.enabled,
        environmentLabel: 'PROD',
        environmentColor: 'red',
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: EnvironmentBanner(profile: tagged)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PROD'), findsOneWidget);
      expect(find.text('orders-prod'), findsOneWidget);
    },
  );

  testWidgets(
    'ClusterDropdown renders environment chips next to tagged profiles',
    (tester) async {
      const prod = ClusterProfile(
        name: 'orders-prod',
        bootstrapServers: 'b1:9093',
        tlsVerification: TlsVerification.enabled,
        environmentLabel: 'PROD',
        environmentColor: 'red',
      );
      const dev = ClusterProfile(
        name: 'orders-dev',
        bootstrapServers: 'b2:9092',
        tlsVerification: TlsVerification.enabled,
        environmentLabel: 'DEV',
        environmentColor: 'green',
      );

      getIt.registerSingleton<KafkaMetadataService>(KafkaMetadataService());
      getIt.registerSingleton<ClusterService>(_StubClusterService([prod, dev]));
      final clusterCtrl = ClusterListController();
      await clusterCtrl.loadClusters();
      getIt.registerSingleton<ClusterListController>(clusterCtrl);
      getIt.registerSingleton<TopicController>(_StubTopicController());

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClusterDropdown(value: prod, onChanged: (_) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<ClusterProfile>));
      await tester.pumpAndSettle();

      expect(find.text('PROD'), findsWidgets);
      expect(find.text('DEV'), findsWidgets);
    },
  );

  testWidgets(
    'ClusterFilterField triggers onChanged and clears on suffix button',
    (tester) async {
      final ctrl = TextEditingController();
      var latest = '';
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClusterFilterField(
              controller: ctrl,
              onChanged: (v) => latest = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'prod');
      await tester.pump();
      expect(latest, 'prod');

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(latest, '');
      expect(ctrl.text, '');
      ctrl.dispose();
    },
  );
}
