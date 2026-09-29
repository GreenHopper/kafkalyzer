import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';
import 'package:kafkalyzer/src/ui/messages/messages_view.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  KafkaMessage createMessage({
    required int offset,
    required String payload,
    String topic = 'test-orders',
  }) {
    return KafkaMessage(
      topic: topic,
      partition: 0,
      offset: offset,
      timestamp: 1600000000000 + offset * 1000,
      key: 'key-$offset',
      payload: payload,
      headers: const [],
    );
  }

  Widget createWidgetUnderTest(List<KafkaMessage> messages) {
    return MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(body: MessagesView(messages: messages)),
    );
  }

  testWidgets(
    'toggling column visibility via columns menu updates table and persists to SharedPreferences',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final messages = [
        createMessage(
          offset: 1,
          payload: '{"customer": {"name": "Alice"}, "amount": 100}',
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(messages));
      await tester.pumpAndSettle();

      // Open columns configuration menu
      final menuBtn = find.byKey(const Key('table_columns_menu_button'));
      expect(menuBtn, findsOneWidget);
      await tester.tap(menuBtn);
      await tester.pumpAndSettle();

      // Expect to see menu items for standard columns
      final partitionFinder = find.widgetWithText(MenuItemButton, 'Partition');
      expect(partitionFinder, findsOneWidget);

      // Toggle off Partition
      await tester.tap(partitionFinder);
      await tester.pumpAndSettle();

      // Check SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString('topic_columns_preset_test-orders');
      expect(savedJson, isNotNull);
      final decoded = jsonDecode(savedJson!) as Map<String, dynamic>;
      final config = TableColumnConfig.fromJson(decoded);
      expect(config.hiddenColumns, contains('partition'));

      // Check that "Reset columns" button is visible
      final resetBtn = find.text('Reset columns');
      expect(resetBtn, findsOneWidget);

      // Tap Reset columns
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      final savedAfterReset = prefs.getString(
        'topic_columns_preset_test-orders',
      );
      expect(savedAfterReset, isNull);
    },
  );
}
