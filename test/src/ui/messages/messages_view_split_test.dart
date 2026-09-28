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
      offset: 101,
      key: 'order-101',
      payload: '{"item":"widget","qty":5}',
      timestamp: 1695888000000,
    ),
    const KafkaMessage(
      topic: 'orders-topic',
      partition: 0,
      offset: 102,
      key: 'order-102',
      payload: '{"item":"gadget","qty":2}',
      timestamp: 1695888005000,
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
    'tapping row opens embedded inspector panel inline without modal dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Inspector is initially closed
      expect(find.byType(MessageInspectorPanel), findsNothing);

      // Tap first message in the table
      await tester.tap(find.text('order-101', findRichText: true).first);
      await tester.pumpAndSettle();

      // Inspector is now open embedded
      expect(find.byType(MessageInspectorPanel), findsOneWidget);
      // Ensure no Dialog was pushed
      expect(find.byType(Dialog), findsNothing);

      // Inspector displays selected message details
      expect(find.textContaining('order-101'), findsWidgets);
      expect(find.text('O: 101'), findsOneWidget);
    },
  );

  testWidgets(
    'toggling dock position switches to side dock and persists in SharedPreferences',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Open inspector
      await tester.tap(find.text('order-101', findRichText: true).first);
      await tester.pumpAndSettle();

      expect(find.byType(MessageInspectorPanel), findsOneWidget);

      // Click dock button to switch to side
      final dockButton = find.byTooltip('Dock to right');
      expect(dockButton, findsOneWidget);
      await tester.tap(dockButton);
      await tester.pumpAndSettle();

      // Verify preference is persisted
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('message_inspector_dock_position'),
        equals('side'),
      );

      // Verify Row layout is used for side dock
      final rowFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Row &&
            widget.children.any(
              (c) => c is Expanded && c.child is MessagesTableView,
            ),
      );
      expect(rowFinder, findsOneWidget);
    },
  );

  testWidgets('closing inspector restores full view', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Open inspector
    await tester.tap(find.text('order-101', findRichText: true).first);
    await tester.pumpAndSettle();
    expect(find.byType(MessageInspectorPanel), findsOneWidget);

    // Click close button
    final closeButton = find.byTooltip('Close inspector');
    expect(closeButton, findsOneWidget);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    // Inspector is closed and table takes full space
    expect(find.byType(MessageInspectorPanel), findsNothing);
    expect(find.byType(MessagesTableView), findsOneWidget);
  });
}
