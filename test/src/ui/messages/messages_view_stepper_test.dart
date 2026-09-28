import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_inspector_panel.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';

class FakeMessageExportService implements MessageExportService {
  @override
  Future<void> exportMessages(List<KafkaMessage> messages) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final getIt = GetIt.instance;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<MessageExportService>(FakeMessageExportService());
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
  });

  final testMessages = [
    const KafkaMessage(
      topic: 'orders-topic',
      partition: 0,
      offset: 100,
      key: 'order-100',
      payload: '{"item":"alpha","qty":1}',
      timestamp: 1695888000000,
    ),
    const KafkaMessage(
      topic: 'orders-topic',
      partition: 0,
      offset: 101,
      key: 'order-101',
      payload: '{"item":"beta","qty":2}',
      timestamp: 1695888005000,
    ),
    const KafkaMessage(
      topic: 'orders-topic',
      partition: 0,
      offset: 102,
      key: 'order-102',
      payload: '{"item":"gamma","qty":3}',
      timestamp: 1695888010000,
    ),
  ];

  Widget createWidgetUnderTest({
    List<KafkaMessage>? messages,
    Function(KafkaMessage)? onMessageTap,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessagesView(
          messages: messages ?? testMessages,
          onMessageTap: onMessageTap,
        ),
      ),
    );
  }

  testWidgets(
    'stepping next and previous via buttons updates inspector selection',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Select middle message (index 1: order-101)
      await tester.tap(find.text('order-101', findRichText: true).first);
      await tester.pumpAndSettle();

      expect(find.textContaining('order-101'), findsWidgets);
      expect(find.text('2 of 3'), findsOneWidget);

      final prevButton = find.widgetWithIcon(IconButton, Icons.chevron_left);
      final nextButton = find.widgetWithIcon(IconButton, Icons.chevron_right);
      expect(prevButton, findsOneWidget);
      expect(nextButton, findsOneWidget);

      // Messages are sorted descending by timestamp:
      // Index 0: order-102, Index 1: order-101, Index 2: order-100
      // Tap previous -> moves to index 0 (order-102)
      await tester.tap(prevButton);
      await tester.pumpAndSettle();

      expect(find.textContaining('order-102'), findsWidgets);
      expect(find.text('1 of 3'), findsOneWidget);

      // At index 0, previous is disabled
      final prevWidget = tester.widget<IconButton>(prevButton);
      expect(prevWidget.onPressed, isNull);

      // Tap next -> moves back to index 1 (order-101)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      expect(find.text('2 of 3'), findsOneWidget);

      // Tap next again -> moves to index 2 (order-100)
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
      expect(find.textContaining('order-100'), findsWidgets);
      expect(find.text('3 of 3'), findsOneWidget);

      // At index 2, next is disabled
      final nextWidget = tester.widget<IconButton>(nextButton);
      expect(nextWidget.onPressed, isNull);
    },
  );

  testWidgets('keyboard shortcuts J and K step next and previous', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Select index 0 (order-102, newest timestamp)
    await tester.tap(find.text('order-102', findRichText: true).first);
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);

    // Press 'J' -> steps to index 1 (order-101)
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.textContaining('order-101'), findsWidgets);

    // Press 'J' again -> steps to index 2 (order-100)
    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.textContaining('order-100'), findsWidgets);

    // Press 'K' -> steps back to index 1 (order-101)
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.textContaining('order-101'), findsWidgets);

    // Arrow keys also step
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('Focus Mode maximizes inspector and Escape minimizes/closes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Select order-100
    await tester.tap(find.text('order-100', findRichText: true).first);
    await tester.pumpAndSettle();

    // Master table and inspector both exist initially
    expect(find.byType(MessagesTableView), findsOneWidget);
    expect(find.byType(MessageInspectorPanel), findsOneWidget);

    // Toggle maximize via button
    final maxButton = find.byTooltip('Maximize (Focus Mode)');
    expect(maxButton, findsOneWidget);
    await tester.tap(maxButton);
    await tester.pumpAndSettle();

    // In Focus Mode, master view is not rendered
    expect(find.byType(MessagesTableView), findsNothing);
    expect(find.byType(MessageInspectorPanel), findsOneWidget);
    expect(find.byTooltip('Minimize (Esc)'), findsOneWidget);

    // Press Escape once -> restores split mode
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(MessagesTableView), findsOneWidget);
    expect(find.byType(MessageInspectorPanel), findsOneWidget);

    // Press Escape again -> closes inspector
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(MessageInspectorPanel), findsNothing);
    expect(find.byType(MessagesTableView), findsOneWidget);
  });

  testWidgets('keyF toggles maximize mode', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.text('order-100', findRichText: true).first);
    await tester.pumpAndSettle();

    expect(find.byType(MessagesTableView), findsOneWidget);

    // Press 'F' -> maximizes
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.byType(MessagesTableView), findsNothing);

    // Press 'F' again -> restores
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(find.byType(MessagesTableView), findsOneWidget);
  });

  testWidgets('typing J, K, F into a text field does not trigger navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Select order-101 (index 1)
    await tester.tap(find.text('order-101', findRichText: true).first);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);

    // Focus on the top search bar TextField
    final searchField = find.byType(TextField).first;
    await tester.tap(searchField);
    await tester.pumpAndSettle();

    // Enter text containing 'j', 'k', 'f'
    await tester.enterText(searchField, 'jkf');
    await tester.pumpAndSettle();

    // Inspector selection should NOT have changed (still index 1: '2 of 3')
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.textContaining('order-101'), findsWidgets);
    // Should NOT have maximized
    expect(find.byType(MessagesTableView), findsOneWidget);
  });
}
