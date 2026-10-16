import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_run_view.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';
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

  Widget buildTestWidget(Script testScript) {
    return MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        splashFactory: InkRipple.splashFactory,
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ScriptRunView(script: testScript)),
    );
  }

  testWidgets('ScriptRunView switches to monitor on run', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(script));
    await tester.pumpAndSettle();

    expect(find.text('Parameters & Execution'), findsOneWidget);
    expect(find.text('Pipeline Preview'), findsOneWidget);
    expect(find.text('Run Script (1 step)'), findsOneWidget);

    // Tap Run button
    await tester.tap(find.text('Run Script (1 step)'));
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
    expect(find.text('RUNNING'), findsNWidgets(2)); // One for step, one for topic

    // Tap Stop
    await tester.tap(find.text('Stop'));
    await tester.pump();

    expect(fakeRunner.isRunning, isFalse);
    expect(find.text('New Run'), findsOneWidget);
  });

  testWidgets('ScriptRunView displays match counts for completed steps', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(script));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Run Script (1 step)'));
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

  testWidgets('renders responsive two-column layout on wide screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const detailedScript = Script(
      id: '2',
      name: 'Order Pipeline',
      steps: [
        ScriptStep(
          id: 's1',
          name: 'Find Order',
          clusterName: 'c1',
          topicNames: ['orders-in'],
          filterTemplate: '{{orderId}}',
          extractions: [
            ScriptExtraction(
              jsonPath: r'$.customerId',
              variableName: 'customerId',
            ),
          ],
        ),
        ScriptStep(
          id: 's2',
          name: 'Track Payment',
          clusterName: 'c1',
          topicNames: ['payments'],
        ),
      ],
    );

    await tester.pumpWidget(buildTestWidget(detailedScript));
    await tester.pumpAndSettle();

    // Verify 2-column headers and badges
    expect(find.text('Parameters & Execution'), findsOneWidget);
    expect(find.text('Pipeline Preview'), findsOneWidget);
    expect(find.text('2 Steps'), findsOneWidget);
    expect(find.text('Run Script (2 steps)'), findsOneWidget);

    // Verify parameter card constraints: maxWidth 540
    final constrainedBox = tester.widget<ConstrainedBox>(
      find.ancestor(
        of: find.text('Parameters & Execution'),
        matching: find.byType(ConstrainedBox),
      ).first,
    );
    expect(constrainedBox.constraints.maxWidth, 540);

    // Verify pipeline preview content
    expect(find.text('Find Order'), findsOneWidget);
    expect(find.text('Track Payment'), findsOneWidget);
    expect(find.text('orders-in'), findsOneWidget);
    expect(find.text('payments'), findsOneWidget);
    expect(find.text('Filter: {{orderId}}'), findsOneWidget);
    expect(find.text('Extracted: customerId'), findsOneWidget);
  });

  testWidgets('renders stacked single-column layout on narrow screens', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(700, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(script));
    await tester.pumpAndSettle();

    expect(find.text('Parameters & Execution'), findsOneWidget);
    expect(find.text('Pipeline Preview'), findsOneWidget);
    expect(find.text('Run Script (1 step)'), findsOneWidget);

    // Verify layout inside SingleChildScrollView is Column
    final scrollView = find.byType(SingleChildScrollView);
    expect(scrollView, findsOneWidget);

    final columnInsideScroll = find.descendant(
      of: scrollView,
      matching: find.byType(Column),
    );
    expect(columnInsideScroll, findsWidgets);
  });

  testWidgets('displays variable inputs with clean type indicators and icons', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const scriptWithVars = Script(
      id: '3',
      name: 'Config Script',
      variables: [
        ScriptVariable(name: 'userQuery', type: ScriptVariableType.string),
        ScriptVariable(name: 'batchSize', type: ScriptVariableType.numeric),
        ScriptVariable(name: 'startTime', type: ScriptVariableType.timestamp),
      ],
      steps: [
        ScriptStep(id: 's1', name: 'Step 1', clusterName: 'c1'),
      ],
    );

    await tester.pumpWidget(buildTestWidget(scriptWithVars));
    await tester.pumpAndSettle();

    // Verify clean type badges
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Numeric'), findsOneWidget);

    // Verify TimestampPickerField is rendered for timestamp variable
    expect(find.byType(TimestampPickerField), findsOneWidget);

    // Verify prefix icons
    expect(find.byIcon(Icons.short_text), findsOneWidget);
    expect(find.byIcon(Icons.numbers), findsOneWidget);
  });

  testWidgets('displays empty state when script has no steps', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const emptyScript = Script(
      id: '4',
      name: 'Empty Script',
      steps: [],
    );

    await tester.pumpWidget(buildTestWidget(emptyScript));
    await tester.pumpAndSettle();

    expect(find.text('Pipeline Preview'), findsOneWidget);
    expect(find.text('0 Steps'), findsOneWidget);
    expect(
      find.text(
        'No execution steps configured. Use the Edit tab to add steps.',
      ),
      findsOneWidget,
    );
    expect(find.text('Run Script (0 steps)'), findsOneWidget);
  });
}
