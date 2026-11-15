import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/json_diff.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/diff_ignore_list_service.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../rust/api/rust_mocks.mocks.dart';

void main() {
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    reset(mockApi);
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenAnswer((invocation) async {
      final reqs =
          invocation.namedArguments[#requests] as List<JsonDiffRequest>;
      return List.generate(
        reqs.length,
        (_) => const JsonDiffResult(
          entries: [
            JsonDiffEntry(
              path: 'val',
              segments: ['val'],
              kind: JsonDiffKind.changed,
              oldValue: '10',
              newValue: '20',
            ),
          ],
          total: 1,
          hidden: 0,
          truncated: false,
          invalidSide: null,
        ),
      );
    });
  });
  Widget createWidgetUnderTest({
    required List<KafkaMessage> messages,
    required Function(KafkaMessage) onMessageTap,
    String? searchPhrase,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessagesDiffView(
          messages: messages,
          onMessageTap: onMessageTap,
          searchPhrase: searchPhrase,
        ),
      ),
    );
  }

  testWidgets('renders diff view list and handles lazy diff loading', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool tapped = false;
    final messages = [
      const KafkaMessage(
        topic: 'topic-x',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: '{"val": 10}',
        timestamp: 1000,
      ),
      const KafkaMessage(
        topic: 'topic-x',
        partition: 0,
        offset: 2,
        key: 'k1',
        payload: '{"val": 20}', // Changed JSON value
        timestamp: 2000,
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: messages,
        onMessageTap: (_) => tapped = true,
      ),
    );

    // Verify timeline elements are rendered
    expect(find.text('topic-x'), findsNWidgets(2));

    // The second item should show loading indicator (CircularProgressIndicator) initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Wait for the 250ms lazy loading delay in _LazyDiffViewer
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle(); // Wait for future to resolve

    // Verify JsonDiffWidget is rendered
    expect(find.byType(JsonDiffWidget), findsOneWidget);

    // Tap the card
    await tester.tap(find.byType(JsonDiffWidget));
    expect(tapped, isTrue);
  });

  testWidgets('renders empty screen placeholder if messages list is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWidgetUnderTest(messages: [], onMessageTap: (_) {}),
    );

    expect(find.text('No messages to display'), findsOneWidget);
  });

  testWidgets('renders German empty placeholder when locale is de', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessagesDiffView(messages: const [], onMessageTap: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine Nachrichten zum Anzeigen'), findsOneWidget);
  });

  testWidgets('non-JSON pair never shows "No differences found."', (
    WidgetTester tester,
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
          invalidSide: JsonDiffInvalidSide.new_,
        ),
      ],
    );

    final messages = [
      const KafkaMessage(
        topic: 'topic-x',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: '{"val": 10}',
        timestamp: 1000,
      ),
      const KafkaMessage(
        topic: 'topic-x',
        partition: 0,
        offset: 2,
        key: 'k1',
        payload: 'plain text payload',
        timestamp: 2000,
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(messages: messages, onMessageTap: (_) {}),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('No differences found.'), findsNothing);
    expect(find.text('plain text payload'), findsOneWidget);
  });

  testWidgets('failing batch shows "Error computing diff"', (
    WidgetTester tester,
  ) async {
    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenThrow(StateError('bridge failed'));

    final messages = [
      const KafkaMessage(
        topic: 'topic-x',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: '{"val": 10}',
        timestamp: 1000,
      ),
      const KafkaMessage(
        topic: 'topic-x',
        partition: 0,
        offset: 2,
        key: 'k1',
        payload: '{"val": 20}',
        timestamp: 2000,
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(messages: messages, onMessageTap: (_) {}),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Error computing diff'), findsOneWidget);
  });

  testWidgets(
    'ignore from row context menu hides field, shows Hidden (1), and leaves other topic unaffected',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final ignoreService = DiffIgnoreListService(prefs: prefs);

      when(
        mockApi.crateApiJsonDiffDiffJsonBatch(
          requests: anyNamed('requests'),
          maxEntries: anyNamed('maxEntries'),
        ),
      ).thenAnswer((invocation) async {
        final reqs =
            invocation.namedArguments[#requests] as List<JsonDiffRequest>;
        return reqs.map((r) {
          if (r.ignorePaths.contains('ts')) {
            return const JsonDiffResult(
              entries: [],
              total: 0,
              hidden: 1,
              truncated: false,
              invalidSide: null,
            );
          }
          return const JsonDiffResult(
            entries: [
              JsonDiffEntry(
                path: 'ts',
                segments: ['ts'],
                kind: JsonDiffKind.changed,
                oldValue: '1',
                newValue: '2',
              ),
            ],
            total: 1,
            hidden: 0,
            truncated: false,
            invalidSide: null,
          );
        }).toList();
      });

      final messages = [
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 1,
          key: 'k1',
          payload: '{"ts":1}',
          timestamp: 1000,
        ),
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 2,
          key: 'k1',
          payload: '{"ts":2}',
          timestamp: 2000,
        ),
        const KafkaMessage(
          topic: 'payments',
          partition: 0,
          offset: 1,
          key: 'k1',
          payload: '{"ts":1}',
          timestamp: 1000,
        ),
        const KafkaMessage(
          topic: 'payments',
          partition: 0,
          offset: 2,
          key: 'k1',
          payload: '{"ts":2}',
          timestamp: 2000,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: MessagesDiffView(
              messages: messages,
              onMessageTap: (_) {},
              ignoreListService: ignoreService,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // Header has topic dropdown since there are two topics
      expect(find.byType(DropdownButton<String>), findsOneWidget);
      expect(find.text('Ignored fields (0)'), findsOneWidget);

      // Right-click on the first 'ts: ' row (orders)
      await tester.tap(find.text('ts: ').first, buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ignore this field'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      // orders card now shows No differences found. + Hidden (1), header updated
      expect(find.text('Ignored fields (1)'), findsOneWidget);
      expect(find.text('No differences found.'), findsOneWidget);
      expect(find.text('Hidden (1)'), findsOneWidget);
      // payments card still shows ts:
      expect(find.text('ts: '), findsOneWidget);
    },
  );

  testWidgets('unreadable ignore list shows warning and omits hidden count', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      DiffIgnoreListService.storageKey('orders'): 'corrupted',
    });
    final prefs = await SharedPreferences.getInstance();
    final ignoreService = DiffIgnoreListService(prefs: prefs);

    when(
      mockApi.crateApiJsonDiffDiffJsonBatch(
        requests: anyNamed('requests'),
        maxEntries: anyNamed('maxEntries'),
      ),
    ).thenAnswer(
      (_) async => const [
        JsonDiffResult(
          entries: [],
          total: 2005,
          hidden: 2,
          truncated: true,
          invalidSide: null,
        ),
      ],
    );

    final messages = [
      const KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: '{"a":1}',
        timestamp: 1000,
      ),
      const KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 2,
        key: 'k1',
        payload: '{"a":2}',
        timestamp: 2000,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: MessagesDiffView(
            messages: messages,
            onMessageTap: (_) {},
            ignoreListService: ignoreService,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(
      find.text('Could not read saved ignore list for orders.'),
      findsOneWidget,
    );
    expect(find.text('Hidden (2)'), findsNothing);
    expect(find.text('2005 more differences not shown'), findsOneWidget);
  });

  testWidgets('German locale renders Ausgeblendet (n) for hidden count', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      DiffIgnoreListService.storageKey('orders'): ['ts'],
    });
    final prefs = await SharedPreferences.getInstance();
    final ignoreService = DiffIgnoreListService(prefs: prefs);

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
          hidden: 2,
          truncated: false,
          invalidSide: null,
        ),
      ],
    );

    final messages = [
      const KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: '{"ts":1}',
        timestamp: 1000,
      ),
      const KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 2,
        key: 'k1',
        payload: '{"ts":2}',
        timestamp: 2000,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: Scaffold(
          body: MessagesDiffView(
            messages: messages,
            onMessageTap: (_) {},
            ignoreListService: ignoreService,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('Ausgeblendet (2)'), findsOneWidget);
  });
}
