import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';

void main() {
  KafkaMessage createMessage({
    required int offset,
    required String payload,
    String? key,
  }) {
    return KafkaMessage(
      topic: 'test-topic',
      partition: 0,
      offset: offset,
      timestamp: 1600000000000 + offset * 1000,
      key: key ?? 'key-$offset',
      payload: payload,
      headers: const [],
    );
  }

  final messages = [
    createMessage(
      offset: 1,
      payload: '{"customer": {"name": "Alice", "id": 101}, "status": "ACTIVE"}',
    ),
    createMessage(
      offset: 2,
      payload: '{"customer": {"name": "Bob", "id": 102}, "status": "PENDING"}',
    ),
    createMessage(
      offset: 3,
      payload: '{"customer": null, "status": "INACTIVE"}',
    ),
  ];

  testWidgets('renders projected columns alongside standard columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projectedColumns = [
      const ProjectedColumn(path: 'customer.name', label: 'Customer'),
      const ProjectedColumn(path: 'status', label: 'Status'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesTableView(
            messages: messages,
            projectedColumns: projectedColumns,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Customer'), findsOneWidget);
    expect(find.textContaining('Status'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          return widget.text.toPlainText() == 'Alice';
        }
        return false;
      }),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          return widget.text.toPlainText() == 'Bob';
        }
        return false;
      }),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          return widget.text.toPlainText() == 'ACTIVE';
        }
        return false;
      }),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          return widget.text.toPlainText() == 'PENDING';
        }
        return false;
      }),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate((widget) {
        if (widget is RichText) {
          return widget.text.toPlainText() == 'INACTIVE';
        }
        return false;
      }),
      findsOneWidget,
    );
  });

  testWidgets(
    'triggers onRemoveProjectedColumn callback when close icon tapped',
    (tester) async {
      ProjectedColumn? removedColumn;
      final projectedColumns = [
        const ProjectedColumn(path: 'customer.name', label: 'Customer'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              projectedColumns: projectedColumns,
              onRemoveProjectedColumn: (col) {
                removedColumn = col;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closeIcon = find.byIcon(Icons.close);
      expect(closeIcon, findsOneWidget);

      await tester.tap(closeIcon);
      await tester.pumpAndSettle();

      expect(removedColumn, equals(projectedColumns.first));
    },
  );

  testWidgets('sorts rows when clicking projected column header', (
    tester,
  ) async {
    final projectedColumns = [
      const ProjectedColumn(path: 'customer.name', label: 'Customer'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesTableView(
            messages: messages,
            projectedColumns: projectedColumns,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Customer header to sort
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();

    // Verify sort indicator arrow appears
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);

    // Tap Customer header again to sort descending
    await tester.tap(find.text('Customer'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
  });
}
