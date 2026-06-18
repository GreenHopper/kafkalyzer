import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/view_mode_switcher.dart';

void main() {
  Widget createWidgetUnderTest({
    required String activeView,
    required ValueChanged<String> onViewChanged,
    bool showSchemaView = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ViewModeSwitcher(
          activeView: activeView,
          onViewChanged: onViewChanged,
          showSchemaView: showSchemaView,
        ),
      ),
    );
  }

  testWidgets('renders correct selected state and triggers callbacks', (
    WidgetTester tester,
  ) async {
    String changedView = "";

    await tester.pumpWidget(
      createWidgetUnderTest(
        activeView: 'timeline',
        onViewChanged: (val) => changedView = val,
        showSchemaView: true,
      ),
    );

    // Verify correct toggled buttons count (4 buttons: table, timeline, diff, schema)
    final toggleButtons = tester.widget<ToggleButtons>(
      find.byType(ToggleButtons),
    );
    expect(toggleButtons.isSelected, [false, true, false, false]);

    // Tap table icon (index 0)
    await tester.tap(find.byIcon(Icons.table_chart));
    await tester.pump();
    expect(changedView, 'table');

    // Tap diff icon (index 2)
    await tester.tap(find.byIcon(Icons.difference));
    await tester.pump();
    expect(changedView, 'diff');

    // Tap schema icon (index 3)
    await tester.tap(find.byIcon(Icons.data_object));
    await tester.pump();
    expect(changedView, 'schema');
  });

  testWidgets('hides schema view if showSchemaView is false', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        activeView: 'timeline',
        onViewChanged: (_) {},
        showSchemaView: false,
      ),
    );

    final toggleButtons = tester.widget<ToggleButtons>(
      find.byType(ToggleButtons),
    );
    expect(toggleButtons.isSelected, [false, true, false]);
    expect(find.byIcon(Icons.data_object), findsNothing);
  });
}
