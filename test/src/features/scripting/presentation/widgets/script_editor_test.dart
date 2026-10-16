import 'package:material_ui/material_ui.dart';
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

  testWidgets('ScriptEditor renders compact header with script name and concurrency limit', (
    WidgetTester tester,
  ) async {
    final script = Script(
      id: '1',
      name: 'Batch Export Flow',
      concurrencyLimit: 8,
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
            onSave: (_) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scriptNameField = find.widgetWithText(TextField, 'Batch Export Flow');
    expect(scriptNameField, findsOneWidget);

    final concurrencyField = find.widgetWithText(TextField, '8');
    expect(concurrencyField, findsOneWidget);

    final headerBox = tester.widget<ConstrainedBox>(
      find.ancestor(
        of: scriptNameField,
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(headerBox.constraints.maxWidth, 1200);
  });

  testWidgets('ScriptEditor requires confirmation before deleting a step', (
    WidgetTester tester,
  ) async {
    Script? savedScript;
    final step1 = ScriptStep(
      id: 'step-1',
      name: 'Fetch User Event',
      clusterName: 'Cluster A',
      topicNames: ['users'],
    );
    final step2 = ScriptStep(
      id: 'step-2',
      name: 'Fetch Order Event',
      clusterName: 'Cluster A',
      topicNames: ['orders'],
    );

    final script = Script(
      id: '1',
      name: 'Test Workflow',
      variables: [],
      steps: [step1, step2],
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

    await tester.pumpAndSettle();

    // Verify both steps are visible
    expect(find.text('Fetch User Event'), findsOneWidget);
    expect(find.text('Fetch Order Event'), findsOneWidget);

    // Tap delete on step 1
    final deleteButtons = find.widgetWithIcon(IconButton, Icons.delete);
    expect(deleteButtons, findsNWidgets(2));

    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // Verify confirmation dialog is shown
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete Step?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to delete step "Fetch User Event"? This action cannot be undone.'),
      findsOneWidget,
    );

    // Cancel deletion
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();

    // Verify no deletion occurred
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Fetch User Event'), findsOneWidget);
    expect(find.text('Fetch Order Event'), findsOneWidget);
    expect(savedScript, isNull);

    // Tap delete again and confirm
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    // Verify step 1 was deleted
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Fetch User Event'), findsNothing);
    expect(find.text('Fetch Order Event'), findsOneWidget);
    expect(savedScript, isNotNull);
    expect(savedScript!.steps.length, 1);
    expect(savedScript!.steps.first.name, 'Fetch Order Event');
  });
}
