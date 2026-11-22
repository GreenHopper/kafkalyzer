import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';
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

/// Stands in for the topic-name port: the dialogs only ask for the names.
class _Names implements TopicNameSource {
  const _Names(this.names);
  final List<String>? names;
  @override
  List<String>? topicNames(ClusterProfile profile) => names;
}

/// The topic list is treated as not loaded unless a test says otherwise.
const _names = _Names(null);

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
      tlsVerification: TlsVerification.enabled,
    );

    setUp(() {
      mockController = _TestMockSchemaController();
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
            topicNames: _names,
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
            topicNames: _names,
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
            topicNames: _names,
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
      tlsVerification: TlsVerification.enabled,
    );

    setUp(() {
      mockController = _TestMockSchemaController();
    });

    testWidgets('shows compare schema button in toolbar', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.fetchSchemas(any)).thenAnswer((_) async {
        return;
      });
      when(mockController.getSchemas(any)).thenReturn(['my-topic-value']);
      when(
        mockController.fetchSubjectSchemaView(any, 'my-topic-value'),
      ).thenAnswer(
        (_) async => const api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'my-topic-value',
            version: 1,
            id: 1,
            schemaType: api.SchemaKindDto.avro,
            schema: '{"type": "string"}',
            references: [],
          ),
          fields: api.SchemaFieldModelDto(
            kind: api.SchemaKindDto.avro,
            messages: [],
            fields: [],
            truncated: false,
          ),
        ),
      );

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

    testWidgets('renders German empty-selection prompt in SchemaDiffDialog', (
      tester,
    ) async {
      final mockController = _TestMockSchemaController();
      when(
        mockController.fetchSchemaVersions(any, any),
      ).thenAnswer((_) async => <int>[1, 2]);
      when(
        mockController.fetchSchemaContent(
          any,
          any,
          version: anyNamed('version'),
        ),
      ).thenThrow(Exception('not loaded'));

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SchemaDiffDialog(
              topicNames: _names,
              profile: testProfile,
              subject: 'test-topic-value',
              controller: mockController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Versionen zum Vergleichen auswählen'), findsOneWidget);
    });

    testWidgets('shows association error with retry in Associated Topics tab', (
      tester,
    ) async {
      final mockController = _TestMockSchemaController();
      when(
        mockController.fetchSchemaVersions(any, any),
      ).thenAnswer((_) async => <int>[1]);
      when(
        mockController.fetchSchemaContent(
          any,
          any,
          version: anyNamed('version'),
        ),
      ).thenAnswer((_) async => '{"type": "string"}');

      var calls = 0;
      when(mockController.getAssociatedTopics(any, any)).thenAnswer((_) async {
        calls++;
        if (calls == 1) {
          throw Exception('Association failed');
        }
        return ['orders'];
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SchemaDiffDialog(
              topicNames: _names,
              profile: testProfile,
              subject: 'orders-value',
              controller: mockController,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Associated Topics'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Association failed'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('orders'), findsOneWidget);
    });
  });
}

class _TestMockSchemaController extends MockSchemaController {
  @override
  String? errorFor(ClusterProfile? cluster) => null;
}
