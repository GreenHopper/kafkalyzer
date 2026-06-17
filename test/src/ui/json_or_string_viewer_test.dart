import 'package:kafkalyzer/src/ui/json_or_string_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

      expect(find.text('Test Viewer'), findsOneWidget);
      expect(find.text('Not a JSON string'), findsOneWidget);
      // Toggle buttons should not be visible or only Raw enabled?
      // Logic: if !isValidJson, ToggleButtons might be hidden or just Raw selected.
      // Implementation: if (_isValidJson) ... ToggleButtons
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

      expect(find.text('KEY'), findsOneWidget); // Card view uppercases keys
      expect(find.text('value'), findsOneWidget);
      expect(find.byType(ToggleButtons), findsOneWidget);

      // Verify "Cards" is selected (index 2)
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

      // Tap "Raw" (index 0)
      await tester.tap(find.text('Raw'));
      await tester.pumpAndSettle();

      expect(find.text(jsonStr), findsOneWidget);
      // Should basically see the raw string rendering
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
      await tester.pumpAndSettle(); // Allow async restore

      final toggleButtons = tester.widget<ToggleButtons>(
        find.byType(ToggleButtons),
      );
      expect(toggleButtons.isSelected[0], isTrue); // Raw selected
    });
  });
}
