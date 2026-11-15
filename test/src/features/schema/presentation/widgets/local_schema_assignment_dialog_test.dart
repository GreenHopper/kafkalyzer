import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/local_schema_assignment_dialog.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart';
import 'package:kafkalyzer/src/services/local_schema_assignment_service.dart';
import 'package:material_ui/material_ui.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('LocalSchemaAssignmentDialog', () {
    testWidgets('Avro preview enables Save and saves assignment', (
      tester,
    ) async {
      LocalSchemaAssignmentDto? saved;
      await tester.pumpWidget(
        _wrap(
          LocalSchemaAssignmentDialog(
            side: LocalSchemaSide.value,
            onSave: (a) async => saved = a,
            onRemove: () async {},
            pickFileFn: () async => '/tmp/order.avsc',
            inspectLocalSchemaFn:
                ({required path, format, messageType}) async =>
                    const LocalSchemaInfo(
                      fileName: 'order.avsc',
                      detectedFormat: LocalSchemaFormatDto.avro,
                      sha256Hex: 'sha-avro',
                      messageTypes: [],
                      fields: SchemaFieldModelDto(
                        kind: SchemaKindDto.avro,
                        messages: [],
                        fields: [
                          SchemaFieldEntryDto(
                            path: 'orderId',
                            name: 'orderId',
                            depth: 0,
                            typeLabel: 'string',
                            optional: false,
                            repeated: false,
                          ),
                        ],
                        truncated: false,
                      ),
                    ),
          ),
        ),
      );

      // Initially Save is disabled
      final saveFinder = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(saveFinder).onPressed, isNull);

      await tester.tap(find.text('Choose file…'));
      await tester.pumpAndSettle();

      expect(find.text('order.avsc'), findsOneWidget);
      expect(find.text('orderId'), findsOneWidget);
      expect(tester.widget<FilledButton>(saveFinder).onPressed, isNotNull);

      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(saved!.path, '/tmp/order.avsc');
      expect(saved!.format, LocalSchemaFormatDto.avro);
      expect(saved!.expectedSha256, 'sha-avro');
    });

    testWidgets(
      'Protobuf with two message types disables Save until one is chosen',
      (tester) async {
        LocalSchemaAssignmentDto? saved;
        await tester.pumpWidget(
          _wrap(
            LocalSchemaAssignmentDialog(
              side: LocalSchemaSide.value,
              onSave: (a) async => saved = a,
              onRemove: () async {},
              pickFileFn: () async => '/tmp/multi.proto',
              inspectLocalSchemaFn:
                  ({required path, format, messageType}) async {
                    final fields = messageType == 'Event'
                        ? const [
                            SchemaFieldEntryDto(
                              path: 'event_id',
                              name: 'event_id',
                              depth: 0,
                              typeLabel: 'string',
                              optional: false,
                              repeated: false,
                            ),
                          ]
                        : const <SchemaFieldEntryDto>[];
                    return LocalSchemaInfo(
                      fileName: 'multi.proto',
                      detectedFormat: LocalSchemaFormatDto.protobufSource,
                      sha256Hex: 'sha-proto',
                      messageTypes: const ['Order', 'Event'],
                      selectedMessage: messageType,
                      fields: SchemaFieldModelDto(
                        kind: SchemaKindDto.protobuf,
                        messages: const ['Order', 'Event'],
                        fields: fields,
                        truncated: false,
                      ),
                    );
                  },
            ),
          ),
        );

        await tester.tap(find.text('Choose file…'));
        await tester.pumpAndSettle();

        final saveFinder = find.widgetWithText(FilledButton, 'Save');
        expect(tester.widget<FilledButton>(saveFinder).onPressed, isNull);

        await tester.tap(find.text('Select a message type'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Event').last);
        await tester.pumpAndSettle();

        expect(find.text('event_id'), findsOneWidget);
        expect(tester.widget<FilledButton>(saveFinder).onPressed, isNotNull);

        await tester.tap(saveFinder);
        await tester.pumpAndSettle();
        expect(saved?.messageType, 'Event');
      },
    );

    testWidgets('proto2 source shows error and descriptor-set hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          LocalSchemaAssignmentDialog(
            side: LocalSchemaSide.key,
            onSave: (_) async {},
            onRemove: () async {},
            pickFileFn: () async => '/tmp/legacy.proto',
            inspectLocalSchemaFn:
                ({required path, format, messageType}) async =>
                    const LocalSchemaInfo(
                      fileName: 'legacy.proto',
                      detectedFormat: LocalSchemaFormatDto.protobufSource,
                      messageTypes: [],
                      error: LocalSchemaErrorDto(
                        kind: LocalDecodeErrorKindDto.unsupportedProto2,
                        detail: 'syntax = "proto2"',
                      ),
                    ),
          ),
        ),
      );

      await tester.tap(find.text('Choose file…'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Proto2 source files are not supported directly'),
        findsOneWidget,
      );
      expect(
        find.textContaining('protoc --include_imports --descriptor_set_out'),
        findsOneWidget,
      );
      final saveFinder = find.widgetWithText(FilledButton, 'Save');
      expect(tester.widget<FilledButton>(saveFinder).onPressed, isNull);
    });

    testWidgets('picker cancel leaves existing assignment unchanged', (
      tester,
    ) async {
      const existing = LocalSchemaAssignmentDto(
        path: '/tmp/old.avsc',
        format: LocalSchemaFormatDto.avro,
        framing: FramingDto.auto,
        mode: LocalSchemaModeDto.fallback,
        expectedSha256: 'sha-old',
      );
      await tester.pumpWidget(
        _wrap(
          LocalSchemaAssignmentDialog(
            side: LocalSchemaSide.value,
            existing: existing,
            onSave: (_) async {},
            onRemove: () async {},
            pickFileFn: () async => null,
            inspectLocalSchemaFn:
                ({required path, format, messageType}) async =>
                    const LocalSchemaInfo(
                      fileName: 'old.avsc',
                      detectedFormat: LocalSchemaFormatDto.avro,
                      sha256Hex: 'sha-old',
                      messageTypes: [],
                    ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Choose file…'));
      await tester.pumpAndSettle();

      expect(find.text('old.avsc'), findsOneWidget);
    });

    testWidgets('Remove button calls onRemove when existing is present', (
      tester,
    ) async {
      var removed = false;
      const existing = LocalSchemaAssignmentDto(
        path: '/tmp/old.avsc',
        format: LocalSchemaFormatDto.avro,
        framing: FramingDto.auto,
        mode: LocalSchemaModeDto.fallback,
      );
      await tester.pumpWidget(
        _wrap(
          LocalSchemaAssignmentDialog(
            side: LocalSchemaSide.value,
            existing: existing,
            onSave: (_) async {},
            onRemove: () async => removed = true,
            inspectLocalSchemaFn:
                ({required path, format, messageType}) async =>
                    const LocalSchemaInfo(
                      fileName: 'old.avsc',
                      detectedFormat: LocalSchemaFormatDto.avro,
                      messageTypes: [],
                    ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
    });
  });
}
