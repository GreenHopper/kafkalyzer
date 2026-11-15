import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/topic_schema_inspector_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSchemaRegistryService extends Mock implements SchemaRegistryService {
  @override
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) =>
      super.noSuchMethod(
        Invocation.method(#fetchSubjects, [], {#profile: profile}),
        returnValue: Future.value(<String>[]),
      );
}

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('TopicSchemaInspectorView local schema cards', () {
    const noRegistryProfile = ClusterProfile(
      name: 'local-only',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.enabled,
    );

    const withRegistryProfile = ClusterProfile(
      name: 'with-sr',
      bootstrapServers: 'localhost:9092',
      schemaRegistryUrl: 'http://localhost:8081',
      tlsVerification: TlsVerification.enabled,
    );

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'shows local schema cards and field structure when registry is not configured',
      (tester) async {
        final localService = LocalSchemaAssignmentService(
          prefsProvider: SharedPreferences.getInstance,
          inspectFn: ({required path, format, messageType}) async =>
              const LocalSchemaInfo(
                fileName: 'orders.avsc',
                detectedFormat: LocalSchemaFormatDto.avro,
                sha256Hex: 'sha-1',
                messageTypes: [],
                fields: api.SchemaFieldModelDto(
                  kind: api.SchemaKindDto.avro,
                  messages: [],
                  fields: [
                    api.SchemaFieldEntryDto(
                      path: 'order_id',
                      name: 'order_id',
                      depth: 0,
                      typeLabel: 'string',
                      optional: false,
                      repeated: false,
                    ),
                  ],
                  truncated: false,
                ),
              ),
        );

        await localService.saveSide(
          'local-only',
          'orders',
          LocalSchemaSide.value,
          const LocalSchemaAssignmentDto(
            path: '/tmp/orders.avsc',
            format: LocalSchemaFormatDto.avro,
            framing: FramingDto.auto,
            mode: LocalSchemaModeDto.fallback,
            expectedSha256: 'sha-1',
          ),
        );

        final schemaController = SchemaController(
          registryService: _MockSchemaRegistryService(),
          localSchemaService: localService,
        );

        await tester.pumpWidget(
          _wrap(
            TopicSchemaInspectorView(
              profile: noRegistryProfile,
              topicName: 'orders',
              controller: schemaController,
              localSchemaService: localService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('orders.avsc'), findsOneWidget);
        expect(find.text('Ready'), findsOneWidget);
        expect(find.text('Assign local schema'), findsOneWidget);
        // Field structure rendered via JsonOrStringViewer
        expect(find.textContaining('order_id'), findsOneWidget);
      },
    );

    testWidgets(
      'shows confirm button when file changed and removes on Remove tap',
      (tester) async {
        final localService = LocalSchemaAssignmentService(
          prefsProvider: SharedPreferences.getInstance,
          inspectFn: ({required path, format, messageType}) async =>
              const LocalSchemaInfo(
                fileName: 'orders.avsc',
                detectedFormat: LocalSchemaFormatDto.avro,
                sha256Hex: 'sha-new',
                messageTypes: [],
              ),
        );

        await localService.saveSide(
          'with-sr',
          'orders',
          LocalSchemaSide.value,
          const LocalSchemaAssignmentDto(
            path: '/tmp/orders.avsc',
            format: LocalSchemaFormatDto.avro,
            framing: FramingDto.auto,
            mode: LocalSchemaModeDto.fallback,
            expectedSha256: 'sha-old',
          ),
        );

        final mockRegistry = _MockSchemaRegistryService();
        when(
          mockRegistry.fetchSubjects(profile: withRegistryProfile),
        ).thenAnswer((_) async => []);

        final schemaController = SchemaController(
          registryService: mockRegistry,
          localSchemaService: localService,
        );

        await tester.pumpWidget(
          _wrap(
            TopicSchemaInspectorView(
              profile: withRegistryProfile,
              topicName: 'orders',
              controller: schemaController,
              localSchemaService: localService,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('File modified since assignment'), findsOneWidget);
        expect(find.text('Confirm updated file'), findsOneWidget);

        await tester.tap(find.text('Confirm updated file'));
        await tester.pumpAndSettle();

        expect(find.text('Ready'), findsOneWidget);

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.text('orders.avsc'), findsNothing);
        expect(find.text('Assign local schema'), findsNWidgets(2));
      },
    );
  });
}
