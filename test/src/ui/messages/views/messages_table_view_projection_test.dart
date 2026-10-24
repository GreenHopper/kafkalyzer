import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:mockito/mockito.dart';

import '../../../rust/api/rust_mocks.mocks.dart';

void main() {
  // Projected values come from the Rust resolver, whose grammar is tested in
  // `rust/kafkalyzer-core/src/json_path.rs`. The table only consumes the
  // returned strings, so the widget test stubs the bridge and checks wiring.
  const resolved = {
    '{"customer": {"name": "Alice", "id": 101}, "status": "ACTIVE"}': {
      'customer.name': 'Alice',
      'customer.id': '101',
      'status': 'ACTIVE',
    },
    '{"customer": {"name": "Bob", "id": 102}, "status": "PENDING"}': {
      'customer.name': 'Bob',
      'customer.id': '102',
      'status': 'PENDING',
    },
    '{"customer": null, "status": "INACTIVE"}': {'status': 'INACTIVE'},
  };
  final resolverCalls = <List<String>>[];
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    resolverCalls.clear();
    reset(mockApi);
    when(
      mockApi.crateApiJsonPathResolveJsonPathBatch(
        payloads: anyNamed('payloads'),
        paths: anyNamed('paths'),
      ),
    ).thenAnswer((invocation) async {
      final payloads = invocation.namedArguments[#payloads] as List<String>;
      final paths = invocation.namedArguments[#paths] as List<String>;
      resolverCalls.add(paths);
      return [
        for (final payload in payloads)
          for (final path in paths) resolved[payload]?[path],
      ];
    });
  });

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

  testWidgets('resolves a 500 message batch with a single bridge call', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final manyMessages = List.generate(
      500,
      (index) => createMessage(
        offset: index + 1,
        payload:
            '{"customer": {"name": "Alice", "id": 101}, "status": "ACTIVE"}',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesTableView(
            messages: manyMessages,
            projectedColumns: const [
              ProjectedColumn(path: 'customer.name', label: 'Customer'),
              ProjectedColumn(path: 'customer.id', label: 'Customer Id'),
              ProjectedColumn(path: 'status', label: 'Status'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resolverCalls, hasLength(1));
    expect(resolverCalls.single, ['customer.name', 'customer.id', 'status']);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('Alice'),
      ),
      findsWidgets,
    );
  });
}
