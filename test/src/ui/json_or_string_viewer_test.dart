import 'package:kafkalyzer/src/ui/hex_viewer.dart';
import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> awaitIsolates(WidgetTester tester) async {
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
  await tester.runAsync(() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
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

    testWidgets('renders Cards view by default for valid json', (tester) async {
      final jsonStr = '{"key": "value"}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(title: 'Test Viewer', rawContent: jsonStr),
          ),
        ),
      );
      await awaitIsolates(tester);

      expect(find.text('KEY'), findsOneWidget); // Card view uppercases keys
      expect(find.text('value'), findsOneWidget);
      expect(find.byType(ToggleButtons), findsOneWidget);

      final toggleButtons = tester.widget<ToggleButtons>(
        find.byType(ToggleButtons),
      );
      expect(toggleButtons.isSelected[2], isTrue);
    });

    testWidgets('switches to Raw view', (tester) async {
      final jsonStr = '{"key": "value"}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: JsonOrStringViewer(title: 'Test Viewer', rawContent: jsonStr),
          ),
        ),
      );

      await tester.tap(find.text('Raw'));
      await awaitIsolates(tester);

      expect(find.text(jsonStr), findsOneWidget);
    });

    testWidgets('persistence restores view mode', (tester) async {
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
    });

    testWidgets('renders Tree view and cycles search results', (tester) async {
      final jsonStr = '{"user": {"name": "Alice", "age": 30}}';
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

      expect(find.text('user'), findsOneWidget);
      expect(find.text('name'), findsOneWidget);
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
      final selectableTextFinder = find.byType(SelectableText);
      expect(selectableTextFinder, findsOneWidget);
      final text = tester.widget<SelectableText>(selectableTextFinder).data!;
      expect(text, contains('48 65 6c 6c 6f'));
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
      expect(find.text('DIRECT'), findsOneWidget);
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
      expect(find.text('B'), findsOneWidget);
    });
  });
}
