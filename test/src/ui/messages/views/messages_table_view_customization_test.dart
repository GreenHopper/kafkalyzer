import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:mockito/mockito.dart';

import '../../../rust/api/rust_mocks.mocks.dart';

void main() {
  // Projected cells are filled by the Rust resolver; these layout tests only
  // need the call to complete, so every projected value resolves to empty.
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    reset(mockApi);
    when(
      mockApi.crateApiJsonPathResolveJsonPathBatch(
        payloads: anyNamed('payloads'),
        paths: anyNamed('paths'),
      ),
    ).thenAnswer((invocation) async {
      final payloads = invocation.namedArguments[#payloads] as List<String>;
      final paths = invocation.namedArguments[#paths] as List<String>;
      return List<String?>.filled(payloads.length * paths.length, null);
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
      payload:
          '{"customer": {"name": "Alice Very Long Customer Name", "id": 101}}',
    ),
    createMessage(
      offset: 2,
      payload: '{"customer": {"name": "Bob", "id": 102}}',
    ),
  ];

  testWidgets(
    'hides standard column when marked in columnConfig.hiddenColumns',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // Initial state: Partition and Offset are hidden
      const config = TableColumnConfig(
        hiddenColumns: {
          StandardTableColumns.partition,
          StandardTableColumns.offset,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesTableView(messages: messages, columnConfig: config),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Timestamp'), findsOneWidget);
      expect(find.text('Key'), findsOneWidget);
      expect(find.text('Content'), findsOneWidget);
      expect(find.text('Partition'), findsNothing);
      expect(find.text('Offset'), findsNothing);
    },
  );

  testWidgets('hides standard column via quick-hide header icon', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? hiddenColumnId;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessagesTableView(
            messages: messages,
            onToggleColumnVisibility: (id) => hiddenColumnId = id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Find quick-hide icons on standard columns
    final hideIcons = find.byIcon(Icons.visibility_off_outlined);
    expect(hideIcons, findsWidgets);

    await tester.tap(hideIcons.first);
    await tester.pumpAndSettle();

    expect(hiddenColumnId, equals(StandardTableColumns.timestamp));
  });

  testWidgets(
    'resizes column width interactively via drag handle and auto-fits on double tap',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      String? resizedColId;
      double? resizedWidth;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              projectedColumns: const [
                ProjectedColumn(path: 'customer.name', label: 'Customer'),
              ],
              onColumnWidthChanged: (colId, width) {
                resizedColId = colId;
                resizedWidth = width;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handleFinder = find.byKey(const Key('resize_handle_timestamp'));
      expect(handleFinder, findsOneWidget);

      // 1. Test dragging resize handle
      await tester.drag(handleFinder, const Offset(50, 0));
      await tester.pumpAndSettle();

      expect(resizedColId, equals(StandardTableColumns.timestamp));
      expect(resizedWidth, isNotNull);
      expect(resizedWidth, greaterThan(180.0));

      // 2. Test double tap to auto-fit
      // Double tap the Customer column resize handle (which has long content)
      final customerHandle = find.byKey(
        const Key('resize_handle_customer.name'),
      );
      expect(customerHandle, findsOneWidget);
      await tester.tap(customerHandle);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(customerHandle);
      await tester.pumpAndSettle();

      expect(resizedColId, equals('customer.name'));
    },
  );

  testWidgets(
    'secondary tap on row shows context menu with Copy Shareable Link',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final List<MethodCall> calls = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessagesTableView(
              messages: messages,
              searchPhrase: 'test-query',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find cell InkWell for data row 0 column 0
      final cellInkWell = find.byKey(const ValueKey('message_cell_0_0'));
      expect(cellInkWell, findsOneWidget);
      await tester.tap(cellInkWell, buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('menu_copy_shareable_link')), findsOneWidget);
      await tester.tap(find.byKey(const Key('menu_copy_shareable_link')));
      await tester.pumpAndSettle();

      final setClipboardCall = calls.firstWhere(
        (c) => c.method == 'Clipboard.setData',
      );
      final text = setClipboardCall.arguments['text'] as String;
      expect(text, contains('kafkalyzer://open'));
      expect(text, contains('topic=test-topic'));
      expect(text, contains('offset=1'));
      expect(text, contains('filter=test-query'));
    },
  );
}
