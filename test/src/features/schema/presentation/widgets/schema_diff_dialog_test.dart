import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_diff_dialog.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:material_ui/material_ui.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

@GenerateMocks([SchemaController])
import 'schema_diff_dialog_test.mocks.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('computeLineDiff', () {
    test('identical schemas report no differences', () {
      const v1 = '{"type": "record", "name": "User"}';
      final diff = computeLineDiff(v1, v1);
      expect(diff.every((l) => l.type == DiffLineType.unchanged), isTrue);
    });

    test('detects added and removed lines', () {
      const oldJson = '{\n  "name": "User"\n}';
      const newJson = '{\n  "name": "User",\n  "age": 30\n}';
      final diff = computeLineDiff(oldJson, newJson);
      expect(diff.any((l) => l.type == DiffLineType.added), isTrue);
    });
  });

  group('SchemaDiffDialog Widget Tests', () {
    late MockSchemaController mockController;
    final testProfile = ClusterProfile(
      name: 'test-cluster',
      bootstrapServers: 'localhost:9092',
      schemaRegistryUrl: 'http://localhost:8081',
      securityProtocol: 'plaintext',
      mechanism: 'plain',
    );

    setUp(() {
      mockController = MockSchemaController();
    });

    Widget createTestApp(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets('renders diff tab and displays diff content between versions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        mockController.fetchSchemaVersions(any, any),
      ).thenAnswer((_) async => [1, 2]);
      when(
        mockController.fetchSchemaContent(any, any, version: 1),
      ).thenAnswer((_) async => '{"type": "string"}');
      when(
        mockController.fetchSchemaContent(any, any, version: 2),
      ).thenAnswer((_) async => '{"type": "int"}');
      when(
        mockController.getAssociatedTopics(any, any),
      ).thenAnswer((_) async => ['test-topic']);

      await tester.pumpWidget(
        createTestApp(
          SchemaDiffDialog(
            profile: testProfile,
            subject: 'test-topic-value',
            controller: mockController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Schema Version Diff'), findsOneWidget);
      expect(find.text('test-topic-value'), findsOneWidget);
      expect(
        find.byKey(const Key('diff_base_version_dropdown')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('diff_compare_version_dropdown')),
        findsOneWidget,
      );
    });

    testWidgets('checks compatibility and displays compatible result', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        mockController.fetchSchemaVersions(any, any),
      ).thenAnswer((_) async => [1]);
      when(
        mockController.fetchSchemaContent(any, any, version: 1),
      ).thenAnswer((_) async => '{"type": "string"}');
      when(
        mockController.getAssociatedTopics(any, any),
      ).thenAnswer((_) async => []);
      when(
        mockController.checkCompatibility(
          any,
          any,
          version: anyNamed('version'),
          schema: anyNamed('schema'),
        ),
      ).thenAnswer(
        (_) async => const api.SchemaCompatibilityResult(
          isCompatible: true,
          messages: [],
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          SchemaDiffDialog(
            profile: testProfile,
            subject: 'test-topic-value',
            controller: mockController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Check Compatibility tab
      await tester.tap(find.text('Check Compatibility'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('run_compatibility_check_button')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('run_compatibility_check_button')));
      await tester.pumpAndSettle();

      expect(find.text('Compatible'), findsOneWidget);
    });

    testWidgets('displays associated topics in tab', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        mockController.fetchSchemaVersions(any, any),
      ).thenAnswer((_) async => [1]);
      when(
        mockController.fetchSchemaContent(any, any, version: 1),
      ).thenAnswer((_) async => '{}');
      when(
        mockController.getAssociatedTopics(any, any),
      ).thenAnswer((_) async => ['orders-topic', 'orders-dlq']);

      await tester.pumpWidget(
        createTestApp(
          SchemaDiffDialog(
            profile: testProfile,
            subject: 'orders-topic-value',
            controller: mockController,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Associated Topics tab
      await tester.tap(find.text('Associated Topics'));
      await tester.pumpAndSettle();

      expect(find.text('orders-topic'), findsOneWidget);
      expect(find.text('orders-dlq'), findsOneWidget);
    });
  });

  group('TopicSchemaInspectorView integration', () {
    late MockSchemaController mockController;
    final testProfile = ClusterProfile(
      name: 'test-cluster',
      bootstrapServers: 'localhost:9092',
      schemaRegistryUrl: 'http://localhost:8081',
      securityProtocol: 'plaintext',
      mechanism: 'plain',
    );

    setUp(() {
      mockController = MockSchemaController();
    });

    testWidgets('shows compare schema button in toolbar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.fetchSchemas(any)).thenAnswer((_) async {});
      when(mockController.getSchemas(any)).thenReturn(['my-topic-value']);
      when(
        mockController.fetchSchemaContent(any, 'my-topic-value'),
      ).thenAnswer((_) async => '{"type": "string"}');

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TopicSchemaInspectorView(
              profile: testProfile,
              topicName: 'my-topic',
              controller: mockController,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('schema_compare_button')), findsOneWidget);
    });
  });
}
