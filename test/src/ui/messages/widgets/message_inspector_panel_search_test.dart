import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_inspector_panel.dart';

void main() {
  final testMessage = KafkaMessage(
    topic: 'test-orders',
    partition: 1,
    offset: 1042,
    timestamp: 1695888000000,
    key: 'order-1234',
    payload: '{"orderId":"1234","customer":"1234","status":"CONFIRMED"}',
    headers: [KafkaHeader(key: 'trace-id', value: 'abc-xyz-123')],
  );

  Widget createWidgetUnderTest({
    KafkaMessage? message,
    InspectorDockPosition dockPosition = InspectorDockPosition.bottom,
    VoidCallback? onToggleDockPosition,
    VoidCallback? onClose,
    String? searchPhrase,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessageInspectorPanel(
          message: message ?? testMessage,
          dockPosition: dockPosition,
          onToggleDockPosition: onToggleDockPosition ?? () {},
          onClose: onClose ?? () {},
          searchPhrase: searchPhrase,
        ),
      ),
    );
  }

  testWidgets(
    'toggle search button opens inline search bar and focuses input',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Search bar is initially hidden
      expect(find.text('Search in message...'), findsNothing);

      // Tap search icon in header
      final searchToggle = find.widgetWithIcon(IconButton, Icons.search);
      expect(searchToggle, findsOneWidget);
      await tester.tap(searchToggle);
      await tester.pumpAndSettle();

      // Search bar is now visible
      expect(find.text('Search in message...'), findsOneWidget);

      // Close search button closes it
      final closeSearchButton = find.byTooltip('Close search');
      expect(closeSearchButton, findsOneWidget);
      await tester.tap(closeSearchButton);
      await tester.pumpAndSettle();

      expect(find.text('Search in message...'), findsNothing);
    },
  );

  testWidgets(
    'typing in search bar finds matches, displays counter, and allows next/prev navigation',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Open search
      await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      // Search for "1234" which occurs twice in the payload
      await tester.enterText(searchField, '1234');
      await tester.pumpAndSettle();

      // Matches should be found
      expect(find.text('1 of 2'), findsOneWidget);

      final nextMatchButton = find.byTooltip('Next match (Enter)');
      final prevMatchButton = find.byTooltip('Previous match (Shift+Enter)');
      expect(nextMatchButton, findsOneWidget);
      expect(prevMatchButton, findsOneWidget);

      // Tap next match
      await tester.tap(nextMatchButton);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      // Tap next match again -> wraps to 1
      await tester.tap(nextMatchButton);
      await tester.pumpAndSettle();
      expect(find.text('1 of 2'), findsOneWidget);

      // Tap previous match -> wraps to 2
      await tester.tap(prevMatchButton);
      await tester.pumpAndSettle();
      expect(find.text('2 of 2'), findsOneWidget);

      // Search for non-existent text
      await tester.enterText(searchField, 'nonexistent');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);

      // Clear search via clear icon
      final clearButton = find.widgetWithIcon(IconButton, Icons.clear);
      expect(clearButton, findsOneWidget);
      await tester.tap(clearButton);
      await tester.pumpAndSettle();

      expect(find.text('1 of 2'), findsNothing);
      expect(find.text('No matches'), findsNothing);
    },
  );

  testWidgets('Enter and Shift+Enter cycle through matches', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Open search
    await tester.tap(find.widgetWithIcon(IconButton, Icons.search));
    await tester.pumpAndSettle();

    final searchField = find.byType(TextField);
    await tester.enterText(searchField, '1234');
    await tester.pumpAndSettle();

    expect(find.text('1 of 2'), findsOneWidget);

    // Press Enter -> next match
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);

    // Press Shift+Enter -> previous match
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
  });
}
