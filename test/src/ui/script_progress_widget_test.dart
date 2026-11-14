import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/ui/script_progress_widget.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class FakeMultiSearchController extends ChangeNotifier
    implements MultiSearchController {
  @override
  int get bufferLimit => 50000;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeScriptRunner extends ChangeNotifier implements ScriptRunner {
  @override
  bool isRunning = false;

  @override
  Map<String, StepStatus> stepStatuses = {};

  @override
  Map<String, StepStatus> topicStatuses = {};

  @override
  Map<String, String> stepErrorMessages = {};

  final Map<String, int> matchCounts = {};
  final Map<String, int> droppedCounts = {};

  @override
  SearchProgress? getProgress(String stepId, String topic) => null;

  @override
  int getMatchCount(String stepId, String topic) {
    return matchCounts["${stepId}_$topic"] ?? 0;
  }

  @override
  int getDroppedCount(String stepId, String topic) {
    return droppedCounts["${stepId}_$topic"] ?? 0;
  }

  @override
  final MultiSearchController multiSearchController =
      FakeMultiSearchController();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testScript = Script(
    id: 'script-123',
    name: 'Backup Log Script',
    concurrencyLimit: 2,
    steps: [
      ScriptStep(
        id: 'step-a',
        name: 'Download Data',
        clusterName: 'local-cluster',
        topicNames: ['topic-logs', 'topic-errors'],
      ),
    ],
  );

  Widget createWidgetUnderTest(
    Script script,
    ScriptRunner runner, {
    String? title,
    Locale? locale,
  }) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en'), Locale('de')],
      home: Scaffold(
        body: SingleChildScrollView(
          child: ScriptProgressWidget(
            script: script,
            runner: runner,
            title: title,
          ),
        ),
      ),
    );
  }

  testWidgets('renders title, steps, and progress tile statuses', (
    WidgetTester tester,
  ) async {
    final runner = FakeScriptRunner();
    runner.stepStatuses['step-a'] = StepStatus.running;
    runner.topicStatuses['step-a_topic-logs'] = StepStatus.running;
    runner.topicStatuses['step-a_topic-errors'] = StepStatus.pending;

    await tester.pumpWidget(
      createWidgetUnderTest(testScript, runner, title: 'Script Status Title'),
    );
    await tester.pump(); // Pump once to build layout

    // Verify Title and Step Name
    expect(find.text('Script Status Title'), findsOneWidget);
    expect(find.text('Download Data'), findsOneWidget);

    // Verify Status Text
    expect(find.text('RUNNING'), findsNWidgets(2));

    // Verify progress tiles
    expect(find.byType(TopicProgressTile), findsNWidgets(2));
    expect(find.text('topic-logs'), findsOneWidget);
    expect(find.text('topic-errors'), findsOneWidget);
  });

  testWidgets('renders completed step matches count', (
    WidgetTester tester,
  ) async {
    final runner = FakeScriptRunner();
    runner.stepStatuses['step-a'] = StepStatus.completed;
    runner.topicStatuses['step-a_topic-logs'] = StepStatus.completed;
    runner.topicStatuses['step-a_topic-errors'] = StepStatus.completed;
    runner.matchCounts['step-a_topic-logs'] = 15;
    runner.matchCounts['step-a_topic-errors'] = 5;

    await tester.pumpWidget(createWidgetUnderTest(testScript, runner));
    await tester.pump();

    expect(find.text('COMPLETED'), findsOneWidget);
    // "20 matches found in 2 topics"
    expect(find.text('20 matches found in 2 topics'), findsOneWidget);
  });

  testWidgets('renders step error message', (WidgetTester tester) async {
    final runner = FakeScriptRunner();
    runner.stepStatuses['step-a'] = StepStatus.error;
    runner.stepErrorMessages['step-a'] = 'Connection timeout';

    await tester.pumpWidget(createWidgetUnderTest(testScript, runner));
    await tester.pump();

    expect(find.text('FAILED'), findsOneWidget);
    expect(find.text('Connection timeout'), findsOneWidget);
  });

  testWidgets('renders dropped messages indicator when a topic has drops', (
    WidgetTester tester,
  ) async {
    final runner = FakeScriptRunner();
    runner.stepStatuses['step-a'] = StepStatus.running;
    runner.topicStatuses['step-a_topic-logs'] = StepStatus.completed;
    runner.topicStatuses['step-a_topic-errors'] = StepStatus.completed;
    runner.matchCounts['step-a_topic-logs'] = 51500;
    runner.droppedCounts['step-a_topic-logs'] = 1500;

    await tester.pumpWidget(createWidgetUnderTest(testScript, runner));
    await tester.pump();

    expect(
      find.text('1,500 oldest messages dropped (limit 50,000)'),
      findsOneWidget,
    );
  });

  testWidgets('renders German localization and plural matches', (
    WidgetTester tester,
  ) async {
    final runner = FakeScriptRunner();
    runner.stepStatuses['step-a'] = StepStatus.completed;
    runner.topicStatuses['step-a_topic-logs'] = StepStatus.completed;
    runner.topicStatuses['step-a_topic-errors'] = StepStatus.completed;
    runner.matchCounts['step-a_topic-logs'] = 1;
    runner.matchCounts['step-a_topic-errors'] = 0;

    await tester.pumpWidget(
      createWidgetUnderTest(testScript, runner, locale: const Locale('de')),
    );
    await tester.pump();

    expect(find.text('ABGESCHLOSSEN'), findsOneWidget);
    expect(find.text('1 Treffer in 1 Topic gefunden'), findsOneWidget);
  });
}
