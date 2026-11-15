import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_schemas_view.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../../../../rust/api/rust_mocks.mocks.dart';

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    reset(mockApi);
  });

  final baseline = FieldOccurrence(
    topic: 'a-topic',
    fullPath: 'user.id',
    schemaDef: {'type': 'string'},
  );
  final comp = FieldOccurrence(
    topic: 'b-topic',
    fullPath: 'user.id',
    schemaDef: {'type': 'int', 'doc': 'id'},
  );

  testWidgets('FieldSchemaComparisonsWidget renders differences', (
    tester,
  ) async {
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenAnswer(
      (_) async => const [
        JsonDiffResult(
          entries: [
            JsonDiffEntry(
              path: 'type',
              segments: ['type'],
              kind: JsonDiffKind.changed,
              oldValue: '"string"',
              newValue: '"int"',
            ),
            JsonDiffEntry(
              path: 'doc',
              segments: ['doc'],
              kind: JsonDiffKind.added,
              newValue: '"id"',
            ),
          ],
          total: 2,
          hidden: 0,
          truncated: false,
          invalidSide: null,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithApp(
        FieldSchemaComparisonsWidget(baseline: baseline, comparisons: [comp]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(JsonDiffWidget), findsOneWidget);
    expect(find.text('doc: '), findsOneWidget);
  });

  testWidgets('FieldSchemaComparisonsWidget renders no differences message', (
    tester,
  ) async {
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenAnswer(
      (_) async => const [
        JsonDiffResult(
          entries: [],
          total: 0,
          hidden: 0,
          truncated: false,
          invalidSide: null,
        ),
      ],
    );

    await tester.pumpWidget(
      _wrapWithApp(
        FieldSchemaComparisonsWidget(baseline: baseline, comparisons: [comp]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No differences from baseline.'), findsOneWidget);
    expect(find.byType(JsonDiffWidget), findsNothing);
  });

  testWidgets('FieldSchemaComparisonsWidget renders error on failing call', (
    tester,
  ) async {
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenThrow(StateError('failed'));

    await tester.pumpWidget(
      _wrapWithApp(
        FieldSchemaComparisonsWidget(baseline: baseline, comparisons: [comp]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Error computing diff'), findsOneWidget);
  });

  test(
    'Markdown export formats added, removed, and changed entry paths',
    () async {
      when(
        mockApi.crateApiJsonDiffDiffJsonBatch(
          requests: anyNamed('requests'),
          maxEntries: anyNamed('maxEntries'),
        ),
      ).thenAnswer(
        (_) async => const [
          JsonDiffResult(
            entries: [
              JsonDiffEntry(
                path: 'doc',
                segments: ['doc'],
                kind: JsonDiffKind.added,
                newValue: '"id"',
              ),
              JsonDiffEntry(
                path: 'oldField',
                segments: ['oldField'],
                kind: JsonDiffKind.removed,
                oldValue: '"x"',
              ),
              JsonDiffEntry(
                path: 'type',
                segments: ['type'],
                kind: JsonDiffKind.changed,
                oldValue: '"string"',
                newValue: '"int"',
              ),
            ],
            total: 3,
            hidden: 0,
            truncated: false,
            invalidSide: null,
          ),
        ],
      );

      final md = await generateMarkdownForSchemaField('userId', [
        baseline,
        comp,
      ]);
      expect(md, contains('- 🟢 **Added** `doc`: `"id"`'));
      expect(md, contains('- 🔴 **Removed** `oldField`: `"x"`'));
      expect(md, contains('- 🟡 **Changed** `type`: `"string"`  ➔  `"int"`'));
    },
  );
}
