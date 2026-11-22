import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

@GenerateMocks([SchemaController])
import 'schema_viewer_dialog_test.mocks.dart';

Future<void> awaitIsolates(WidgetTester tester) async {
  await tester.pump();
  int attempts = 0;
  while (tester.any(find.byType(CircularProgressIndicator)) && attempts < 50) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    attempts++;
  }
  await tester.pumpAndSettle();
}

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

  group('SchemaViewerDialog', () {
    testWidgets('shows loading indicator initially', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['test-topic-key']);
      when(
        mockController.fetchSubjectSchemaView(any, 'test-topic-key'),
      ).thenAnswer((_) async {
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Delay to force async
        return const api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'test-topic-key',
            version: 1,
            id: 1,
            schemaType: api.SchemaKindDto.avro,
            schema: '{}',
            references: [],
          ),
          fields: api.SchemaFieldModelDto(
            kind: api.SchemaKindDto.avro,
            messages: [],
            fields: [],
            truncated: false,
          ),
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );

      // Should show loading now because it's awaiting fetchSchemaContent
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Let it finish
      await awaitIsolates(tester);
    });

    testWidgets('shows no schema message when none found', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['other-topic-key']);

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text("No schema found for this topic."), findsOneWidget);
    });

    testWidgets('loads and displays key and value schemas', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        mockController.getSchemas(any),
      ).thenReturn(['test-topic-key', 'test-topic-value']);
      when(
        mockController.fetchSubjectSchemaView(any, 'test-topic-key'),
      ).thenAnswer(
        (_) async => const api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'test-topic-key',
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
      when(
        mockController.fetchSubjectSchemaView(any, 'test-topic-value'),
      ).thenAnswer(
        (_) async => const api.SubjectSchemaViewDto(
          schema: api.SubjectSchemaDto(
            subject: 'test-topic-value',
            version: 1,
            id: 2,
            schemaType: api.SchemaKindDto.avro,
            schema: '{"type": "record", "name": "User", "fields": []}',
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
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text("Key Schema"), findsWidgets);
      expect(find.text("Value Schema"), findsWidgets);
      expect(find.byType(JsonOrStringViewer), findsNWidgets(2));
    });

    testWidgets('shows error message on fetch failure', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['test-topic-key']);
      when(
        mockController.fetchSubjectSchemaView(any, 'test-topic-key'),
      ).thenThrow(Exception('Fetch failed'));

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(
        find.text('Error loading schema: Exception: Fetch failed'),
        findsOneWidget,
      );
    });

    testWidgets('shows search bar', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn([]);

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search...'), findsOneWidget);
    });

    testWidgets('renders German localized titles and empty schema message', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['other-topic-key']);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text('Schema-Viewer'), findsOneWidget);
      expect(
        find.text('Kein Schema für dieses Topic gefunden.'),
        findsOneWidget,
      );
      expect(find.text('Topic: test-topic'), findsOneWidget);
    });

    testWidgets('renders German localized error message on fetch failure', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['test-topic-key']);
      when(
        mockController.fetchSubjectSchemaView(any, 'test-topic-key'),
      ).thenThrow(Exception('Fetch failed'));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('de'),
          home: SchemaViewerDialog(
            topicNames: _names,
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(
        find.text('Fehler beim Laden des Schemas: Exception: Fetch failed'),
        findsOneWidget,
      );
    });

    testWidgets(
      'opens by subject, navigates to existing associated topic, and disables missing topic',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          mockController.fetchSchemaVersions(any, 'orders-value'),
        ).thenAnswer((_) async => [1]);
        when(
          mockController.fetchSubjectSchemaView(
            any,
            'orders-value',
            version: 1,
          ),
        ).thenAnswer(
          (_) async => const api.SubjectSchemaViewDto(
            schema: api.SubjectSchemaDto(
              subject: 'orders-value',
              version: 1,
              id: 10,
              schemaType: api.SchemaKindDto.protobuf,
              schema: 'syntax = "proto3"; message Order {}',
              references: [],
            ),
            fields: api.SchemaFieldModelDto(
              kind: api.SchemaKindDto.protobuf,
              messages: ['Order'],
              fields: [],
              truncated: false,
            ),
          ),
        );
        when(
          mockController.getAssociatedTopics('orders-value', ['orders']),
        ).thenAnswer((_) async => ['orders', 'missing-topic']);

        final navigated = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => SchemaViewerDialog(
                        topicNames: const _Names(['orders']),
                        profile: testProfile,
                        initialSubject: 'orders-value',
                        controller: mockController,
                        onNavigateToTopic: navigated.add,
                      ),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await awaitIsolates(tester);

        expect(find.text('Schema: orders-value'), findsOneWidget);
        expect(find.text('missing-topic (not on cluster)'), findsOneWidget);
        expect(
          find.byKey(const Key('associated_topic_missing_missing-topic')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('associated_topic_open_orders')));
        await tester.pumpAndSettle();

        expect(navigated, ['orders']);
        expect(find.byType(SchemaViewerDialog), findsNothing);
      },
    );

    testWidgets(
      'unknown topic list still lists associated topics and does not claim they are missing',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          mockController.fetchSchemaVersions(any, 'orders-value'),
        ).thenAnswer((_) async => [1]);
        when(
          mockController.fetchSubjectSchemaView(
            any,
            'orders-value',
            version: 1,
          ),
        ).thenAnswer(
          (_) async => const api.SubjectSchemaViewDto(
            schema: api.SubjectSchemaDto(
              subject: 'orders-value',
              version: 1,
              id: 10,
              schemaType: api.SchemaKindDto.protobuf,
              schema: 'syntax = "proto3"; message Order {}',
              references: [],
            ),
            fields: api.SchemaFieldModelDto(
              kind: api.SchemaKindDto.protobuf,
              messages: ['Order'],
              fields: [],
              truncated: false,
            ),
          ),
        );
        when(
          mockController.getAssociatedTopics('orders-value', <String>[]),
        ).thenAnswer((_) async => ['orders', 'missing-topic']);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SchemaViewerDialog(
              topicNames: _names,
              profile: testProfile,
              initialSubject: 'orders-value',
              controller: mockController,
              onNavigateToTopic: (_) {},
            ),
          ),
        );
        await awaitIsolates(tester);

        // Unknown is shown as unknown: the names stay plain chips instead of
        // the "not on cluster" claim an empty list would produce.
        expect(find.text('missing-topic'), findsOneWidget);
        expect(find.textContaining('(not on cluster)'), findsNothing);
        expect(
          find.byKey(const Key('associated_topic_open_orders')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'association failure shows retry and back button works after reference',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        when(
          mockController.fetchSchemaVersions(any, 'orders-value'),
        ).thenAnswer((_) async => [1]);
        when(
          mockController.fetchSubjectSchemaView(
            any,
            'orders-value',
            version: 1,
          ),
        ).thenAnswer(
          (_) async => const api.SubjectSchemaViewDto(
            schema: api.SubjectSchemaDto(
              subject: 'orders-value',
              version: 1,
              id: 1,
              schemaType: api.SchemaKindDto.protobuf,
              schema: 'syntax = "proto3"; message Order {}',
              references: [
                api.SchemaReferenceDto(
                  name: 'common.proto',
                  subject: 'common-proto',
                  version: 2,
                ),
              ],
            ),
            fields: api.SchemaFieldModelDto(
              kind: api.SchemaKindDto.protobuf,
              messages: ['Order'],
              fields: [],
              truncated: false,
            ),
          ),
        );
        when(
          mockController.fetchSchemaVersions(any, 'common-proto'),
        ).thenAnswer((_) async => [2]);
        when(
          mockController.fetchSubjectSchemaView(
            any,
            'common-proto',
            version: 2,
          ),
        ).thenAnswer(
          (_) async => const api.SubjectSchemaViewDto(
            schema: api.SubjectSchemaDto(
              subject: 'common-proto',
              version: 2,
              id: 2,
              schemaType: api.SchemaKindDto.protobuf,
              schema: 'syntax = "proto3"; message Common {}',
              references: [],
            ),
            fields: api.SchemaFieldModelDto(
              kind: api.SchemaKindDto.protobuf,
              messages: ['Common'],
              fields: [],
              truncated: false,
            ),
          ),
        );

        var assocCalls = 0;
        when(mockController.getAssociatedTopics(any, any)).thenAnswer((
          inv,
        ) async {
          assocCalls++;
          if (assocCalls == 1) {
            throw Exception('assoc boom');
          }
          return const ['orders'];
        });

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SchemaViewerDialog(
              topicNames: const _Names(['orders']),
              profile: testProfile,
              initialSubject: 'orders-value',
              controller: mockController,
            ),
          ),
        );
        await awaitIsolates(tester);

        expect(find.textContaining('assoc boom'), findsOneWidget);
        await tester.tap(
          find.byKey(const Key('schema_viewer_retry_associations')),
        );
        await awaitIsolates(tester);
        expect(find.text('orders'), findsOneWidget);

        // Follow reference -> Back button appears -> tap Back
        await tester.tap(find.text('common.proto (common-proto v2)'));
        await awaitIsolates(tester);
        expect(find.text('Schema: common-proto'), findsOneWidget);
        expect(
          find.byKey(const Key('schema_viewer_back_button')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('schema_viewer_back_button')));
        await awaitIsolates(tester);
        expect(find.text('Schema: orders-value'), findsOneWidget);
      },
    );
  });
}

class _TestMockSchemaController extends MockSchemaController {
  @override
  String? errorFor(ClusterProfile? cluster) => null;

  @override
  Object? errorObjectFor(ClusterProfile? cluster) => null;

  @override
  Future<String?> fetchSubjectCompatibility(
    ClusterProfile? cluster,
    String? subject, {
    bool? force = false,
  }) async => null;

  @override
  Future<String> fetchGlobalCompatibility(
    ClusterProfile? cluster, {
    bool? force = false,
  }) async => 'BACKWARD';
}
