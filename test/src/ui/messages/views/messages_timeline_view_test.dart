import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_timeline_view.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/timeline_message_card.dart';

void main() {
  Widget createWidgetUnderTest({
    required List<KafkaMessage> messages,
    required Function(KafkaMessage) onMessageTap,
    String? searchPhrase,
    bool showNonMatches = false,
    Map<String, List<ScriptExtraction>>? stepExtractions,
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
        body: MessagesTimelineView(
          messages: messages,
          onMessageTap: onMessageTap,
          searchPhrase: searchPhrase,
          showNonMatches: showNonMatches,
          stepExtractions: stepExtractions,
        ),
      ),
    );
  }

  testWidgets('renders messages timeline and lazy resolves cards', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool tapped = false;
    final messages = [
      const KafkaMessage(
        topic: 'topic-a',
        partition: 0,
        offset: 10,
        key: 'key-1',
        payload: 'payload-content-1',
        timestamp: 1000,
      ),
    ];

    await tester.pumpWidget(
      createWidgetUnderTest(
        messages: messages,
        onMessageTap: (_) => tapped = true,
      ),
    );

    // Verify metadata card is shown
    expect(find.text('topic-a'), findsOneWidget);

    // TimelineMessageCard should not be rendered before delay
    expect(find.byType(TimelineMessageCard), findsNothing);

    // Wait for the 50ms lazy loading delay in _LazyTimelineCard
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify card is now visible
    expect(find.byType(TimelineMessageCard), findsOneWidget);

    // Tap on it
    await tester.tap(find.byType(TimelineMessageCard));
    expect(tapped, isTrue);
  });

  testWidgets(
    'renders extraction values using ScriptResultMessage and stepExtractions',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final msg = ScriptResultMessage(
        topic: 'topic-a',
        partition: 0,
        offset: 11,
        key: 'key-2',
        payload: '{"user_id": "usr_123"}',
        timestamp: 2000,
        stepId: 'step-a',
        stepName: 'Step Alpha',
      );

      final Map<String, List<ScriptExtraction>> extractions = {
        'step-a': [
          const ScriptExtraction(
            variableName: 'ExtractedUser',
            jsonPath: 'user_id',
          ),
        ],
      };

      await tester.pumpWidget(
        createWidgetUnderTest(
          messages: [msg],
          onMessageTap: (_) {},
          stepExtractions: extractions,
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // The extraction utility should extract "usr_123" and render "ExtractedUser: usr_123"
      // Since it uses RichText inside TimelineMessageCard, check plainText helper
      bool findTextInRichText(Widget widget, String text) {
        if (widget is RichText) {
          final plainText = widget.text.toPlainText();
          return plainText.contains(text);
        }
        return false;
      }

      expect(
        find.byWidgetPredicate(
          (w) => findTextInRichText(w, 'ExtractedUser: usr_123'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('renders empty placeholder if list is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWidgetUnderTest(messages: [], onMessageTap: (_) {}),
    );
    expect(find.text('No messages to display'), findsOneWidget);
  });
}
