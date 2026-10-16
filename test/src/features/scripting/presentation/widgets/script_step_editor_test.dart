import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_step_editor.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';

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
  MockClusterListController() : super();
  @override
  List<ClusterProfile> get clusters => [
    const ClusterProfile(name: "Cluster A", bootstrapServers: "localhost:9092"),
  ];
}

class MockTopicController extends TopicController {
  MockTopicController() : super();
  bool mockLoading = false;
  final List<TopicMetadata> mockTopics = [
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
  List<TopicMetadata>? getTopics(ClusterProfile cluster) => mockTopics;

  @override
  bool isLoading(ClusterProfile cluster) => mockLoading;
}

class MockSchemaRegistryService extends SchemaRegistryService {
  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) async =>
      [];
  @override
  Future<String> fetchSchema({
    required ClusterProfile profile,
    required String subject,
  }) async => '{}';
}

class MockSchemaController extends SchemaController {
  MockSchemaController() : super(registryService: MockSchemaRegistryService());
  @override
  Future<List<String>> fetchSchemaFields(
    ClusterProfile cluster,
    String topic,
  ) async => [];
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
    if (!GetIt.I.isRegistered<SchemaRegistryService>()) {
      GetIt.I.registerSingleton<SchemaRegistryService>(
        MockSchemaRegistryService(),
      );
    }
    if (!GetIt.I.isRegistered<SchemaController>()) {
      GetIt.I.registerSingleton<SchemaController>(MockSchemaController());
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

    // Expand Advanced Filters
    final advancedToggleFinder = find.text('Advanced Filters');
    await tester.ensureVisible(advancedToggleFinder);
    await tester.tap(advancedToggleFinder);
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

  testWidgets(
    'ScriptStepEditor displays topic chips and inline spinner without blocking UI during topic fetch',
    (WidgetTester tester) async {
      final topicController = GetIt.I<TopicController>() as MockTopicController;
      topicController.mockLoading = true;

      final step = ScriptStep(
        id: '1',
        name: 'Test Step',
        clusterName: 'Cluster A',
        topicNames: ['topic-a', 'topic-b'],
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
              child: ScriptStepEditor(
                step: step,
                variables: [],
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify chips are visible even when topics are still loading
      expect(find.widgetWithText(Chip, 'topic-a'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'topic-b'), findsOneWidget);

      // Verify inline CircularProgressIndicator inside TextFormField suffix
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Verify topics field shows loading hint
      expect(find.text('Loading topics...'), findsOneWidget);

      // Verify removing chip still functions while loading
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(Chip, 'topic-a'),
          matching: find.byIcon(Icons.cancel),
        ),
      );
      await tester.pump();

      expect(find.widgetWithText(Chip, 'topic-a'), findsNothing);
      expect(find.widgetWithText(Chip, 'topic-b'), findsOneWidget);

      topicController.mockLoading = false;
    },
  );

  testWidgets(
    'ScriptStepEditor allows manual topic addition when cluster is offline or unreachable',
    (WidgetTester tester) async {
      final step = ScriptStep(
        id: '1',
        name: 'Test Step',
        clusterName: 'Cluster A',
        topicNames: ['existing-topic'],
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
                onSave: (s) => savedStep = s,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find manual add button
      final addTopicButton = find.byTooltip('Add Topic Manually');
      expect(addTopicButton, findsOneWidget);

      await tester.tap(addTopicButton);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.text('Add Topic Manually'), findsOneWidget);
      final topicInput = find.widgetWithText(TextField, 'Enter topic name');
      expect(topicInput, findsOneWidget);

      // Enter manual topic name
      await tester.enterText(topicInput, 'offline-events');
      await tester.pump();

      // Confirm
      await tester.tap(find.widgetWithText(FilledButton, 'Add Topic'));
      await tester.pumpAndSettle();

      // Verify new chip exists
      expect(find.widgetWithText(Chip, 'existing-topic'), findsOneWidget);
      expect(find.widgetWithText(Chip, 'offline-events'), findsOneWidget);

      // Save step and verify
      final saveBtn = find.widgetWithText(FilledButton, 'Save');
      await tester.ensureVisible(saveBtn);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      expect(savedStep, isNotNull);
      expect(savedStep!.topicNames, ['existing-topic', 'offline-events']);
    },
  );

  testWidgets(
    'ScriptStepEditor preset selection updates scan mode and controls',
    (WidgetTester tester) async {
      final step = ScriptStep(
        id: '1',
        name: 'Scan Mode Step',
        clusterName: 'Cluster A',
        topicNames: ['topic-a'],
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
              child: ScriptStepEditor(
                step: step,
                variables: [],
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Dropdown should be initially Latest Messages
      final modeDropdown = find.byType(DropdownButtonFormField<TopicScanMode>);
      expect(modeDropdown, findsOneWidget);
      expect(find.text('Latest Messages'), findsOneWidget);

      // Switch to Live Stream
      await tester.tap(modeDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Live Stream').last);
      await tester.pumpAndSettle();

      // Should show streaming banner with sensors icon
      expect(find.byIcon(Icons.sensors), findsWidgets);

      // Switch to Time Range
      await tester.tap(modeDropdown);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Time Range').last);
      await tester.pumpAndSettle();

      expect(find.text('Start Timestamp'), findsOneWidget);
      expect(find.text('End Timestamp'), findsOneWidget);
    },
  );

  testWidgets(
    'ScriptStepEditor renders extraction source dropdown with dedicated width and uppercase items',
    (WidgetTester tester) async {
      final step = ScriptStep(
        id: '1',
        name: 'Extraction Step',
        clusterName: 'Cluster A',
        topicNames: ['topic-a'],
        extractions: [
          const ScriptExtraction(
            source: ScriptExtractionSource.key,
            variableName: 'userId',
            jsonPath: r'$.user.id',
          ),
        ],
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
              child: ScriptStepEditor(
                step: step,
                variables: [],
                onSave: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Value Extractions section
      expect(find.text('Value Extractions'), findsOneWidget);

      // Verify extraction source dropdown is inside a SizedBox with width: 120
      final sourceDropdown = find.byType(
        DropdownButtonFormField<ScriptExtractionSource>,
      );
      expect(sourceDropdown, findsOneWidget);

      final sizedBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: sourceDropdown,
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(sizedBox.width, 120.0);

      // Verify "KEY" is rendered
      expect(find.text('KEY'), findsOneWidget);

      // Open dropdown and verify "KEY" and "VALUE" items exist
      await tester.ensureVisible(sourceDropdown);
      await tester.tap(sourceDropdown);
      await tester.pumpAndSettle();

      expect(find.text('KEY'), findsWidgets);
      expect(find.text('VALUE'), findsOneWidget);
    },
  );
}
