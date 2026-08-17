import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_diff_view.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/diff/json_diff_widget.dart';

void main() {
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
}
