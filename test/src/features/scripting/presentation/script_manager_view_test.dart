import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/script_manager_view.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  @override
  bool get isRunning => false;

  @override
  ScriptRun? get currentRun => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testScript = Script(id: 'script-1', name: 'Demo Script', steps: []);
  const testScript2 =
      Script(id: 'script-2', name: 'Analytics Pipeline', steps: []);

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({
      'saved_scripts_v1': jsonEncode([
        testScript.toJson(),
        testScript2.toJson(),
      ]),
    });
    getIt.registerSingleton<Logger>(Logger());
    getIt.registerSingleton<ScriptRepository>(ScriptRepository());
    getIt.registerSingleton<ScriptRunner>(FakeScriptRunner());
    getIt.registerSingleton<ScriptController>(ScriptController());
    // Allow ScriptController.loadScripts to finish
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await getIt.reset();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: ScriptManagerView()),
    );
  }

  testWidgets('collapses and expands script catalog via toggle buttons', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsOneWidget);
    expect(find.text('Demo Script'), findsOneWidget);
    expect(find.byKey(const Key('script_collapse_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('script_collapse_sidebar')));
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsNothing);
    expect(find.text('Demo Script'), findsNothing);
    expect(find.byKey(const Key('script_expand_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('script_expand_sidebar')));
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsOneWidget);
    expect(find.text('Demo Script'), findsOneWidget);
  });

  testWidgets('Ctrl+B toggles script catalog sidebar', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsNothing);
    expect(find.byKey(const Key('script_expand_sidebar')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsOneWidget);
  });

  testWidgets('persists script catalog collapsed preference', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('script_collapse_sidebar')));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ScriptManagerView.sidebarCollapsedPrefKey), isTrue);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Scripts'), findsNothing);
    expect(find.byKey(const Key('script_expand_sidebar')), findsOneWidget);
  });

  testWidgets('filters script catalog by search query in real time', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Demo Script'), findsOneWidget);
    expect(find.text('Analytics Pipeline'), findsOneWidget);

    // Enter search text
    final searchField = find.byType(TextField);
    expect(searchField, findsOneWidget);
    await tester.enterText(searchField, 'Analytics');
    await tester.pumpAndSettle();

    expect(find.text('Analytics Pipeline'), findsOneWidget);
    expect(find.text('Demo Script'), findsNothing);

    // Clear search using clear button
    final clearButton = find.byIcon(Icons.clear);
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(find.text('Demo Script'), findsOneWidget);
    expect(find.text('Analytics Pipeline'), findsOneWidget);
  });

  testWidgets('canceling delete dialog preserves the script', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Demo Script'), findsOneWidget);

    // Find delete button specifically for Demo Script
    final demoScriptTile = find.ancestor(
      of: find.text('Demo Script'),
      matching: find.byType(ListTile),
    );
    final deleteButton = find.descendant(
      of: demoScriptTile,
      matching: find.byIcon(Icons.delete),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog is shown
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Delete Script?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Demo Script'),
      ),
      findsOneWidget,
    );

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Dialog is closed and Demo Script remains
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Demo Script'), findsOneWidget);
  });

  testWidgets('confirming delete dialog deletes the script', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    expect(find.text('Demo Script'), findsOneWidget);

    // Find delete button specifically for Demo Script
    final demoScriptTile = find.ancestor(
      of: find.text('Demo Script'),
      matching: find.byType(ListTile),
    );
    final deleteButton = find.descendant(
      of: demoScriptTile,
      matching: find.byIcon(Icons.delete),
    );
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Verify confirmation dialog is shown
    expect(find.byType(AlertDialog), findsOneWidget);

    // Tap Delete in dialog (descendant of AlertDialog)
    final deleteConfirmBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('Delete'),
    );
    await tester.tap(deleteConfirmBtn);
    await tester.pumpAndSettle();

    // Dialog closed and Demo Script deleted
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Demo Script'), findsNothing);
    expect(find.text('Analytics Pipeline'), findsOneWidget);
  });
}
