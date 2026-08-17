import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:kafkalyzer/src/ui/message_details_dialog.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MessagesTableView', () {
    final messages = [
      KafkaMessage(
        topic: 'test-topic',
        partition: 0,
        offset: 100,
        timestamp: DateTime(2023, 1, 1).millisecondsSinceEpoch,
        key: 'key1',
        payload: 'payload1',
      ),
      KafkaMessage(
        topic: 'test-topic',
        partition: 1,
        offset: 101,
        timestamp: DateTime(2023, 1, 2).millisecondsSinceEpoch,
        key: 'key2',
        payload: 'payload2',
      ),
    ];

    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(
        1200,
        800,
      );
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('renders messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: MessagesTableView(messages: messages, onMessageTap: (_) {}),
          ),
        ),
      );

      expect(find.byType(TableView), findsOneWidget);
      expect(find.text('key1', findRichText: true), findsOneWidget);
      expect(find.text('payload1', findRichText: true), findsOneWidget);
      expect(find.text('key2', findRichText: true), findsOneWidget);
      expect(find.text('payload2', findRichText: true), findsOneWidget);
    });

    testWidgets('sorts by different columns', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              showTopic: true,
              onMessageTap: (_) {},
            ),
          ),
        ),
      );

      // Sort by Offset ascending and descending
      await tester.tap(find.text('Offset'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Offset'));
      await tester.pumpAndSettle();

      // Sort by Timestamp
      await tester.tap(find.text('Timestamp'));
      await tester.pumpAndSettle();

      // Sort by Partition
      await tester.tap(find.text('Partition'));
      await tester.pumpAndSettle();

      // Sort by Key
      await tester.tap(find.text('Key'));
      await tester.pumpAndSettle();

      // Sort by Content
      await tester.tap(find.text('Content'));
      await tester.pumpAndSettle();

      // Sort by Topic
      await tester.tap(find.text('Topic'));
      await tester.pumpAndSettle();
    });

    testWidgets('filters messages using filter dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              showTopic: true,
              onMessageTap: (_) {},
            ),
          ),
        ),
      );

      // Open filter dialog for Key
      final filterIcon = find
          .byIcon(Icons.filter_list)
          .at(4); // Key column filter icon
      await tester.tap(filterIcon);
      await tester.pumpAndSettle();

      expect(find.text('Filter Key'), findsOneWidget);

      // Apply filter
      await tester.enterText(find.byType(TextField), 'key1');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      // Verify that key2 is no longer displayed or is filtered out
      // (Since TableView doesn't build unrendered cells, key1 is there but key2 is not)
      expect(find.text('key1', findRichText: true), findsOneWidget);
      expect(find.text('key2', findRichText: true), findsNothing);

      // Clear filter
      final activeFilterIcon = find.byIcon(Icons.filter_alt).first;
      await tester.tap(activeFilterIcon);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('key2', findRichText: true), findsOneWidget);
    });

    testWidgets('shows topic column when enabled', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              showTopic: true,
              onMessageTap: (_) {},
            ),
          ),
        ),
      );
      expect(find.text('Topic'), findsOneWidget);
      expect(find.text('test-topic'), findsAtLeastNWidgets(2));
    });

    testWidgets('row tap calls onMessageTap or shows details dialog', (
      tester,
    ) async {
      KafkaMessage? tappedMessage;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              onMessageTap: (msg) {
                tappedMessage = msg;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('key1', findRichText: true));
      await tester.pumpAndSettle();

      expect(tappedMessage, isNotNull);
      expect(tappedMessage!.key, 'key1');

      // Now test showing details dialog when onMessageTap is null
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: MessagesTableView(messages: messages)),
        ),
      );

      await tester.tap(find.text('key2', findRichText: true));
      await tester.pumpAndSettle();

      expect(find.byType(MessageDetailsDialog), findsOneWidget);
    });
  });
}
