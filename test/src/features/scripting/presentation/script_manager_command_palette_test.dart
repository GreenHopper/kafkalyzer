import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/script_manager_view.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeClusterList extends ChangeNotifier implements ClusterListController {
  @override
  List<ClusterProfile> get clusters => const [];

  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeActiveConn extends ChangeNotifier
    implements ActiveConnectionController {
  @override
  ClusterProfile? get activeProfile => null;

  @override
  bool get isConnecting => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SpyScriptRunner extends ChangeNotifier implements ScriptRunner {
  _SpyScriptRunner({this.running = false, this.run});

  final bool running;
  final ScriptRun? run;
  int runScriptCalls = 0;
  int cancelCalls = 0;

  @override
  bool get isRunning => running;

  @override
  ScriptRun? get currentRun => run;

  @override
  Future<List<ScriptRun>> getPastRuns(Script script) async => <ScriptRun>[];

  Future<void> cancel() async {
    cancelCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #runScript) {
      runScriptCalls++;
      return Future<ScriptRun?>.value(null);
    }
    return super.noSuchMethod(invocation);
  }
}

void main() {
  const script1 = Script(id: 'script-1', name: 'Demo Script');
  const script2 = Script(id: 'script-2', name: 'Analytics Pipeline');

  late MainNavigationController nav;
  late _SpyScriptRunner runner;

  setUp(() async {
    await GetIt.instance.reset();
    SharedPreferences.setMockInitialValues({
      'saved_scripts_v1': jsonEncode([script1.toJson(), script2.toJson()]),
    });
    nav = MainNavigationController();
    runner = _SpyScriptRunner();
    GetIt.instance.registerSingleton<Logger>(Logger());
    GetIt.instance.registerSingleton<ClusterListController>(_FakeClusterList());
    GetIt.instance.registerSingleton<ActiveConnectionController>(
      _FakeActiveConn(),
    );
    GetIt.instance.registerSingleton<ScriptRepository>(ScriptRepository());
    GetIt.instance.registerSingleton<ScriptRunner>(runner);
    GetIt.instance.registerSingleton<ScriptController>(ScriptController());
    GetIt.instance.registerSingleton<MainNavigationController>(nav);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Widget buildApp() {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ScriptManagerView()),
    );
  }

  testWidgets('opens requested script on Run tab without starting it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    nav.openScript('script-2');
    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Analytics Pipeline'), findsWidgets);
    expect(runner.runScriptCalls, 0);

    // Unknown script shows SnackBar
    nav.openScript('missing-script');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Script not found'), findsOneWidget);
    expect(runner.runScriptCalls, 0);
  });

  testWidgets('opening another script keeps a running script running', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final runningRunner = _SpyScriptRunner(
      running: true,
      run: ScriptRun(
        id: 'run-1',
        scriptName: 'Demo Script',
        timestamp: 1000,
        parameters: const {},
        status: ScriptRunStatus.running,
        path: 'demo.lua',
        clusterName: 'prod',
        startTime: 1000,
        scriptSnapshot: script1,
      ),
    );
    await GetIt.instance.unregister<ScriptRunner>();
    GetIt.instance.registerSingleton<ScriptRunner>(runningRunner);

    await tester.pumpWidget(buildApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    nav.openScript('script-2');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Analytics Pipeline'), findsWidgets);
    expect(runningRunner.runScriptCalls, 0);
    expect(runningRunner.cancelCalls, 0);
    expect(runningRunner.isRunning, isTrue);
  });
}
