import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
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
    'pinning a column adds it to table and persists to SharedPreferences',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final messages = [
        createMessage(
          offset: 1,
          payload:
              '{"customer": {"name": "Alice", "city": "Vienna"}, "amount": 100}',
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(messages));
      await tester.pumpAndSettle();

      // Click on message to open inspector
      await tester.tap(find.text('key-1', findRichText: true));
      await tester.pumpAndSettle();

      // Find the pin button in the virtual JSON tree inside inspector
      final pinButtons = find.byTooltip('Pin as Column');
      expect(pinButtons, findsWidgets);

      // Pin the first node
      await tester.tap(pinButtons.first);
      await tester.pumpAndSettle();

      // Check SnackBar feedback
      expect(find.textContaining('pinned to table'), findsOneWidget);

      // Verify reset columns button appeared in toolbar
      expect(find.text('Reset columns'), findsOneWidget);

      // Check SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('topic_columns_preset_test-orders');
      expect(saved, isNotNull);
      expect(saved, contains('customer'));

      // Test Reset columns
      await tester.tap(find.text('Reset columns'));
      await tester.pumpAndSettle();

      final savedAfterReset = prefs.getString(
        'topic_columns_preset_test-orders',
      );
      expect(savedAfterReset, isNull);
    },
  );
}
