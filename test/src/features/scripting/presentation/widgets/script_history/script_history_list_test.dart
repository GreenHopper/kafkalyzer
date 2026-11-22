import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_history/script_history_list.dart';
import 'package:material_ui/material_ui.dart';

class _FakeRunner extends ChangeNotifier implements ScriptRunner {
  ScriptRun? deleted;
  bool throwOnDelete = false;

  @override
  Future<void> deleteRun(ScriptRun run) async {
    if (throwOnDelete) throw StateError('delete failed');
    deleted = run;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _script = Script(
  id: 'script-1',
  name: 'Demo Script',
  steps: [
    ScriptStep(
      id: 's1',
      name: 'Step1',
      clusterName: 'c1',
      topicNames: ['orders'],
    ),
  ],
);

const _run = ScriptRun(
  id: 'run-1',
  scriptName: 'Demo Script',
  timestamp: 1695888000000,
  parameters: {},
  status: ScriptRunStatus.completed,
  path: '/tmp/run-1',
  scriptSnapshot: _script,
  totalMessages: 3,
  totalExamined: 10,
  clusterName: 'c1',
);

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Scaffold(body: SizedBox(width: 800, height: 600, child: child)),
  );
}

void main() {
  testWidgets('empty history shows empty state', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ScriptHistoryList(
          script: _script,
          history: const [],
          onSelect: (_) {},
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No past runs found.'), findsOneWidget);
    expect(find.text('Demo Script'), findsNothing);
  });

  testWidgets('populated history selects a run on tap', (tester) async {
    ScriptRun? selected;
    await tester.pumpWidget(
      _wrap(
        ScriptHistoryList(
          script: _script,
          history: const [_run],
          onSelect: (run) => selected = run,
          onRefresh: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demo Script'), findsOneWidget);
    await tester.tap(find.text('Demo Script'));
    await tester.pumpAndSettle();

    expect(selected?.id, equals('run-1'));
  });

  testWidgets('loading history shows progress indicator', (tester) async {
    await tester.pumpWidget(
      _wrap(
        ScriptHistoryList(
          script: _script,
          history: null,
          onSelect: (_) {},
          onRefresh: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('error run shows parameters and delete confirm cancel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final runner = _FakeRunner();
    var refreshed = false;
    ScriptRun? rerun;
    ScriptRun? loaded;
    const failed = ScriptRun(
      id: 'run-err',
      scriptName: 'Demo Script',
      timestamp: 1695888000000,
      parameters: {'env': 'prod'},
      status: ScriptRunStatus.error,
      path: '/tmp/run-err',
      error: 'boom',
      clusterName: 'c1',
      startTime: 1695888000000,
      endTime: 1695888010000,
      totalMessages: 0,
      totalExamined: 5,
      scriptSnapshot: _script,
    );

    await tester.pumpWidget(
      _wrap(
        ScriptHistoryList(
          script: _script,
          history: const [failed],
          onSelect: (_) {},
          onRefresh: () => refreshed = true,
          onRerun: (r) => rerun = r,
          onLoadRun: (r) => loaded = r,
          runner: runner,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('env: prod'), findsOneWidget);
    expect(find.byIcon(Icons.error), findsOneWidget);

    await tester.tap(find.byTooltip('Run Again'));
    await tester.pumpAndSettle();
    expect(rerun?.id, 'run-err');

    await tester.tap(find.byTooltip('Load Results'));
    await tester.pumpAndSettle();
    expect(loaded?.id, 'run-err');

    await tester.tap(find.byTooltip('Delete Run'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Run Result'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(runner.deleted, isNull);

    await tester.tap(find.byTooltip('Delete Run'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(runner.deleted?.id, 'run-err');
    expect(refreshed, isTrue);
  });
}
