import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_run_sidebar.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:material_ui/material_ui.dart';

const _steps = [
  ScriptStep(
    id: 's1',
    name: 'ExtractOrders',
    clusterName: 'c1',
    topicNames: ['orders'],
  ),
];

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('shows run summary for a selected run', (tester) async {
    const run = ScriptRun(
      id: 'run-1',
      scriptName: 'Demo',
      timestamp: 1695888000000,
      parameters: {},
      status: ScriptRunStatus.completed,
      path: '/tmp/run-1',
      clusterName: 'prod',
      totalExamined: 12,
      startTime: 1695888000000,
      endTime: 1695888005000,
    );

    await tester.pumpWidget(
      _wrap(
        ScriptRunSidebar(
          run: run,
          scriptSteps: _steps,
          groupedResults: const {},
          totalMessages: 2,
          selectedTopics: const {},
          parameterFilters: const {},
          onTopicToggle: (_, _) {},
          onClearSelection: () {},
          onParameterFilterChanged: (_, _) {},
          onStepToggle: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Run Summary'), findsOneWidget);
    expect(find.textContaining('Cluster:'), findsOneWidget);
    expect(find.textContaining('prod'), findsOneWidget);
  });

  testWidgets('missing cluster uses default label, not a blank success', (
    tester,
  ) async {
    const run = ScriptRun(
      id: 'run-2',
      scriptName: 'Demo',
      timestamp: 1695888000000,
      parameters: {},
      status: ScriptRunStatus.error,
      path: '/tmp/run-2',
      error: 'broker unreachable',
    );

    await tester.pumpWidget(
      _wrap(
        ScriptRunSidebar(
          run: run,
          scriptSteps: _steps,
          groupedResults: const {},
          totalMessages: 0,
          selectedTopics: const {},
          parameterFilters: const {},
          onTopicToggle: (_, _) {},
          onClearSelection: () {},
          onParameterFilterChanged: (_, _) {},
          onStepToggle: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Run Summary'), findsOneWidget);
    expect(find.textContaining('Default'), findsOneWidget);
    expect(find.textContaining('broker unreachable'), findsNothing);
  });

  testWidgets('lists step topics from grouped results and parameters', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const run = ScriptRun(
      id: 'run-3',
      scriptName: 'Demo',
      timestamp: 1695888000000,
      parameters: {'region': 'eu-west,us-east'},
      status: ScriptRunStatus.completed,
      path: '/tmp/run-3',
      clusterName: 'prod',
      totalExamined: 20,
      topicExamined: {'s1_orders': 20},
      startTime: 1695888000000,
      endTime: 1695888015000,
    );
    const msg = KafkaMessage(
      topic: 'orders',
      partition: 0,
      offset: 1,
      timestamp: 1695888000000,
      payload: '{}',
    );

    await tester.pumpWidget(
      _wrap(
        ScriptRunSidebar(
          run: run,
          scriptSteps: _steps,
          groupedResults: const {
            's1': {
              'orders': [msg],
            },
          },
          totalMessages: 1,
          selectedTopics: const {},
          parameterFilters: const {},
          onTopicToggle: (_, _) {},
          onClearSelection: () {},
          onParameterFilterChanged: (_, _) {},
          onStepToggle: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ExtractOrders'), findsOneWidget);
    expect(find.textContaining('orders'), findsWidgets);
    expect(find.text('Parameters'), findsOneWidget);
    expect(find.textContaining('region'), findsOneWidget);
  });

  testWidgets('orphan step keys show under Other results', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const run = ScriptRun(
      id: 'run-4',
      scriptName: 'Demo',
      timestamp: 1695888000000,
      parameters: {},
      status: ScriptRunStatus.completed,
      path: '/tmp/run-4',
      clusterName: 'prod',
      topicExamined: {'orphan_legacy': 3},
    );
    const msg = KafkaMessage(
      topic: 'legacy',
      partition: 0,
      offset: 1,
      timestamp: 1695888000000,
      payload: '{}',
    );

    await tester.pumpWidget(
      _wrap(
        ScriptRunSidebar(
          run: run,
          scriptSteps: _steps,
          groupedResults: const {
            'orphan': {
              'legacy': [msg],
            },
          },
          totalMessages: 1,
          selectedTopics: const {},
          parameterFilters: const {},
          onTopicToggle: (_, _) {},
          onClearSelection: () {},
          onParameterFilterChanged: (_, _) {},
          onStepToggle: (_, _) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Other Results'), findsOneWidget);
    expect(find.textContaining('legacy'), findsWidgets);
  });
}
