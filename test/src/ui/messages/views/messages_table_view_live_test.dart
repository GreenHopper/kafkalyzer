import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/message_ring_buffer.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:material_ui/material_ui.dart';

KafkaMessage _msg(int offset, {String? key, String? payload, int? timestamp}) {
  return KafkaMessage(
    topic: 'orders',
    partition: 0,
    offset: offset,
    key: key ?? 'key-$offset',
    payload: payload ?? 'payload-$offset',
    timestamp: timestamp ?? 1700000000000 + offset * 1000,
  );
}

void main() {
  testWidgets('retained messages are not rebuilt on a live tick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final buffer = MessageRingBuffer(4);
    buffer.add(_msg(0));
    buffer.add(_msg(1));
    buffer.add(_msg(2));

    final builtOffsets = <int>[];
    var snapshot = buffer.snapshot();
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
                messages: snapshot,
                onRowBuilt: (m) => builtOffsets.add(m.offset),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(builtOffsets, [0, 1, 2]);
    builtOffsets.clear();

    // Add 2 messages (offset 0 evicted, 1 & 2 retained, 3 & 4 added)
    buffer.add(_msg(3));
    buffer.add(_msg(4));
    setHostState(() {
      snapshot = buffer.snapshot();
    });
    await tester.pumpAndSettle();

    expect(builtOffsets, [3, 4]);
    expect(find.text('payload-0', findRichText: true), findsNothing);
    expect(find.text('payload-4', findRichText: true), findsOneWidget);
  });

  testWidgets('column filter is evaluated only for new rows on a live tick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final buffer = MessageRingBuffer(4);
    buffer.add(_msg(0, payload: 'alpha-0'));
    buffer.add(_msg(1, payload: 'beta-1'));
    buffer.add(_msg(2, payload: 'alpha-2'));

    final filterEvaluated = <int>[];
    var snapshot = buffer.snapshot();
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
                messages: snapshot,
                onColumnFilterEvaluated: (m) => filterEvaluated.add(m.offset),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Content column filter dialog
    final filterIcons = find.byIcon(Icons.filter_list);
    expect(filterIcons, findsWidgets);
    await tester.tap(filterIcons.at(4));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'alpha');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();

    expect(filterEvaluated, [0, 1, 2]);
    filterEvaluated.clear();

    // Add 2 new rows; offset 0 evicted
    buffer.add(_msg(3, payload: 'beta-3'));
    buffer.add(_msg(4, payload: 'alpha-4'));
    setHostState(() {
      snapshot = buffer.snapshot();
    });
    await tester.pumpAndSettle();

    expect(filterEvaluated, [3, 4]);
    expect(find.text('alpha-2', findRichText: true), findsOneWidget);
    expect(find.text('alpha-4', findRichText: true), findsOneWidget);
    expect(find.text('beta-3', findRichText: true), findsNothing);
  });

  testWidgets('incremental column sort equals full sort across live ticks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final buffer = MessageRingBuffer(4);
    buffer.add(_msg(0, key: 'k-30'));
    buffer.add(_msg(1, key: 'k-10'));
    buffer.add(_msg(2, key: 'k-20'));

    var snapshot = buffer.snapshot();
    List<int> latestVisualOffsets = [];
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
                messages: snapshot,
                onVisualOrderChanged: (order) {
                  latestVisualOffsets = order.map((m) => m.offset).toList();
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Click Key header (column index 3) to sort ascending by key
    await tester.tap(find.text('Key').first);
    await tester.pumpAndSettle();
    expect(latestVisualOffsets, [1, 2, 0]); // k-10, k-20, k-30

    // Add k-05 and k-25 -> k-30 (offset 0) evicted
    buffer.add(_msg(3, key: 'k-05'));
    buffer.add(_msg(4, key: 'k-25'));
    setHostState(() {
      snapshot = buffer.snapshot();
    });
    await tester.pumpAndSettle();

    // Expected sorted by key: k-05 (3), k-10 (1), k-20 (2), k-25 (4)
    expect(latestVisualOffsets, [3, 1, 2, 4]);
  });
}
