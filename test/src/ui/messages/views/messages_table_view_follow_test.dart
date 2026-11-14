import 'dart:ui' show Tristate;
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/message_ring_buffer.dart';
import 'package:kafkalyzer/src/ui/messages/views/messages_table_view.dart';
import 'package:material_ui/material_ui.dart';
import 'package:two_dimensional_scrollables/two_dimensional_scrollables.dart';

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
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  ScrollPosition findVerticalTablePosition(WidgetTester tester) {
    final twoD = tester.state<TwoDimensionalScrollableState>(
      find.byType(TwoDimensionalScrollable),
    );
    return twoD.verticalScrollable.position;
  }

  testWidgets(
    'follow newest is on by default, exposes tooltip & semantics, and re-enables on token change',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final messages = List.generate(30, (i) => _msg(i));
      var token = 1;
      late StateSetter setHostState;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MessagesTableView(
                messages: messages,
                showFollowControl: true,
                followResetToken: token,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('follow_newest_toggle'));
      expect(toggleFinder, findsOneWidget);
      expect(find.text('Follow newest'), findsOneWidget);

      final semantics = tester.getSemantics(toggleFinder);
      expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
      expect(find.byType(Tooltip), findsWidgets);

      // Tap a row -> switches follow off
      await tester.tap(find.text('payload-0', findRichText: true));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isFalse,
      );

      // New stream token switches follow back on
      setHostState(() {
        token = 2;
      });
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isTrue,
      );
    },
  );

  testWidgets(
    'stays at top for descending and at bottom for ascending when following',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var messages = List.generate(30, (i) => _msg(29 - i)); // descending
      var ascending = false;
      late StateSetter setHostState;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MessagesTableView(
                messages: messages,
                showFollowControl: true,
                followResetToken: 1,
                inputSortField: 'timestamp',
                inputSortAscending: ascending,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      var vPos = findVerticalTablePosition(tester);
      expect(vPos.pixels, 0.0);

      // Prepend newer messages in descending order -> stays at 0
      setHostState(() {
        messages = [_msg(31), _msg(30), ...messages];
      });
      await tester.pumpAndSettle();
      expect(vPos.pixels, 0.0);

      // Switch to ascending order -> jumps to maxScrollExtent
      setHostState(() {
        ascending = true;
        messages = List.generate(32, (i) => _msg(i));
      });
      await tester.pumpAndSettle();
      vPos = findVerticalTablePosition(tester);
      expect(vPos.pixels, vPos.maxScrollExtent);
      expect(vPos.pixels, greaterThan(0.0));

      // Append more in ascending order -> stays at new maxScrollExtent
      setHostState(() {
        messages = [...messages, _msg(32), _msg(33)];
      });
      await tester.pumpAndSettle();
      expect(vPos.pixels, vPos.maxScrollExtent);
    },
  );

  testWidgets(
    'wheel and drag switch follow off, programmatic scroll does not, and re-enable jumps to newest',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final messages = List.generate(40, (i) => _msg(39 - i));
      KafkaMessage? selected;
      late StateSetter setHostState;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MessagesTableView(
                messages: messages,
                showFollowControl: true,
                followResetToken: 1,
                selectedMessage: selected,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('follow_newest_toggle'));
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isTrue,
      );

      // Programmatic scroll via selectedMessage change should NOT switch follow off
      setHostState(() {
        selected = messages[25];
      });
      await tester.pumpAndSettle();
      final vPos = findVerticalTablePosition(tester);
      expect(vPos.pixels, greaterThan(0.0));
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isTrue,
      );

      // Re-tap toggle off then on -> jumps back to 0 (descending newest)
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isFalse,
      );
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isTrue,
      );
      expect(vPos.pixels, 0.0);

      // Wheel scroll switches follow off
      final tableCenter = tester.getCenter(find.byType(TableView));
      final pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(tableCenter));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isFalse,
      );

      // Re-enable -> jumps back to 0
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isTrue,
      );
      expect(vPos.pixels, 0.0);

      // Drag scroll switches follow off
      await tester.drag(find.byType(TableView), const Offset(0, -150));
      await tester.pumpAndSettle();
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isFalse,
      );
    },
  );

  testWidgets(
    'anchor row keeps its y position when 50 rows arrive and 50 drop while follow is off',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final buffer = MessageRingBuffer(150);
      for (var i = 0; i < 150; i++) {
        buffer.add(_msg(i));
      }

      // Descending order (newest first)
      List<KafkaMessage> desc(MessageSnapshot snap) => snap.reversed.toList();
      var current = desc(buffer.snapshot());
      late StateSetter setHostState;

      await tester.pumpWidget(
        wrap(
          StatefulBuilder(
            builder: (context, setState) {
              setHostState = setState;
              return MessagesTableView(
                messages: current,
                showFollowControl: true,
                followResetToken: 1,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to row around offset 80 (switches follow off)
      await tester.drag(find.byType(TableView), const Offset(0, -600));
      await tester.pumpAndSettle();

      final toggleFinder = find.byKey(const ValueKey('follow_newest_toggle'));
      expect(
        tester.getSemantics(toggleFinder).flagsCollection.isToggled,
        Tristate.isFalse,
      );

      // Pick a visible anchor row
      final anchorFinder = find.text('payload-135', findRichText: true);
      expect(anchorFinder, findsOneWidget);
      final anchorYBefore = tester.getTopLeft(anchorFinder).dy;

      // 50 new rows arrive (150..199) and 50 oldest (0..49) drop
      for (var i = 150; i < 200; i++) {
        buffer.add(_msg(i));
      }
      setHostState(() {
        current = desc(buffer.snapshot());
      });
      // Pump 1 frame (not pumpAndSettle) to verify zero-jump on first frame per S2
      await tester.pump();

      final anchorYAfter = tester.getTopLeft(anchorFinder).dy;
      expect(anchorYAfter, moreOrLessEquals(anchorYBefore, epsilon: 1.0));
    },
  );

  testWidgets('follow toggle is disabled under non-timestamp column sort', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final messages = List.generate(10, (i) => _msg(i));

    await tester.pumpWidget(
      wrap(
        MessagesTableView(
          messages: messages,
          showFollowControl: true,
          followResetToken: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Sort by Key column
    await tester.tap(find.text('Key').first);
    await tester.pumpAndSettle();

    final toggleFinder = find.byKey(const ValueKey('follow_newest_toggle'));
    expect(
      tester.getSemantics(toggleFinder).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
  });
}
