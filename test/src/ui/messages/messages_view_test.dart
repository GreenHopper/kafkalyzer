import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';

class FakeMessageExportService implements MessageExportService {
  List<KafkaMessage> exported = [];
  bool called = false;

  @override
  Future<void> exportMessages(List<KafkaMessage> messages) async {
    called = true;
    exported = messages;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;
  late FakeMessageExportService fakeExportService;

  setUp(() async {
    await getIt.reset();
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

  testWidgets('exports/downloads active messages list', (
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

    final downloadBtnFinder = find.widgetWithIcon(IconButton, Icons.download);
    expect(downloadBtnFinder, findsOneWidget);
    final iconButton = tester.widget<IconButton>(downloadBtnFinder);
    iconButton.onPressed!();
    await tester.pumpAndSettle();

    expect(fakeExportService.called, isTrue);
    expect(fakeExportService.exported.length, 2);
    expect(find.text('Messages exported successfully'), findsOneWidget);
  });

  testWidgets('defaults to descending sort and toggles preference for active view', (
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

    // Default view is table; default sort is descending
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsNothing);

    await tester.tap(find.byKey(const Key('message_sort_order_toggle')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('message_sort_order_table'), 'asc');
    expect(prefs.getString('message_sort_order_timeline'), isNull);
  });

  testWidgets('restores independent sort orders when switching view types', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'message_sort_order_table': 'asc',
      'message_sort_order_timeline': 'desc',
    });

    await tester.pumpWidget(
      createWidgetUnderTest(messages: testMessages, onMessageTap: (_) {}),
    );
    await tester.pumpAndSettle();

    // Table starts ascending from prefs
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Switch to timeline → descending
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesTimelineView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    // Back to table → ascending restored
    await tester.tap(find.byIcon(Icons.table_chart));
    await tester.pumpAndSettle();
    expect(find.byType(MessagesTableView), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
  });

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
    expect(
      tester.getTopLeft(banana).dy,
      lessThan(tester.getTopLeft(apple).dy),
    );

    // Toggle to ascending → oldest first
    await tester.tap(find.byKey(const Key('message_sort_order_toggle')));
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(apple).dy,
      lessThan(tester.getTopLeft(banana).dy),
    );
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('message_sort_order_timeline'), 'asc');
  });
}
