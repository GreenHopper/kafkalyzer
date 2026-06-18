import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_editor.dart';

void main() {
  testWidgets('ScriptEditor adds new variable with selected type', (
    WidgetTester tester,
  ) async {
    Script? savedScript;
    final script = Script(
      id: '1',
      name: 'Test Script',
      variables: [],
      steps: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(
          body: ScriptEditor(
            script: script,
            onSave: (s) {
              savedScript = s;
            },
          ),
        ),
      ),
    );

    // Find input fields
    final nameFinder = find.widgetWithText(TextField, 'New Variable Name');
    // There are multiple add icons (one for step, one for variable).
    // The variable one is in the same row as the text field.
    // We can find the button that is a sibling of the dropdown.

    // Enter variable name
    await tester.enterText(nameFinder, 'myVar');
    await tester.pump();

    // Select type 'numeric'
    // Default is string. Dropdown should show 'string'.
    final dropdownFinder = find.byType(DropdownButton<ScriptVariableType>);
    expect(dropdownFinder, findsOneWidget);

    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle(); // Open menu

    final numericItemFinder = find.text('numeric').last;
    await tester.tap(numericItemFinder);
    await tester.pumpAndSettle(); // Close menu

    // Find add button (the one in the variable row)
    // It's the IconButton after the dropdown.
    final variableAddButton = find.descendant(
      of: find.ancestor(of: nameFinder, matching: find.byType(Row)),
      matching: find.byIcon(Icons.add),
    );

    await tester.tap(variableAddButton);
    await tester.pump();

    // Verify saved script has variable
    expect(savedScript, isNotNull);
    expect(savedScript!.variables.length, 1);
    expect(savedScript!.variables.first.name, 'myVar');
    expect(savedScript!.variables.first.type, ScriptVariableType.numeric);

    // Verify chip shows up (In DataTable now)
    final dataTableFinder = find.byType(DataTable);
    expect(
      find.descendant(of: dataTableFinder, matching: find.text('myVar')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dataTableFinder, matching: find.text('numeric')),
      findsOneWidget,
    );
  });

  testWidgets('ScriptEditor edits existing variable type', (
    WidgetTester tester,
  ) async {
    Script? savedScript;
    final variable = ScriptVariable(
      name: 'oldVar',
      type: ScriptVariableType.string,
    );
    final script = Script(
      id: '1',
      name: 'Test Script',
      variables: [variable],
      steps: [],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(
          body: ScriptEditor(
            script: script,
            onSave: (s) {
              savedScript = s;
            },
          ),
        ),
      ),
    );

    // Find variable in table
    final dataTableFinder = find.byType(DataTable);
    expect(
      find.descendant(of: dataTableFinder, matching: find.text('oldVar')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dataTableFinder, matching: find.text('string')),
      findsOneWidget,
    );

    // Find edit button for this row
    final editButtonFinder = find.descendant(
      of: dataTableFinder,
      matching: find.byIcon(Icons.edit),
    );
    expect(editButtonFinder, findsOneWidget);

    await tester.tap(editButtonFinder);
    await tester.pumpAndSettle(); // Open dialog

    // Change type to timestamp
    final dropdownFinder = find.widgetWithText(
      DropdownButtonFormField<ScriptVariableType>,
      'Type',
    );
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    final timestampItemFinder = find.text('timestamp').last;
    await tester.tap(timestampItemFinder);
    await tester.pumpAndSettle();

    // Save
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(); // Close dialog

    // Verify saved script
    expect(savedScript, isNotNull);
    expect(savedScript!.variables.first.name, 'oldVar');
    expect(savedScript!.variables.first.type, ScriptVariableType.timestamp);

    // Verify chip updated
    expect(
      find.descendant(of: dataTableFinder, matching: find.text('timestamp')),
      findsOneWidget,
    );
  });
}
