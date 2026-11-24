import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/projected_column.dart';
import 'package:kafkalyzer/src/features/messages/presentation/views/messages_table_view.dart';
import 'package:mockito/mockito.dart';

import '../../../../rust/api/rust_mocks.mocks.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

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
  final resolverPayloads = <List<String>>[];
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    resolverCalls.clear();
    resolverPayloads.clear();
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
      resolverPayloads.add(payloads);
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
      tester.view.physicalSize = const Size(1200, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      ProjectedColumn? removedColumn;
      final projectedColumns = [
        const ProjectedColumn(path: 'customer.name', label: 'Customer'),
      ];

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

  testWidgets(
    'incremental live tick resolves only new payloads and prunes dropped entries',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final msg4 = createMessage(
        offset: 4,
        payload:
            '{"customer": {"name": "Alice", "id": 101}, "status": "ACTIVE"}',
      );
      var currentMessages = [messages[0], messages[1], messages[2]];
      late StateSetter setHostState;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return MessagesTableView(
                  messages: currentMessages,
                  projectedColumns: const [
                    ProjectedColumn(path: 'customer.name', label: 'Customer'),
                    ProjectedColumn(path: 'status', label: 'Status'),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(resolverPayloads, hasLength(1));
      expect(resolverPayloads.single, hasLength(3));
      resolverPayloads.clear();

      // Drop messages[0], keep messages[1] & messages[2], add msg4
      setHostState(() {
        currentMessages = [messages[1], messages[2], msg4];
      });
      await tester.pumpAndSettle();

      expect(resolverPayloads, hasLength(1));
      expect(resolverPayloads.single, [msg4.payload]);
      resolverPayloads.clear();

      // Re-adding the exact dropped instance messages[0] must resolve it again
      // because its cache entry was pruned when it left the input.
      setHostState(() {
        currentMessages = [messages[2], msg4, messages[0]];
      });
      await tester.pumpAndSettle();

      expect(resolverPayloads, hasLength(1));
      expect(resolverPayloads.single, [messages[0].payload]);
    },
  );
}
