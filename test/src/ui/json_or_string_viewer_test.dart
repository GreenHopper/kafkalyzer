import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';

Future<void> awaitIsolates(WidgetTester tester) async {
  await tester.pump();
  int attempts = 0;
  while (tester.any(find.byType(CircularProgressIndicator)) && attempts < 50) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    attempts++;
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('JsonOrStringViewer', () {
    testWidgets('renders raw content when input is invalid json', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              title: 'Test Viewer',
              rawContent: 'Not a JSON string',
            ),
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text('Test Viewer'), findsOneWidget);
      expect(find.text('Not a JSON string'), findsOneWidget);
      expect(find.byType(ToggleButtons), findsNothing);
    });

    testWidgets(
      'renders Tree view by default for valid json and has only Raw and Tree toggles',
      (tester) async {
        final jsonStr = '{"key": "value"}';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JsonOrStringViewer(
                title: 'Test Viewer',
                rawContent: jsonStr,
              ),
            ),
          ),
        );
        await awaitIsolates(tester);

        expect(find.text('key: '), findsOneWidget);
        expect(find.text('"value"'), findsOneWidget);
        expect(find.byType(ToggleButtons), findsOneWidget);

        final toggleButtons = tester.widget<ToggleButtons>(
          find.byType(ToggleButtons),
        );
        expect(toggleButtons.children.length, 2);
        expect(find.text('Raw'), findsOneWidget);
        expect(find.text('Tree'), findsOneWidget);
        expect(find.text('Cards'), findsNothing);
        expect(toggleButtons.isSelected[1], isTrue); // Tree selected
      },
    );

    testWidgets('switches to Raw view', (tester) async {
      final jsonStr = '{"key": "value"}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(title: 'Test Viewer', rawContent: jsonStr),
          ),
        ),
      );

      await awaitIsolates(tester);
      await tester.tap(find.text('Raw'));
      await tester.pumpAndSettle();

      expect(find.text(jsonStr), findsOneWidget);
    });

    testWidgets(
      'persistence restores view mode and maps legacy Cards (2) to Tree (1)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'json_view_mode_testkey': 0, // Saved as Raw
        });

        final jsonStr = '{"key": "value"}';
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JsonOrStringViewer(
                title: 'Test Viewer',
                rawContent: jsonStr,
                persistenceKey: 'testkey',
              ),
            ),
          ),
        );
        await awaitIsolates(tester);

        final toggleButtons = tester.widget<ToggleButtons>(
          find.byType(ToggleButtons),
        );
        expect(toggleButtons.isSelected[0], isTrue); // Raw selected
      },
    );

    testWidgets('renders Tree view and cycles search results', (tester) async {
      final jsonStr = '{"user": {"account": {"username": "Alice"}}}';
      int matchCount = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              title: 'Test Tree',
              rawContent: jsonStr,
              initialViewMode: 1, // Tree
              searchQuery: 'Alice',
              onMatchCountChanged: (count) {
                matchCount = count;
              },
            ),
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(matchCount, 1);

      final state = tester.state<JsonOrStringViewerState>(
        find.byType(JsonOrStringViewer),
      );
      state.jumpToMatch(0);
      await awaitIsolates(tester);
    });

    testWidgets('renders Binary/Hex view mode', (tester) async {
      const rawBinary = '<Binary Data>:48656c6c6f'; // "Hello" in hex
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              title: 'Binary Test',
              rawContent: rawBinary,
            ),
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.byType(HexViewer), findsOneWidget);
      final hexTextFinder = find.descendant(
        of: find.byType(HexViewer),
        matching: find.textContaining('48 65 6c 6c 6f'),
      );
      expect(hexTextFinder, findsOneWidget);
    });

    testWidgets('copy button copies raw content to clipboard', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(title: 'Copy Test', rawContent: 'copy me'),
          ),
        ),
      );
      await awaitIsolates(tester);

      final copyButton = find.byTooltip('Copy content');
      expect(copyButton, findsOneWidget);
      await tester.tap(copyButton);
      await awaitIsolates(tester);
      expect(find.text('Content copied to clipboard'), findsOneWidget);
    });

    testWidgets('uses pre-parsed JSON', (tester) async {
      final parsed = {'direct': 'value'};
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              title: 'Preparsed Test',
              rawContent: '',
              preParsedJson: parsed,
            ),
          ),
        ),
      );
      await awaitIsolates(tester);
      expect(find.text('direct: '), findsOneWidget);
    });

    testWidgets('updates when rawContent or searchQuery changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              rawContent: '{"a": 1}',
              onMatchCountChanged: (count) {},
            ),
          ),
        ),
      );
      await awaitIsolates(tester);

      // Change content
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              rawContent: '{"b": 2}',
              onMatchCountChanged: (count) {},
            ),
          ),
        ),
      );
      await awaitIsolates(tester);
      expect(find.text('b: '), findsOneWidget);
    });

    testWidgets('toggles hide empty fields in Tree mode', (tester) async {
      final jsonStr = '{"present": "hello", "missing": null}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              rawContent: jsonStr,
              persistenceKey: 'test_hide_null',
            ),
          ),
        ),
      );
      await awaitIsolates(tester);

      // Initially null is visible
      expect(find.text('missing: '), findsOneWidget);

      // Find filter toggle button
      final filterButton = find.byIcon(Icons.filter_alt_off_outlined);
      expect(filterButton, findsOneWidget);

      // Tap to hide null fields
      await tester.tap(filterButton);
      await tester.pumpAndSettle();

      expect(find.text('missing: '), findsNothing);
      expect(find.text('present: '), findsOneWidget);
      expect(find.byIcon(Icons.filter_alt), findsOneWidget);
    });

    testWidgets(
      'shows inline error when row index fails while Copy remains available',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JsonOrStringViewer(
                title: 'Error Test',
                rawContent: 'plain text payload',
                computeRowIndex: (_) async => throw Exception('index boom'),
              ),
            ),
          ),
        );
        await awaitIsolates(tester);

        expect(find.textContaining('index boom'), findsOneWidget);
        await tester.tap(find.byTooltip('Copy content'));
        await tester.pump();
        expect(find.text('Content copied to clipboard'), findsOneWidget);
      },
    );

    testWidgets(
      'raw search reports count, drops stale query results, and reports failed',
      (tester) async {
        final firstCompleter = Completer<({Int32List offsets, bool capped})>();
        final secondCompleter = Completer<({Int32List offsets, bool capped})>();
        var callCount = 0;
        var reportedCount = -1;
        final states = <RawSearchState>[];

        Widget buildViewer(String query) => MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(
              rawContent: 'alpha beta gamma alpha',
              searchQuery: query,
              onMatchCountChanged: (c) => reportedCount = c,
              onSearchStateChanged: states.add,
              findMatches: (text, q) {
                callCount++;
                return callCount == 1
                    ? firstCompleter.future
                    : secondCompleter.future;
              },
            ),
          ),
        );

        await tester.pumpWidget(buildViewer('alpha'));
        await tester.pump();
        expect(states.last, RawSearchState.running);

        // Quickly change query before first search completes.
        await tester.pumpWidget(buildViewer('beta'));
        await tester.pump();

        // Complete second search first, then stale first search.
        secondCompleter.complete((
          offsets: Int32List.fromList([6]),
          capped: false,
        ));
        await tester.pumpAndSettle();
        expect(reportedCount, 1);
        expect(states.last, RawSearchState.done);

        firstCompleter.complete((
          offsets: Int32List.fromList([0, 17]),
          capped: false,
        ));
        await tester.pumpAndSettle();
        // Stale result was dropped.
        expect(reportedCount, 1);

        // Failed search reports RawSearchState.failed.
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: JsonOrStringViewer(
                rawContent: 'alpha beta',
                searchQuery: 'beta',
                onMatchCountChanged: (c) => reportedCount = c,
                onSearchStateChanged: states.add,
                findMatches: (_, _) async => throw Exception('search boom'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(states.last, RawSearchState.failed);
        expect(reportedCount, 0);
      },
    );

    testWidgets(
      'jumpToMatch scrolls to last match in multi-row raw payload and highlights it',
      (tester) async {
        final lines = List.generate(200, (i) => 'line-$i').join('\n');
        final payload = '$lines\ntarget-match-end';
        var matchCount = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                height: 200,
                child: JsonOrStringViewer(
                  rawContent: payload,
                  expand: true,
                  searchQuery: 'target-match-end',
                  focusedMatchIndex: 0,
                  onMatchCountChanged: (c) => matchCount = c,
                ),
              ),
            ),
          ),
        );
        await awaitIsolates(tester);
        expect(matchCount, 1);
        expect(find.text('target-match-end'), findsNothing);

        final state = tester.state<JsonOrStringViewerState>(
          find.byType(JsonOrStringViewer),
        );
        state.jumpToMatch(0);
        await tester.pumpAndSettle();

        final richTexts = tester
            .widgetList<RichText>(find.byType(RichText))
            .where((rt) => rt.text.toPlainText().contains('target-match-end'))
            .toList();
        expect(richTexts, isNotEmpty);
        TextSpan? highlighted;
        richTexts.first.text.visitChildren((span) {
          if (span is TextSpan && span.text == 'target-match-end') {
            highlighted = span;
            return false;
          }
          return true;
        });
        expect(highlighted, isNotNull);
        expect(highlighted!.style?.backgroundColor, Colors.orange);
      },
    );

    testWidgets(
      'whole-value decode chain Base64 -> gzip -> JSON updates banner, copy, search, and Show original',
      (tester) async {
        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                copiedText = (call.arguments as Map)['text'] as String?;
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null),
        );

        final gzBytes = gzip.encode(utf8.encode('{"decodedField":"needle"}'));
        final b64 = base64Encode(gzBytes);
        int reportedMatches = -1;
        final viewerKey = GlobalKey<JsonOrStringViewerState>();

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: JsonOrStringViewer(
                key: viewerKey,
                rawContent: b64,
                searchQuery: 'needle',
                onMatchCountChanged: (c) => reportedMatches = c,
              ),
            ),
          ),
        );
        await awaitIsolates(tester);
        expect(reportedMatches, 0);

        // Decode Base64
        await tester.tap(find.byTooltip('Decode as…'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Base64'));
        await awaitIsolates(tester);
        expect(find.byType(HexViewer), findsOneWidget);
        expect(find.text('Base64'), findsOneWidget);

        // In Hex mode, toolbar menu only offers gzip
        await tester.tap(find.byTooltip('Decode as…'));
        await tester.pumpAndSettle();
        expect(find.text('JSON'), findsNothing);
        expect(find.text('Base64'), findsOneWidget); // only in banner
        await tester.tap(find.text('gzip'));
        await awaitIsolates(tester);
        expect(find.text('Base64 → gzip'), findsOneWidget);

        // Decode JSON
        await tester.tap(find.byTooltip('Decode as…'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('JSON'));
        await awaitIsolates(tester);
        expect(find.text('Base64 → gzip → JSON'), findsOneWidget);
        expect(find.text('decodedField: '), findsOneWidget);
        expect(reportedMatches, 1);

        viewerKey.currentState?.jumpToMatch(0);
        await tester.pumpAndSettle();
        expect(find.text('🎯'), findsOneWidget);

        // Copy decoded copies decoded JSON; original Copy copies b64
        await tester.tap(find.text('Copy decoded'));
        await tester.pump();
        expect(copiedText, contains('"decodedField": "needle"'));

        await tester.tap(find.byTooltip('Copy content'));
        await tester.pump();
        expect(copiedText, b64);

        // Show original restores original content and match count 0
        await tester.tap(find.text('Show original'));
        await awaitIsolates(tester);
        expect(find.text('Base64 → gzip → JSON'), findsNothing);
        expect(reportedMatches, 0);
      },
    );

    testWidgets(
      'recognizeHexFallback, emptyValueMarker, and fitTreeHeight work as specified',
      (tester) async {
        const rawHex = '0x1f8b08000000';

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    JsonOrStringViewer(
                      rawContent: rawHex,
                      recognizeHexFallback: true,
                      treeViewHeight: 200,
                    ),
                    const JsonOrStringViewer(
                      rawContent: '',
                      emptyValueMarker: '<empty>',
                    ),
                    JsonOrStringViewer(
                      rawContent: jsonEncode({
                        for (var i = 0; i < 40; i++) 'k$i': 'v$i',
                      }),
                      fitTreeHeight: true,
                      treeViewHeight: 220,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await awaitIsolates(tester);

        expect(find.byType(HexViewer), findsOneWidget);
        expect(find.text('<empty>'), findsOneWidget);
        expect(find.text('k0: '), findsOneWidget);
      },
    );

    testWidgets('renders German toggle and copy tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: JsonOrStringViewer(rawContent: '{"a": 1}'),
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text('Roh'), findsOneWidget);
      expect(find.text('Baum'), findsOneWidget);
      expect(find.byTooltip('Inhalt kopieren'), findsOneWidget);
    });
  });
}
