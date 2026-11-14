import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide StepState;
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/connection_diagnostics_panel.dart';
import 'package:kafkalyzer/src/rust/api/connection_diagnostics.dart';

Widget _wrapWithL10n(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets('renders all-ok diagnosis with all five stages', (tester) async {
    final diagnosis = ConnectionDiagnosis(
      outcome: DiagnosisOutcome.ok,
      stages: const [
        StageResult(
          stage: DiagnosisStage.network,
          state: StageState.ok,
          servers: [
            ServerCheck(
              entry: 'localhost:9092',
              dns: StepState.ok,
              addresses: ['127.0.0.1:9092'],
              tcp: StepState.ok,
              connectedAddress: '127.0.0.1:9092',
            ),
          ],
        ),
        StageResult(
          stage: DiagnosisStage.tls,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.authentication,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.metadata,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.schemaRegistry,
          state: StageState.ok,
          servers: [],
        ),
      ],
      unattributed: const [],
      elapsedMs: BigInt.from(42),
    );

    await tester.pumpWidget(
      _wrapWithL10n(ConnectionDiagnosticsPanel(diagnosis: diagnosis)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Connection succeeded across all applicable stages'),
      findsOneWidget,
    );
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('TLS'), findsOneWidget);
    expect(find.text('Authentication'), findsOneWidget);
    expect(find.text('Metadata'), findsOneWidget);
    expect(find.text('Schema Registry'), findsOneWidget);
    expect(find.text('OK'), findsNWidgets(5));
  });

  testWidgets('renders PLAINTEXT diagnosis with not-applicable stages', (
    tester,
  ) async {
    final diagnosis = ConnectionDiagnosis(
      outcome: DiagnosisOutcome.ok,
      stages: const [
        StageResult(
          stage: DiagnosisStage.network,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.tls,
          state: StageState.notApplicable,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.authentication,
          state: StageState.notApplicable,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.metadata,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.schemaRegistry,
          state: StageState.notApplicable,
          servers: [],
        ),
      ],
      unattributed: const [],
      elapsedMs: BigInt.from(15),
    );

    await tester.pumpWidget(
      _wrapWithL10n(ConnectionDiagnosticsPanel(diagnosis: diagnosis)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Connection succeeded across all applicable stages'),
      findsOneWidget,
    );
    expect(find.text('Not applicable'), findsNWidgets(3));
    expect(find.text('OK'), findsNWidgets(2));
  });

  testWidgets('renders failure with localized hint and selectable raw error', (
    tester,
  ) async {
    final diagnosis = ConnectionDiagnosis(
      outcome: DiagnosisOutcome.failed,
      stages: const [
        StageResult(
          stage: DiagnosisStage.network,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.tls,
          state: StageState.failed,
          hint: DiagnosisHint.certificateRejected,
          raw: 'SSL handshake failed: certificate verify failed',
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.authentication,
          state: StageState.notChecked,
          notCheckedReason: NotCheckedReason.previousStageFailed,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.metadata,
          state: StageState.notChecked,
          notCheckedReason: NotCheckedReason.previousStageFailed,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.schemaRegistry,
          state: StageState.notChecked,
          notCheckedReason: NotCheckedReason.previousStageFailed,
          servers: [],
        ),
      ],
      unattributed: const [],
      elapsedMs: BigInt.from(120),
    );

    await tester.pumpWidget(
      _wrapWithL10n(ConnectionDiagnosticsPanel(diagnosis: diagnosis)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connection failed at stage: TLS'), findsOneWidget);
    expect(
      find.text(
        'Certificate verification failed — check truststore/CA or hostname',
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.data == 'SSL handshake failed: certificate verify failed',
      ),
      findsOneWidget,
    );
    expect(find.text('Skipped because TLS failed'), findsNWidgets(3));
  });

  testWidgets(
    'renders failedStageUnknown without marking any stage as failed',
    (tester) async {
      final diagnosis = ConnectionDiagnosis(
        outcome: DiagnosisOutcome.failedStageUnknown,
        stages: const [
          StageResult(
            stage: DiagnosisStage.network,
            state: StageState.ok,
            servers: [],
          ),
          StageResult(
            stage: DiagnosisStage.tls,
            state: StageState.undetermined,
            servers: [],
          ),
          StageResult(
            stage: DiagnosisStage.authentication,
            state: StageState.undetermined,
            servers: [],
          ),
          StageResult(
            stage: DiagnosisStage.metadata,
            state: StageState.undetermined,
            servers: [],
          ),
          StageResult(
            stage: DiagnosisStage.schemaRegistry,
            state: StageState.notChecked,
            notCheckedReason: NotCheckedReason.budgetExhausted,
            servers: [],
          ),
        ],
        unattributed: const ['Unexpected internal error'],
        elapsedMs: BigInt.from(25000),
      );

      await tester.pumpWidget(
        _wrapWithL10n(ConnectionDiagnosticsPanel(diagnosis: diagnosis)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connection failed, stage unknown'), findsOneWidget);
      expect(find.text('Failed'), findsNothing);
      expect(find.text('Undetermined'), findsNWidgets(3));
      expect(
        find.text('Skipped because the diagnosis time budget ran out'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is SelectableText && w.data == 'Unexpected internal error',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('expands network stage to show per-server DNS and TCP rows', (
    tester,
  ) async {
    final diagnosis = ConnectionDiagnosis(
      outcome: DiagnosisOutcome.ok,
      stages: const [
        StageResult(
          stage: DiagnosisStage.network,
          state: StageState.ok,
          servers: [
            ServerCheck(
              entry: 'broker-1:9092',
              dns: StepState.ok,
              addresses: ['10.0.0.1:9092', '10.0.0.2:9092'],
              tcp: StepState.ok,
              connectedAddress: '10.0.0.1:9092',
            ),
            ServerCheck(
              entry: 'broker-2:9092',
              dns: StepState.failed,
              addresses: [],
              tcp: StepState.notChecked,
              hint: DiagnosisHint.hostUnknown,
              raw: 'failed to lookup address information',
            ),
          ],
        ),
        StageResult(
          stage: DiagnosisStage.tls,
          state: StageState.notApplicable,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.authentication,
          state: StageState.notApplicable,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.metadata,
          state: StageState.ok,
          servers: [],
        ),
        StageResult(
          stage: DiagnosisStage.schemaRegistry,
          state: StageState.notApplicable,
          servers: [],
        ),
      ],
      unattributed: const [],
      elapsedMs: BigInt.from(95),
    );

    await tester.pumpWidget(
      _wrapWithL10n(ConnectionDiagnosticsPanel(diagnosis: diagnosis)),
    );
    await tester.pumpAndSettle();

    // Initially collapsed when Network state is ok
    expect(find.text('broker-1:9092'), findsNothing);

    await tester.tap(find.text('Network'));
    await tester.pumpAndSettle();

    expect(find.text('broker-1:9092'), findsOneWidget);
    expect(find.text('broker-2:9092'), findsOneWidget);
    expect(find.text('Resolved: 10.0.0.1:9092, 10.0.0.2:9092'), findsOneWidget);
    expect(find.text('Connected to 10.0.0.1:9092'), findsOneWidget);
    expect(find.text('Host name could not be resolved'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (w) =>
            w is SelectableText &&
            w.data == 'failed to lookup address information',
      ),
      findsOneWidget,
    );
  });
}
