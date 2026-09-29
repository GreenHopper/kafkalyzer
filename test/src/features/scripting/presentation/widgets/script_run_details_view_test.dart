import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_details_view.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_inspector_panel.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMessageExportService implements MessageExportService {
  @override
  Future<void> exportMessages(List messages) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  FakeScriptRunner(this.messages);

  final List<ScriptResultMessage> messages;

  @override
  Future<List<ScriptResultMessage>> loadRunResults(ScriptRun run) async {
    return messages;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeScriptRunner fakeRunner;

  const script = Script(
    id: 'script-1',
    name: 'Inspect Script',
    steps: [
      ScriptStep(
        id: 's1',
        name: 'ExtractOrders',
        clusterName: 'c1',
        topicNames: ['orders'],
      ),
    ],
  );

  const run = ScriptRun(
    id: 'run-1',
    scriptName: 'Inspect Script',
    timestamp: 1695888000000,
    parameters: {},
    status: ScriptRunStatus.completed,
    path: '/tmp/run-1',
    scriptSnapshot: script,
  );

  final messages = [
    const ScriptResultMessage(
      topic: 'orders',
      partition: 0,
      offset: 100,
      key: 'order-100',
      payload: '{"item":"alpha"}',
      timestamp: 1695888000000,
      stepName: 'ExtractOrders',
      stepId: 's1',
    ),
    const ScriptResultMessage(
      topic: 'orders',
      partition: 0,
      offset: 101,
      key: 'order-101',
      payload: '{"item":"beta"}',
      timestamp: 1695888005000,
      stepName: 'ExtractOrders',
      stepId: 's1',
    ),
  ];

  setUp(() async {
    await getIt.reset();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    fakeRunner = FakeScriptRunner(messages);
    getIt.registerSingleton<ScriptRunner>(fakeRunner);
    getIt.registerSingleton<Logger>(Logger());
    getIt.registerSingleton<MessageExportService>(FakeMessageExportService());
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets(
    'tapping a script result opens dockable inspector without a modal dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ScriptRunDetailsView(run: run, script: script, onBack: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MessageInspectorPanel), findsNothing);

      await tester.tap(find.text('order-100', findRichText: true).first);
      await tester.pumpAndSettle();

      expect(find.byType(MessageInspectorPanel), findsOneWidget);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets('keyboard J and K step through script execution results', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ScriptRunDetailsView(run: run, script: script, onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('order-100', findRichText: true).first);
    await tester.pumpAndSettle();

    expect(find.byType(MessageInspectorPanel), findsOneWidget);
    expect(find.textContaining('1 of 2'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyJ);
    await tester.pumpAndSettle();

    expect(find.textContaining('2 of 2'), findsOneWidget);
    expect(find.textContaining('order-101'), findsWidgets);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pumpAndSettle();

    expect(find.textContaining('1 of 2'), findsOneWidget);
  });

  testWidgets('toggles run overview sidebar and persists preference', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ScriptRunDetailsView(run: run, script: script, onBack: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Run Summary'), findsOneWidget);
    expect(find.byKey(const Key('script_run_toggle_sidebar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('script_run_toggle_sidebar')));
    await tester.pumpAndSettle();

    expect(find.text('Run Summary'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(ScriptRunDetailsView.sidebarCollapsedPrefKey), isTrue);

    await tester.tap(find.byKey(const Key('script_run_toggle_sidebar')));
    await tester.pumpAndSettle();

    expect(find.text('Run Summary'), findsOneWidget);
  });
}
