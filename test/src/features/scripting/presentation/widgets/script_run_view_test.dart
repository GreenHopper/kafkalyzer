import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_run_view.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  @override
  bool isRunning = false;

  @override
  Map<String, StepStatus> stepStatuses = {};

  @override
  Map<String, StepStatus> topicStatuses = {};

  @override
  Map<String, String> stepErrorMessages = {};

  Map<String, String> variableValues = {};

  final Map<String, int> matchCounts = {};

  @override
  Future<ScriptRun?> runScript(
    Script script,
    Map<String, String> variableValues, {
    ClusterProfile? overrideCluster,
  }) async {
    isRunning = true;
    for (var step in script.steps) {
      stepStatuses[step.id] = StepStatus.pending;
      for (var topic in step.topicNames) {
        topicStatuses["${step.id}_$topic"] = StepStatus.pending;
      }
    }
    notifyListeners();
    return null;
  }

  void setStepStatus(String id, StepStatus status) {
    stepStatuses[id] = status;
    notifyListeners();
  }

  void setTopicStatus(String stepId, String topic, StepStatus status) {
    topicStatuses["${stepId}_$topic"] = status;
    notifyListeners();
  }

  void setRunning(bool running) {
    isRunning = running;
    notifyListeners();
  }

  @override
  Future<void> cancelScript() async {
    isRunning = false;
    notifyListeners();
  }

  @override
  SearchProgress? getProgress(String stepId, String topic) {
    return null;
  }

  @override
  Future<List<ScriptRun>> getPastRuns(Script script) async {
    return [];
  }

  @override
  int getMatchCount(String stepId, String topic) {
    return matchCounts["${stepId}_$topic"] ?? 0;
  }

  void setMatchCount(String stepId, String topic, int count) {
    matchCounts["${stepId}_$topic"] = count;
    notifyListeners();
  }

  @override
  MultiSearchController get multiSearchController =>
      FakeMultiSearchController();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMultiSearchController extends ChangeNotifier
    implements MultiSearchController {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeClusterListController extends ChangeNotifier
    implements ClusterListController {
  @override
  List<ClusterProfile> get clusters => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeScriptRunner fakeRunner;

  setUp(() {
    fakeRunner = FakeScriptRunner();
    getIt.registerSingleton<ScriptRunner>(fakeRunner);
    getIt.registerSingleton<ClusterListController>(FakeClusterListController());
    // Also need MultiSearchController if ScriptMonitorView depends on it?
    // ScriptMonitorView depends on ScriptRunner mostly.
    // ScriptRunView internal calls might need others?
    // ScriptRunView uses ClusterListController (mocked above).
  });

  tearDown(() {
    getIt.reset();
  });

  const script = Script(
    id: '1',
    name: 'Test Script',
    steps: [
      ScriptStep(
        id: 's1',
        name: 'Step 1',
        clusterName: 'c1',
        topicNames: ['t1'],
      ),
    ],
  );

  testWidgets('ScriptRunView switches to monitor on run', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ScriptRunView(script: script)),
      ),
    );

    expect(find.text('Configuration'), findsOneWidget);
    expect(find.text('Run'), findsOneWidget);

    // Tap Run
    await tester.tap(find.text('Run'));
    await tester.pump(); // Start run
    await tester.pump(const Duration(milliseconds: 200)); // animation

    expect(fakeRunner.isRunning, isTrue);
    expect(find.text('Stop'), findsOneWidget);

    // Update status to Running
    fakeRunner.setStepStatus('s1', StepStatus.running);
    fakeRunner.setTopicStatus('s1', 't1', StepStatus.running);
    await tester.pump(); // Start rebuild
    await tester.pump(); // Start rebuild

    // With the Key trick, it should be expanded now
    expect(find.text('t1'), findsOneWidget);
    expect(
      find.text(
        'RUNNING',
      ), // Localization might change case? Check implementation.
      findsNWidgets(2),
    ); // One for step, one for topic

    // Tap Stop
    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(fakeRunner.isRunning, isFalse);
    expect(find.text('New Run'), findsOneWidget);
  });

  testWidgets('ScriptRunView displays match counts for completed steps', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ScriptRunView(script: script)),
      ),
    );

    await tester.tap(find.text('Run'));
    await tester.pump();

    // Set match counts
    fakeRunner.setMatchCount('s1', 't1', 5);
    fakeRunner.setStepStatus('s1', StepStatus.completed);
    fakeRunner.setTopicStatus('s1', 't1', StepStatus.completed);
    await tester.pump();

    // Verify match count text
    // "5 matches found in 1 topics"
    expect(find.text('5 matches found in 1 topics'), findsOneWidget);
  });
}
