import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_metadata_card.dart';

void main() {
  Widget createWidgetUnderTest(
    KafkaMessage message, {
    KafkaMessage? prevMessage,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: MessageMetadataCard(message: message, prevMessage: prevMessage),
      ),
    );
  }

  group('MessageMetadataCard', () {
    const msgBase = KafkaMessage(
      topic: 'test-topic',
      partition: 1,
      offset: 100,
      timestamp: 1000000,
    );

    testWidgets('renders "Start" when prevMessage is null', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(msgBase));
      expect(find.text('Start'), findsOneWidget);
      expect(find.text('test-topic'), findsOneWidget);
      expect(find.text('P: 1 | O: 100'), findsOneWidget);
    });

    testWidgets('renders duration difference in milliseconds', (tester) async {
      const prev = KafkaMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 99,
        timestamp: 999500, // 500ms diff
      );
      await tester.pumpWidget(
        createWidgetUnderTest(msgBase, prevMessage: prev),
      );
      expect(find.text('+500ms'), findsOneWidget);
    });

    testWidgets('renders duration difference in seconds', (tester) async {
      const prev = KafkaMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 98,
        timestamp: 985000, // 15s diff
      );
      await tester.pumpWidget(
        createWidgetUnderTest(msgBase, prevMessage: prev),
      );
      expect(find.text('+15.0s'), findsOneWidget);
    });

    testWidgets('renders duration difference in minutes', (tester) async {
      const prev = KafkaMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 97,
        timestamp: 880000, // 120s diff = 2.0m
      );
      await tester.pumpWidget(
        createWidgetUnderTest(msgBase, prevMessage: prev),
      );
      expect(find.text('+2.0m'), findsOneWidget);
    });

    testWidgets('renders step name for ScriptResultMessage', (tester) async {
      final scriptMsg = ScriptResultMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 100,
        key: 'key',
        payload: 'val',
        timestamp: 1000000,
        stepId: 'step-1',
        stepName: 'My Step Name',
      );
      await tester.pumpWidget(createWidgetUnderTest(scriptMsg));
      expect(find.text('My Step Name'), findsOneWidget);
    });

    testWidgets('shows the schema of each message side with its own values', (
      tester,
    ) async {
      const schemaMessage = KafkaMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 100,
        timestamp: 1000000,
        keySchema: MessageSchema(schemaId: 7, subject: 'test-key', version: 1),
        valueSchema: MessageSchema(
          schemaId: 128,
          subject: 'test-value',
          version: 4,
        ),
      );

      await tester.pumpWidget(createWidgetUnderTest(schemaMessage));

      expect(find.text('Key: test-key v1 (#7)'), findsOneWidget);
      expect(find.text('Value: test-value v4 (#128)'), findsOneWidget);
    });

    testWidgets('shows no schema lines for a message without registry schema', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest(msgBase));

      expect(find.byKey(const Key('metadata_card_schema_key')), findsNothing);
      expect(find.byKey(const Key('metadata_card_schema_value')), findsNothing);
    });
  });
}
