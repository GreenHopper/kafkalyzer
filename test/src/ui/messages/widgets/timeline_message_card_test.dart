import 'package:material_ui/material_ui.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';
import 'package:kafkalyzer/src/ui/tombstone_widget.dart';

void main() {
  Widget createWidgetUnderTest({
    required KafkaMessage message,
    required VoidCallback onTap,
    String? searchPhrase,
    Widget? customContent,
    List<MapEntry<String, String>>? extractedValues,
    bool showPayloadPreview = true,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: TimelineMessageCard(
          message: message,
          onTap: onTap,
          searchPhrase: searchPhrase,
          customContent: customContent,
          extractedValues: extractedValues,
          showPayloadPreview: showPayloadPreview,
        ),
      ),
    );
  }

  bool findTextInRichText(Widget widget, String text) {
    if (widget is RichText) {
      final plainText = widget.text.toPlainText();
      return plainText.contains(text);
    }
    return false;
  }

  testWidgets('renders key, payload and responds to tap', (
    WidgetTester tester,
  ) async {
    bool tapped = false;
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-message-key',
      payload: 'this is a secret message payload text',
      timestamp: 1234567,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(message: msg, onTap: () => tapped = true),
    );

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'my-message-key')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) => findTextInRichText(w, 'this is a secret message payload text'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(Card));
    expect(tapped, isTrue);
  });

  testWidgets('renders extracted values if present', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      timestamp: 1234567,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        message: msg,
        onTap: () {},
        extractedValues: [
          const MapEntry('username', 'bob'),
          const MapEntry('action', 'login'),
        ],
      ),
    );

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'username: bob')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'action: login')),
      findsOneWidget,
    );
  });

  testWidgets('renders customContent instead of payload preview', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-key',
      payload: 'ignored payload',
      timestamp: 1234567,
    );

    await tester.pumpWidget(
      createWidgetUnderTest(
        message: msg,
        onTap: () {},
        customContent: const Text('CUSTOM CONTENT SHOWN'),
      ),
    );

    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'my-key')),
      findsOneWidget,
    );
    expect(find.text('CUSTOM CONTENT SHOWN'), findsOneWidget);
    expect(
      find.byWidgetPredicate((w) => findTextInRichText(w, 'ignored payload')),
      findsNothing,
    );
  });

  testWidgets('renders TombstoneWidget when payload is null', (
    WidgetTester tester,
  ) async {
    const msg = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      key: 'my-key',
      payload: null,
      timestamp: 1234567,
    );

    await tester.pumpWidget(createWidgetUnderTest(message: msg, onTap: () {}));

    expect(find.byType(TombstoneWidget), findsOneWidget);
  });
}
