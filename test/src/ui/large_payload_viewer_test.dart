import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:kafkalyzer/src/utils/payload_processing_isolate.dart';
import 'package:material_ui/material_ui.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    '20 MB raw payload stays virtualized, bounded, and jumps within budget',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // ~20 MB text: 180k x 100-char lines (~18 MB) + 2 MB single line + marker at end
      final line = '${'a' * 99}\n';
      final linesBlock = line * 180000;
      final singleLine2Mb = 'b' * (2 * 1024 * 1024);
      final payload = '$linesBlock$singleLine2Mb\nNEEDLE_AT_THE_END';

      var matchCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 1000,
              child: JsonOrStringViewer(
                rawContent: payload,
                expand: true,
                searchQuery: 'NEEDLE_AT_THE_END',
                focusedMatchIndex: 0,
                onMatchCountChanged: (c) => matchCount = c,
              ),
            ),
          ),
        ),
      );

      // Wait for initial parsing/indexing + search
      await tester.pumpAndSettle();

      final swReady = Stopwatch()..start();
      await tester.pump();
      swReady.stop();
      expect(swReady.elapsedMilliseconds, lessThan(250));

      expect(matchCount, 1);
      expect(find.textContaining('truncated'), findsNothing);

      final builtRowRichTexts = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byType(ScrollablePositionedList),
              matching: find.byType(RichText),
            ),
          )
          .toList();
      expect(builtRowRichTexts.length, lessThanOrEqualTo(200));
      for (final rt in builtRowRichTexts) {
        expect(
          rt.text.toPlainText().length,
          lessThanOrEqualTo(defaultMaxRawRowChars),
        );
      }

      // Jump to last match near end of 20 MB payload
      final state = tester.state<JsonOrStringViewerState>(
        find.byType(JsonOrStringViewer),
      );
      state.jumpToMatch(0);
      await tester.pumpAndSettle();

      final swJump = Stopwatch()..start();
      await tester.pump();
      swJump.stop();
      expect(swJump.elapsedMilliseconds, lessThan(250));

      final targetRichTexts = tester
          .widgetList<RichText>(
            find.descendant(
              of: find.byType(ScrollablePositionedList),
              matching: find.byType(RichText),
            ),
          )
          .where((rt) => rt.text.toPlainText().contains('NEEDLE_AT_THE_END'))
          .toList();
      expect(targetRichTexts, isNotEmpty);

      TextSpan? focusedSpan;
      targetRichTexts.first.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'NEEDLE_AT_THE_END') {
          focusedSpan = span;
          return false;
        }
        return true;
      });
      expect(focusedSpan, isNotNull);
      expect(focusedSpan!.style?.backgroundColor, Colors.orange);
    },
  );

  testWidgets(
    '20 MB binary payload renders in HexViewer without truncation and shows last offset',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const len = 20 * 1024 * 1024;
      final bytes = Uint8List(len);
      bytes[len - 1] = 0xAB;
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              height: 800,
              width: 1000,
              child: HexViewer(
                bytes: bytes,
                scrollController: scrollController,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('truncated'), findsNothing);

      scrollController.jumpTo(scrollController.position.maxScrollExtent);
      await tester.pumpAndSettle();

      final expectedOffset = ((len - 1) & ~0xF)
          .toRadixString(16)
          .padLeft(8, '0');
      expect(find.textContaining(expectedOffset), findsOneWidget);
    },
  );
}
