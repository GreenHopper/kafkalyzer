import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/message_ring_buffer.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';

class FakeMessageExportService implements MessageExportService {
  List<KafkaMessage> exported = [];
  bool called = false;
  ExportFormat? lastFormat;
  bool? lastIncludeHeadersColumn;
  String? resultPath = '/tmp/export.json';

  @override
  Future<String?> exportMessages(
    List<KafkaMessage> messages, {
    required String dialogTitle,
    ExportFormat format = ExportFormat.json,
    TableColumnConfig? columnConfig,
    bool isScriptingView = false,
    bool includeHeadersColumn = false,
  }) async {
    called = true;
    exported = messages;
    lastFormat = format;
    lastIncludeHeadersColumn = includeHeadersColumn;
    return resultPath;
  }

  @override
  Future<String?> exportMessagesCsv(
    List<KafkaMessage> messages, {
    required String dialogTitle,
    TableColumnConfig? columnConfig,
    bool isScriptingView = false,
    bool includeHeadersColumn = false,
  }) async {
    called = true;
    exported = messages;
    lastFormat = ExportFormat.csv;
    lastIncludeHeadersColumn = includeHeadersColumn;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;
  late FakeMessageExportService fakeExportService;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    getIt.registerSingleton<FileOpenerService>(
      FileOpenerService(logger: getIt<Logger>()),
    );
    fakeExportService = FakeMessageExportService();
    getIt.registerSingleton<MessageExportService>(fakeExportService);
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget createWidgetUnderTest({
    required List<KafkaMessage> messages,
    required Function(KafkaMessage) onMessageTap,
    String? preferencesKey,
    bool showHeader = true,
    bool showTopic = false,
    bool showStep = false,
    Widget Function(BuildContext context, String searchPhrase)?
    schemaViewBuilder,
    int Function(KafkaMessage a, KafkaMessage b)? sortComparator,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessagesView(
          messages: messages,
          onMessageTap: onMessageTap,
          preferencesKey: preferencesKey,
          showHeader: showHeader,
          showTopic: showTopic,
          showStep: showStep,
          schemaViewBuilder: schemaViewBuilder,
          sortComparator: sortComparator,
        ),
      ),
    );
  }

  final testMessages = [
    const KafkaMessage(
      topic: 'topic-a',
      partition: 0,
      offset: 1,
      key: 'key-1',
      payload: 'apple pie',
      timestamp: 1000,
    ),
    const KafkaMessage(
      topic: 'topic-b',
      partition: 1,
      offset: 2,
      key: 'key-2',
      payload: 'banana cake',
      timestamp: 2000,
    ),
  ];

