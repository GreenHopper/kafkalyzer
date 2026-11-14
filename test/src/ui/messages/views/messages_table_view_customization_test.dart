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

  testWidgets(
    'sorting by column breaks ties deterministically by topic, partition, offset',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final m1 = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 5,
        key: 'k',
        payload: '{"row":"first"}',
        timestamp: 9000,
      );
      final m2 = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 10,
        key: 'k',
        payload: '{"row":"second"}',
        timestamp: 9000,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MessagesTableView(messages: [m2, m1])),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Timestamp column header to activate column sort
      await tester.tap(find.text('Timestamp'));
      await tester.pumpAndSettle();

      // Ties should put offset 5 before offset 10
      final firstY = tester.getTopLeft(find.text('5')).dy;
      final secondY = tester.getTopLeft(find.text('10')).dy;
      expect(firstY, lessThan(secondY));
    },
  );

  testWidgets(
    'Content column filter matches full payload beyond 300-char preview',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final longPayload = '${'x' * 350}needle-beyond-preview';
      final mLong = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: longPayload,
        timestamp: 2000,
      );
      final mOther = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 2,
        key: 'k2',
        payload: '{"nullableKey":null,"other":"value"}',
        timestamp: 1000,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MessagesTableView(messages: [mLong, mOther])),
        ),
      );
      await tester.pumpAndSettle();

      // Open Content column filter (column index 4: Timestamp, Partition, Offset, Key, Content)
      await tester.tap(find.byIcon(Icons.filter_list).at(4));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).last,
        'needle-beyond-preview',
      );
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsNothing);
    },
  );

  testWidgets(
    'empty column-filter state preserves header and resets filters on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final m1 = KafkaMessage(
        topic: 'orders',
        partition: 0,
        offset: 1,
        key: 'k1',
        payload: 'hello',
        timestamp: 1000,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: MessagesTableView(messages: [m1])),
        ),
      );
      await tester.pumpAndSettle();

      // Filter Content with a non-matching term
      await tester.tap(find.byIcon(Icons.filter_list).at(4));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'does-not-exist');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text('Timestamp'), findsOneWidget);
      expect(
        find.text('No rows match the active column filters.'),
        findsOneWidget,
      );
      expect(find.text('Reset filters'), findsOneWidget);

      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(
        find.text('No rows match the active column filters.'),
        findsNothing,
      );
    },
  );

  testWidgets('renders German headers and filter dialog texts', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final m1 = KafkaMessage(
      topic: 'orders',
      partition: 0,
      offset: 1,
      key: 'k1',
      payload: 'hello',
      timestamp: 1000,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('de'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: MessagesTableView(messages: [m1])),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zeitstempel'), findsOneWidget);
    expect(find.text('Key'), findsOneWidget);
    expect(find.text('Inhalt'), findsOneWidget);

    final contentFilter = find.byTooltip('Inhalt filtern');
    expect(contentFilter, findsOneWidget);
    final filterSize = tester.getSize(contentFilter);
    expect(filterSize.width, greaterThanOrEqualTo(24.0));
    expect(filterSize.height, greaterThanOrEqualTo(24.0));

    await tester.tap(contentFilter);
    await tester.pumpAndSettle();

    expect(find.text('Inhalt filtern'), findsOneWidget);
    expect(find.text('Suchtext zum Filtern eingeben...'), findsOneWidget);
    expect(find.text('Leeren'), findsOneWidget);
    expect(find.text('Anwenden'), findsOneWidget);
  });
}
