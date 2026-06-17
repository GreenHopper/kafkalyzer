import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TimestampPickerField', () {
    testWidgets('renders correctly with initial value', (tester) async {
      final controller = TextEditingController(text: '1234567890');

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: TimestampPickerField(controller: controller, label: 'Test Label'),
          ),
        ),
      );

      expect(find.text('Test Label'), findsOneWidget);
      expect(find.text('1234567890'), findsOneWidget);
      // Helper text should show the formatted date/epoch info potentially,
      // but that depends on DateFormatUtils behavior which we implicitly test integration with.
    });

    testWidgets('updates controller when inline chip is selected', (tester) async {
      final controller = TextEditingController();
      String? selectedLabel;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: TimestampPickerField(
              controller: controller,
              label: 'Test Label',
              showInlineChips: true,
              onLabelChanged: (label) => selectedLabel = label,
            ),
          ),
        ),
      );

      expect(find.text('1m'), findsOneWidget);
      expect(find.text('5m'), findsOneWidget);

      await tester.tap(find.text('5m'));
      await tester.pumpAndSettle();

      expect(controller.text, isNotEmpty); // Should satisfy a date format
      expect(selectedLabel, '5m');
    });

    testWidgets('opens quick time picker dialog', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: TimestampPickerField(controller: controller, label: 'Test Label'),
          ),
        ),
      );

      final historyIcon = find.byIcon(Icons.history);
      expect(historyIcon, findsOneWidget);

      await tester.tap(historyIcon);
      await tester.pumpAndSettle();

      expect(find.text('Quick Time Selection'), findsOneWidget);
      expect(find.text('Now'), findsOneWidget);
      expect(find.text('5 min ago'), findsOneWidget);
    });
  });
}