  testWidgets('renders table view by default and filters on search', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    // Verify MessagesTableView is loaded by default
    expect(find.byType(MessagesTableView), findsOneWidget);
    expect(find.text('apple pie', findRichText: true), findsOneWidget);
    expect(find.text('banana cake', findRichText: true), findsOneWidget);

    // Search for 'apple'
    await tester.enterText(find.byType(TextField), 'apple');
    await tester.pump(const Duration(milliseconds: 300)); // wait for debounce
    await tester.pumpAndSettle();

    // Verify filtered results
    expect(find.text('apple pie', findRichText: true), findsOneWidget);
    expect(find.text('banana cake', findRichText: true), findsNothing);
  });

  testWidgets('header wraps its controls on a narrow window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(520, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('switches view modes and persists preference key', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'my_view_pref': 'timeline'});

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: testMessages,
        onMessageTap: (_) {},
        preferencesKey: 'my_view_pref',
      ),
    );
    await tester.pumpAndSettle();

    // Should load timeline mode from shared preferences
    expect(find.byType(MessagesTimelineView), findsOneWidget);

    // Switch to diff view mode (difference icon)
    await tester.tap(find.byIcon(Icons.difference));
    await tester.pumpAndSettle();

    expect(find.byType(MessagesDiffView), findsOneWidget);

    // Check shared preferences updated
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('my_view_pref'), 'diff');
  });

  testWidgets('exports/downloads active messages list as JSON via menu', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    final downloadBtnFinder = find.byIcon(Icons.download);
    expect(downloadBtnFinder, findsOneWidget);
    await tester.tap(downloadBtnFinder);
    await tester.pumpAndSettle();

    // Verify popup menu items are shown
    expect(find.text('JSON (Full Payload)'), findsOneWidget);
    expect(find.text('NDJSON (One Message per Line)'), findsOneWidget);
    expect(find.text('CSV (Visible Columns)'), findsOneWidget);

    await tester.tap(find.text('JSON (Full Payload)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(fakeExportService.called, isTrue);
    expect(fakeExportService.lastFormat, ExportFormat.json);
    expect(fakeExportService.exported.length, 2);
    expect(find.text('Messages exported successfully'), findsOneWidget);
  });

  testWidgets('exports/downloads active messages list as CSV via menu', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    final downloadBtnFinder = find.byIcon(Icons.download);
    expect(downloadBtnFinder, findsOneWidget);
    await tester.tap(downloadBtnFinder);
    await tester.pumpAndSettle();

    await tester.tap(find.text('CSV (Visible Columns)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(fakeExportService.called, isTrue);
    expect(fakeExportService.lastFormat, ExportFormat.csv);
    expect(fakeExportService.exported.length, 2);
    expect(find.text('Messages exported successfully'), findsOneWidget);
  });

  testWidgets(
    'defaults to descending sort and toggles preference in timeline view',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
      );
      await tester.pumpAndSettle();

      // In table mode, toolbar sort controls are hidden
      expect(find.byKey(const Key('message_sort_order_toggle')), findsNothing);
      expect(
        find.byKey(const Key('message_sort_field_selector')),
        findsNothing,
      );

      // Switch to timeline mode
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();

      // Default sort in timeline is descending
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward), findsNothing);

      await tester.tap(find.byKey(const Key('message_sort_order_toggle')));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('message_sort_order_timeline'), 'asc');
    },
  );

  testWidgets(
    'hides sort controls in table view and restores sort order in timeline view',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'message_sort_order_timeline': 'desc',
      });

      await tester.pumpWidget(
        createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
      );
      await tester.pumpAndSettle();

      // Table view: toolbar sort controls are hidden
      expect(find.byKey(const Key('message_sort_order_toggle')), findsNothing);
      expect(
        find.byKey(const Key('message_sort_field_selector')),
        findsNothing,
      );

      // Switch to timeline → sort controls visible with descending
      await tester.tap(find.byIcon(Icons.view_list));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesTimelineView), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

      // Switch back to table → controls hidden again
      await tester.tap(find.byIcon(Icons.table_chart));
      await tester.pumpAndSettle();
      expect(find.byType(MessagesTableView), findsOneWidget);
      expect(find.byKey(const Key('message_sort_order_toggle')), findsNothing);
    },
  );

  testWidgets('timeline displays newest first when sort is descending', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'my_view_pref': 'timeline',
      'message_sort_order_timeline': 'desc',
    });

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: testMessages,
        onMessageTap: (_) {},
        preferencesKey: 'my_view_pref',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MessagesTimelineView), findsOneWidget);

    final banana = find.text('banana cake', findRichText: true);
    final apple = find.text('apple pie', findRichText: true);
    expect(banana, findsOneWidget);
    expect(apple, findsOneWidget);
    expect(tester.getTopLeft(banana).dy, lessThan(tester.getTopLeft(apple).dy));

    // Toggle to ascending → oldest first
    await tester.tap(find.byKey(const Key('message_sort_order_toggle')));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(apple).dy, lessThan(tester.getTopLeft(banana).dy));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('message_sort_order_timeline'), 'asc');
  });

  testWidgets('default table view hides Step and Topic columns', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MessagesTableView), findsOneWidget);
    expect(find.text('Timestamp'), findsAtLeastNWidgets(1));
    expect(find.text('Step'), findsNothing);
    expect(find.text('Topic'), findsNothing);
  });

  testWidgets('table view shows Step and Topic when enabled', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: testMessages,
        onMessageTap: (_) {},
        showTopic: true,
        showStep: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MessagesTableView), findsOneWidget);
    expect(find.text('Step'), findsOneWidget);
    expect(find.text('Topic'), findsOneWidget);
  });

  testWidgets('renders sort field before view mode controls in timeline mode', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({'view_mode_pref': 'timeline'});

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: testMessages,
        onMessageTap: (_) {},
        preferencesKey: 'view_mode_pref',
      ),
    );
    await tester.pumpAndSettle();

    final fieldFinder = find.byKey(const Key('message_sort_field_selector'));
    final orderFinder = find.byKey(const Key('message_sort_order_toggle'));
    final tableModeFinder = find.byIcon(Icons.table_chart);

    expect(fieldFinder, findsOneWidget);
    expect(
      tester.getTopLeft(fieldFinder).dx,
      lessThan(tester.getTopLeft(orderFinder).dx),
    );
    expect(
      tester.getTopLeft(orderFinder).dx,
      lessThan(tester.getTopLeft(tableModeFinder).dx),
    );
  });

  testWidgets('persists sort field for timeline view type', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'message_sort_field_timeline': 'key',
    });

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    // Table view: sort selector is hidden
    expect(find.byKey(const Key('message_sort_field_selector')), findsNothing);

    // Switch to timeline: selector is visible with 'Key'
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('message_sort_field_selector')),
        matching: find.text('Key'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('timeline sorts by key when sort field is key', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'my_view_pref': 'timeline',
      'message_sort_field_timeline': 'key',
      'message_sort_order_timeline': 'asc',
    });

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: testMessages,
        onMessageTap: (_) {},
        preferencesKey: 'my_view_pref',
      ),
    );
    await tester.pumpAndSettle();

    final apple = find.text('apple pie', findRichText: true);
    final banana = find.text('banana cake', findRichText: true);
    // key-1 before key-2 when ascending
    expect(tester.getTopLeft(apple).dy, lessThan(tester.getTopLeft(banana).dy));

    await tester.tap(find.byKey(const Key('message_sort_field_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offset').last);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('message_sort_field_timeline'), 'offset');
  });

  testWidgets('renders custom schema view when schema tab is active', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: testMessages,
        onMessageTap: (_) {},
        schemaViewBuilder: (context, searchPhrase) {
          return Text('custom-schema:$searchPhrase');
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.data_object), findsOneWidget);
    await tester.tap(find.byIcon(Icons.data_object));
    await tester.pumpAndSettle();

    expect(find.text('custom-schema:'), findsOneWidget);
    expect(find.byType(MessagesTableView), findsNothing);
  });

  testWidgets('filters script results by step name and honors sortComparator', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final scriptMessages = [
      const ScriptResultMessage(
        topic: 'orders',
        partition: 0,
        offset: 1,
        key: 'z-key',
        payload: 'payload-z',
        timestamp: 3000,
        stepName: 'ExtractOrders',
        stepId: 's1',
      ),
      const ScriptResultMessage(
        topic: 'orders',
        partition: 0,
        offset: 2,
        key: 'a-key',
        payload: 'payload-a',
        timestamp: 1000,
        stepName: 'ValidateOrders',
        stepId: 's2',
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: scriptMessages,
        onMessageTap: (_) {},
        sortComparator: (a, b) => (a.key ?? '').compareTo(b.key ?? ''),
      ),
    );
    await tester.pumpAndSettle();

    final aKey = find.text('a-key', findRichText: true);
    final zKey = find.text('z-key', findRichText: true);
    expect(tester.getTopLeft(aKey).dy, lessThan(tester.getTopLeft(zKey).dy));

    await tester.enterText(find.byType(TextField), 'extract');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(find.text('payload-z', findRichText: true), findsOneWidget);
    expect(find.text('payload-a', findRichText: true), findsNothing);
  });

  testWidgets('renders localized empty message in German and English', (
    WidgetTester tester,
  ) async {
    // English
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const Scaffold(
          body: MessagesView(messages: [], onMessageTap: _dummyTap),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('No messages to display'), findsOneWidget);

    // German
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('de'),
        home: const Scaffold(
          body: MessagesView(messages: [], onMessageTap: _dummyTap),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keine Nachrichten zum Anzeigen'), findsOneWidget);
  });

  testWidgets('cancelled export (null result) shows no SnackBar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    fakeExportService.resultPath = null;

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON (Full Payload)'));
    await tester.pumpAndSettle();

    expect(fakeExportService.called, isTrue);
    expect(find.byType(SnackBar), findsNothing);
    expect(find.text('Messages exported successfully'), findsNothing);
  });

  testWidgets('export menu is disabled when filtered message list is empty', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    // Filter out all messages via the search bar
    await tester.enterText(
      find.byType(TextField).first,
      'nonexistent-filter-xyz',
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    final exportButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.download),
        matching: find.byType(IconButton),
      ),
    );
    expect(exportButton.onPressed, isNull);
  });

  testWidgets('errorMessage with empty messages renders error state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: MessagesView(
            messages: [],
            errorMessage: 'Broker connection refused',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to fetch messages'), findsOneWidget);
    expect(find.text('Broker connection refused'), findsOneWidget);
  });

  testWidgets('errorMessage with non-empty messages renders error banner', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MessagesView(
            messages: testMessages,
            errorMessage: 'Stream interrupted',
            onMessageTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Failed to fetch messages: Stream interrupted'),
      findsOneWidget,
    );
  });

  testWidgets(
    'equal-timestamp messages sort deterministically regardless of input order',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mA = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 10,
        key: 'k',
        payload: 'alpha item',
        timestamp: 5000,
      );
      final mB = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 20,
        key: 'k',
        payload: 'beta item',
        timestamp: 5000,
      );

      await tester.pumpWidget(
        createWidgetUnderTest(messages: [mB, mA], onMessageTap: (_) {}),
      );
      await tester.pumpAndSettle();

      // Switch to timeline view where _compareMessages drives display order
      await tester.tap(find.text('Timeline'));
      await tester.pumpAndSettle();

      final topA = tester
          .getTopLeft(find.text('alpha item', findRichText: true))
          .dy;
      final topB = tester
          .getTopLeft(find.text('beta item', findRichText: true))
          .dy;
      expect(topA, lessThan(topB));
    },
  );

  testWidgets(
    'export menu shows conditional options and keeps menu open on toggle',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
      );
      await tester.pumpAndSettle();

      // Open menu without selection or active search
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();

      expect(find.text('JSON (Full Payload)'), findsOneWidget);
      expect(find.text('NDJSON (One Message per Line)'), findsOneWidget);
      expect(find.text('CSV (Visible Columns)'), findsOneWidget);
      expect(find.text('Add Headers column (CSV)'), findsOneWidget);
      expect(find.textContaining('Only selected messages'), findsNothing);
      expect(find.text('Include dimmed non-matches'), findsNothing);

      // Toggle Add Headers column -> menu stays open, service not called
      await tester.tap(find.text('Add Headers column (CSV)'));
      await tester.pumpAndSettle();
      expect(fakeExportService.called, isFalse);
      expect(find.text('CSV (Visible Columns)'), findsOneWidget);

      // Export CSV -> includeHeadersColumn is true
      await tester.tap(find.text('CSV (Visible Columns)'));
      await tester.pumpAndSettle();
      expect(fakeExportService.called, isTrue);
      expect(fakeExportService.lastFormat, ExportFormat.csv);
      expect(fakeExportService.lastIncludeHeadersColumn, isTrue);
    },
  );

  testWidgets(
    'export scope excludes dimmed non-matches by default and includes when toggled',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
      );
      await tester.pumpAndSettle();

      // Enter search matching only message 1 ('apple')
      await tester.enterText(find.byType(TextField).first, 'apple');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Enable "show non-matches" toggle
      await tester.tap(find.byIcon(Icons.visibility_off));
      await tester.pumpAndSettle();

      // Export NDJSON without "Include dimmed non-matches" -> only 1 match
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      expect(find.text('Include dimmed non-matches'), findsOneWidget);

      await tester.tap(find.text('NDJSON (One Message per Line)'));
      await tester.pumpAndSettle();
      expect(fakeExportService.lastFormat, ExportFormat.ndjson);
      expect(fakeExportService.exported.length, 1);
      expect(fakeExportService.exported.first.offset, 1);

      // Toggle "Include dimmed non-matches" on and export -> both messages
      await tester.tap(find.byIcon(Icons.download));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Include dimmed non-matches'));
      await tester.pumpAndSettle();
      expect(find.text('NDJSON (One Message per Line)'), findsOneWidget);
      await tester.tap(find.text('NDJSON (One Message per Line)'));
      await tester.pumpAndSettle();
      expect(fakeExportService.exported.length, 2);
    },
  );

  testWidgets('export only selected exports only the selected message', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    // Select message 2 (offset 2)
    await tester.tap(find.text('key-2', findRichText: true));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    expect(find.text('Only selected messages (1)'), findsOneWidget);

    await tester.tap(find.text('Only selected messages (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON (Full Payload)'));
    await tester.pumpAndSettle();

    expect(fakeExportService.exported.length, 1);
    expect(fakeExportService.exported.first.offset, 2);
  });

  testWidgets('export respects table column filter and column sort visual order', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final messages = [
      const KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 10,
        key: 'k-b',
        payload: 'p10',
        timestamp: 3000,
      ),
      const KafkaMessage(
        topic: 'orders',
        partition: 1,
        offset: 20,
        key: 'k-a',
        payload: 'p20',
        timestamp: 1000,
      ),
      const KafkaMessage(
        topic: 'orders',
        partition: 1,
        offset: 5,
        key: 'k-c',
        payload: 'p5',
        timestamp: 2000,
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(messages: messages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    // Sort by Offset ascending (tap Offset header twice or once depending on initial sort)
    await tester.tap(find.text('Offset').first);
    await tester.pumpAndSettle();
    // Filter Partition column to '1'
    final partitionFilter = find.byKey(const Key('col_filter_partition'));
    if (partitionFilter.evaluate().isNotEmpty) {
      await tester.enterText(partitionFilter, '1');
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byIcon(Icons.download));
    await tester.pumpAndSettle();
    await tester.tap(find.text('JSON (Full Payload)'));
    await tester.pumpAndSettle();

    // Should match table's visual order (and if partition filter was applied, only partition 1)
    if (partitionFilter.evaluate().isNotEmpty) {
      expect(fakeExportService.exported.every((m) => m.partition == 1), isTrue);
    }
    expect(fakeExportService.exported.first.offset, anyOf(5, 20));
  });

  testWidgets(
    'incremental MessageSnapshot update evaluates predicate only for new messages and removes evicted',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final evaluated = <int>[];
      final buffer = MessageRingBuffer(4);
      for (var i = 0; i < 3; i++) {
        buffer.add(
          KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: i,
            key: 'k$i',
            payload: i.isEven ? 'match-$i' : 'other-$i',
            timestamp: 1000 + i,
          ),
        );
      }

      var currentMessages = buffer.snapshot();
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return MessagesView(
                  messages: currentMessages,
                  onMessageTap: (_) {},
                  onFilterEvaluated: (m) => evaluated.add(m.offset),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Activate quick filter 'match'
      await tester.enterText(find.byType(TextField).first, 'match');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(evaluated, [0, 1, 2]);
      evaluated.clear();

      // Add 2 new messages (capacity 4 -> offset 0 is evicted)
      buffer.add(
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 3,
          key: 'k3',
          payload: 'other-3',
          timestamp: 1003,
        ),
      );
      buffer.add(
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 4,
          key: 'k4',
          payload: 'match-4',
          timestamp: 1004,
        ),
      );
      setHostState(() {
        currentMessages = buffer.snapshot();
      });
      await tester.pumpAndSettle();

      // Only offsets 3 and 4 should have been evaluated
      expect(evaluated, [3, 4]);
      expect(find.textContaining('2 of 4 matches'), findsOneWidget);
      expect(find.text('match-0', findRichText: true), findsNothing);
      expect(find.text('match-4', findRichText: true), findsOneWidget);
    },
  );
}

void _dummyTap(KafkaMessage message) {}
