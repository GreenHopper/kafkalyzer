import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_step_editor.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kafkalyzer/src/services/cluster_service.dart';

import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

// Mock Dependencies
class MockKafkaMetadataService extends KafkaMetadataService {
  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async =>
      true;

  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async => [];
}

class MockClusterService extends ClusterService {
  @override
  Future<List<ClusterProfile>> loadClusters() async => [];
  @override
  Future<void> saveClusters(List<ClusterProfile> clusters) async {}
}

class MockClusterListController extends ClusterListController {
  MockClusterListController()
    : super(); // Adjust constructor if needed based on actual class
  @override
  List<ClusterProfile> get clusters => [
    const ClusterProfile(name: "Cluster A", bootstrapServers: "localhost:9092"),
  ];
}

class MockTopicController extends TopicController {
  MockTopicController() : super();
  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) => [
    const TopicMetadata(
      name: "topic-a",
      partitionCount: 1,
      replicationFactor: 1,
    ),
    TopicMetadata(
      name: "long-topic-${'a' * 300}",
      partitionCount: 1,
      replicationFactor: 1,
    ),
  ];
  @override
  bool isLoading(ClusterProfile cluster) => false;
}

void main() {
  setUpAll(() async {
    // Register mocks
    SharedPreferences.setMockInitialValues({});
    if (!GetIt.I.isRegistered<ClusterService>()) {
      GetIt.I.registerSingleton<ClusterService>(MockClusterService());
    }
    if (!GetIt.I.isRegistered<ClusterListController>()) {
      GetIt.I.registerSingleton<ClusterListController>(
        MockClusterListController(),
      );
    }
    if (!GetIt.I.isRegistered<KafkaMetadataService>()) {
      GetIt.I.registerSingleton<KafkaMetadataService>(
        MockKafkaMetadataService(),
      );
    }
    if (!GetIt.I.isRegistered<TopicController>()) {
      GetIt.I.registerSingleton<TopicController>(MockTopicController());
    }
  });

  testWidgets('ScriptStepEditor handles long topic names without overflow', (
    WidgetTester tester,
  ) async {
    final longTopicName = "long-topic-${'a' * 300}";
    final step = ScriptStep(
      id: '1',
      name: 'Test Step',
      clusterName: 'Cluster A',
      topicNames: [longTopicName],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScriptStepEditor(step: step, variables: [], onSave: (s) {}),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Find "Type" GroupButton
    final typeLabelFinder = find.text('Type');
    expect(typeLabelFinder, findsOneWidget);

    // Check for "Contains", "Regex", "Exact" buttons
    expect(find.text('Contains'), findsOneWidget);
    expect(find.text('Regex'), findsOneWidget);
    expect(find.text('Exact'), findsOneWidget);

    // Find "Scope" GroupButton
    final scopeLabelFinder = find.text('Scope');
    expect(scopeLabelFinder, findsOneWidget);

    // Check for "Key", "Value", "Both" buttons
    expect(find.text('Key'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Both'), findsOneWidget);
  });

  testWidgets(
    'ScriptStepEditor shows chips for selected topics and allows removal',
    (WidgetTester tester) async {
      final step = ScriptStep(
        id: '1',
        name: 'Test Step',
        clusterName: 'Cluster A',
        topicNames: ['topic-a', 'topic-b'],
      );

      ScriptStep? savedStep;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ScriptStepEditor(
                step: step,
                variables: [],
                onSave: (s) {
                  savedStep = s;
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify chips are present
      expect(find.widgetWithText(Chip, 'topic-a'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'topic-b'), findsOneWidget);

      // Verify text field summary
      expect(find.text('Select Topics (2 selected)'), findsOneWidget);

      // Remove 'topic-a'
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Chip, 'topic-a'),
          matching: find.byIcon(Icons.cancel),
        ),
      );
      await tester.pumpAndSettle();

      // Verify 'topic-a' is gone
      expect(find.widgetWithText(Chip, 'topic-a'), findsNothing);
      expect(find.widgetWithText(Chip, 'topic-b'), findsOneWidget);

      // Verify text field summary updated
      expect(find.text('Select Topics (1 selected)'), findsOneWidget);

      // Save and verify the step has updated topics
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveButtonFinder);
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(savedStep, isNotNull);
      expect(savedStep!.topicNames, ['topic-b']);
    },
  );
}
