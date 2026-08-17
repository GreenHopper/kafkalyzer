import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:google_fonts/google_fonts.dart';

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
  );

  setUp(() {
    mockController = MockSchemaController();
  });

  group('SchemaViewerDialog', () {
    testWidgets('shows loading indicator initially', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['test-topic-key']);
      when(mockController.fetchSchemaContent(any, any)).thenAnswer((_) async {
        await Future.delayed(
          const Duration(milliseconds: 100),
        ); // Delay to force async
        return '{}';
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
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
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text("No Avro schema found for this topic."), findsOneWidget);
    });

    testWidgets('loads and displays key and value schemas', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(
        mockController.getSchemas(any),
      ).thenReturn(['test-topic-key', 'test-topic-value']);
      when(
        mockController.fetchSchemaContent(any, 'test-topic-key'),
      ).thenAnswer((_) async => '{"type": "string"}');
      when(
        mockController.fetchSchemaContent(any, 'test-topic-value'),
      ).thenAnswer((_) async => '{"type": "record", "name": "User"}');

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
            profile: testProfile,
            topicName: 'test-topic',
            controller: mockController,
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text("Key Schema"), findsOneWidget);
      expect(find.text("Value Schema"), findsOneWidget);
      expect(find.byType(JsonOrStringViewer), findsNWidgets(2));
    });

    testWidgets('shows error message on fetch failure', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      when(mockController.getSchemas(any)).thenReturn(['test-topic-key']);
      when(
        mockController.fetchSchemaContent(any, 'test-topic-key'),
      ).thenThrow(Exception('Fetch failed'));

      await tester.pumpWidget(
        MaterialApp(
          home: SchemaViewerDialog(
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
  });
}
