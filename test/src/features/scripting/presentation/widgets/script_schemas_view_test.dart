import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/ui/diff/json_diff_widget.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_schemas_view.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart'
    show ClusterProfile, TlsVerification;
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';

import '../../../../rust/api/rust_mocks.mocks.dart';

class _FakeClusterList extends ChangeNotifier implements ClusterListController {
  _FakeClusterList(this._clusters);
  final List<ClusterProfile> _clusters;

  @override
  List<ClusterProfile> get clusters => _clusters;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSchemaController extends ChangeNotifier implements SchemaController {
  _FakeSchemaController({this.contentBySubject = const {}, this.throwFor});

  final Map<String, String> contentBySubject;
  final String? throwFor;

  @override
  Future<String> fetchSchemaContent(
    ClusterProfile cluster,
    String subject, {
    int? version,
  }) async {
    if (throwFor != null && subject.contains(throwFor!)) {
      throw StateError('Schema not found');
    }
    final content = contentBySubject[subject];
    if (content == null) {
      throw StateError('Schema not found');
    }
    return content;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrapWithApp(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _wrapBounded(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
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

  testWidgets('empty association list shows no-schemas message', (
    tester,
  ) async {
    const script = Script(
      id: 's1',
      name: 'Demo',
      steps: [
        ScriptStep(
          id: 'step-1',
          name: 'Step',
          clusterName: 'c1',
          topicNames: ['orders'],
        ),
      ],
    );
    const profile = ClusterProfile(
      name: 'c1',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.enabled,
    );

    await tester.pumpWidget(
      _wrapBounded(
        ScriptSchemasView(
          script: script,
          searchPhrase: '',
          logger: Logger(level: Level.off),
          clusterController: _FakeClusterList(const [profile]),
          schemaController: _FakeSchemaController(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("No schemas found for the current script's topics."),
      findsOneWidget,
    );
  });

  testWidgets('populated schema list shows field cards', (tester) async {
    const script = Script(
      id: 's1',
      name: 'Demo',
      steps: [
        ScriptStep(
          id: 'step-1',
          name: 'Step',
          clusterName: 'c1',
          topicNames: ['orders'],
        ),
      ],
    );
    const profile = ClusterProfile(
      name: 'c1',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.enabled,
    );
    final schemaJson = jsonEncode({
      'type': 'record',
      'name': 'Order',
      'fields': [
        {'name': 'orderId', 'type': 'string'},
        {
          'name': 'items',
          'type': {
            'type': 'array',
            'items': {
              'type': 'record',
              'name': 'Item',
              'fields': [
                {
                  'name': 'sku',
                  'type': <dynamic>['null', 'string'],
                },
              ],
            },
          },
        },
        {
          'name': 'meta',
          'type': {
            'type': 'record',
            'name': 'Meta',
            'fields': [
              {'name': 'source', 'type': 'string'},
            ],
          },
        },
      ],
    });

    await tester.pumpWidget(
      _wrapBounded(
        ScriptSchemasView(
          script: script,
          searchPhrase: '',
          logger: Logger(level: Level.off),
          clusterController: _FakeClusterList(const [profile]),
          schemaController: _FakeSchemaController(
            contentBySubject: {'orders-value': schemaJson},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('orderId'), findsWidgets);

    await tester.tap(find.textContaining('orderId').first);
    await tester.pumpAndSettle();
    expect(find.byType(ExpansionTile), findsWidgets);
    expect(find.textContaining('sku'), findsWidgets);
    expect(find.textContaining('source'), findsWidgets);

    await tester.pumpWidget(
      _wrapBounded(
        ScriptSchemasView(
          script: script,
          searchPhrase: 'nope',
          logger: Logger(level: Level.off),
          clusterController: _FakeClusterList(const [profile]),
          schemaController: _FakeSchemaController(
            contentBySubject: {'orders-value': schemaJson},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No schema fields found matching'),
      findsOneWidget,
    );
  });

  testWidgets('missing schemas stay empty, not a silent success list', (
    tester,
  ) async {
    const script = Script(
      id: 's1',
      name: 'Demo',
      steps: [
        ScriptStep(
          id: 'step-1',
          name: 'Step',
          clusterName: 'c1',
          topicNames: ['missing'],
        ),
      ],
    );
    const profile = ClusterProfile(
      name: 'c1',
      bootstrapServers: 'localhost:9092',
      tlsVerification: TlsVerification.enabled,
    );

    await tester.pumpWidget(
      _wrapBounded(
        ScriptSchemasView(
          script: script,
          searchPhrase: '',
          logger: Logger(level: Level.off),
          clusterController: _FakeClusterList(const [profile]),
          schemaController: _FakeSchemaController(throwFor: 'missing'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("No schemas found for the current script's topics."),
      findsOneWidget,
    );
    expect(find.byType(ExpansionTile), findsNothing);
  });

  test(
    'generateMarkdownForSchemaField handles empty and single occurrence',
    () async {
      final empty = await generateMarkdownForSchemaField('x', []);
      expect(empty, contains('No occurrences found'));

      final single = await generateMarkdownForSchemaField('orderId', [
        FieldOccurrence(
          topic: 'orders',
          fullPath: 'orderId',
          schemaDef: {'name': 'orderId', 'type': 'string'},
        ),
      ]);
      expect(single, contains('Baseline'));
      expect(single, contains('orders'));
      expect(single, isNot(contains('Comparisons')));
    },
  );

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
