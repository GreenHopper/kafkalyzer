import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/analysis_scope_dialog.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const profile = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'kafka:9092',
    tlsVerification: TlsVerification.enabled,
  );
  const topic = TopicMetadata(
    name: 'orders',
    partitionCount: 4,
    replicationFactor: 3,
    cleanupPolicy: 'compact',
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('AnalysisScopeDialog (6.2)', () {
    testWidgets(
      'invalid count, invalid timestamp, start>=end, and no partitions show inline error and disable Apply',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        AnalysisScope? result;
        await tester.pumpWidget(
          wrap(
            Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await AnalysisScopeDialog.show(
                    context,
                    initialScope: const AnalysisScope(
                      limitFrom: ScopeLimitFrom.newest,
                    ),
                    partitionCount: 4,
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Switch to Newest and enter 0 -> invalid count
        await tester.tap(find.text('Newest'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byKey(const Key('scope_count_field')), '0');
        await tester.pumpAndSettle();
        expect(
          find.text('Enter a positive integer message limit.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scope_apply_button')))
              .onPressed,
          isNull,
        );

        // Fix count to 10000
        await tester.enterText(
          find.byKey(const Key('scope_count_field')),
          '10000',
        );
        await tester.pumpAndSettle();

        // Invalid start timestamp
        final startField = find.descendant(
          of: find.byKey(const Key('scope_start_timestamp_field')),
          matching: find.byType(TextField),
        );
        await tester.enterText(startField, 'not-a-date');
        await tester.pumpAndSettle();
        expect(find.text('Invalid start timestamp format.'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scope_apply_button')))
              .onPressed,
          isNull,
        );

        // Start >= End
        final endField = find.descendant(
          of: find.byKey(const Key('scope_end_timestamp_field')),
          matching: find.byType(TextField),
        );
        await tester.enterText(startField, '5/1/2026 12:00:00');
        await tester.enterText(endField, '5/1/2026 11:00:00');
        await tester.pumpAndSettle();
        expect(
          find.text('Start timestamp must be before end timestamp.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scope_apply_button')))
              .onPressed,
          isNull,
        );

        // Clear timestamps, deselect all partitions -> error
        await tester.enterText(startField, '');
        await tester.enterText(endField, '');
        await tester.tap(find.byKey(const Key('scope_all_partitions_chip')));
        await tester.pumpAndSettle();
        expect(find.text('Select at least one partition.'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scope_apply_button')))
              .onPressed,
          isNull,
        );

        // Select partitions 0 and 3 -> valid, Apply returns scope
        await tester.tap(find.byKey(const Key('scope_partition_chip_0')));
        await tester.tap(find.byKey(const Key('scope_partition_chip_3')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('scope_apply_button')))
              .onPressed,
          isNotNull,
        );

        await tester.tap(find.byKey(const Key('scope_apply_button')));
        await tester.pumpAndSettle();
        expect(result?.messageLimit, 10000);
        expect(result?.limitFrom, ScopeLimitFrom.newest);
        expect(result?.partitions, [0, 3]);
      },
    );

    testWidgets(
      'applying newest 10,000 on partitions 0, 3 updates the scope summary button',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final ctrl = TopicAnalysisController();
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          wrap(
            TopicAnalysisView(topic: topic, profile: profile, controller: ctrl),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Scope: All messages'), findsOneWidget);

        await tester.tap(find.byKey(const Key('analysis_scope_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Newest'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scope_all_partitions_chip')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scope_partition_chip_0')));
        await tester.tap(find.byKey(const Key('scope_partition_chip_3')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scope_apply_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Scope: Newest 10,000 · partitions 0, 3'),
          findsOneWidget,
        );
      },
    );
  });

  group('Start flow with confirmation (6.3)', () {
    testWidgets('below threshold starts directly without dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var started = 0;
      final streamCtrl = StreamController<TopicAnalysisProgress>();
      addTearDown(streamCtrl.close);

      final ctrl = TopicAnalysisController(
        scopeEstimator:
            ({required profile, required topic, required scope}) async =>
                const AnalysisScopeEstimate(
                  plannedTotal: 500,
                  knownTotal: 500,
                  complete: true,
                  unreadable: [],
                ),
        streamFactory: ({required profile, required topic, required options}) {
          started++;
          return streamCtrl.stream;
        },
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        wrap(
          TopicAnalysisView(
            topic: topic,
            profile: profile,
            controller: ctrl,
            confirmThresholdProvider: () async => 1000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('analysis_start_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(AlertDialog), findsNothing);
      expect(started, 1);
    });

    testWidgets('limit <= threshold skips estimate and starts directly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      var estimateCalls = 0;
      var started = 0;
      final streamCtrl = StreamController<TopicAnalysisProgress>();
      addTearDown(streamCtrl.close);

      final ctrl = TopicAnalysisController(
        scopeEstimator:
            ({required profile, required topic, required scope}) async {
              estimateCalls++;
              return const AnalysisScopeEstimate(
                plannedTotal: 100,
                knownTotal: 100,
                complete: true,
                unreadable: [],
              );
            },
        streamFactory: ({required profile, required topic, required options}) {
          started++;
          return streamCtrl.stream;
        },
      );
      ctrl.setScope(
        const AnalysisScope(
          messageLimit: 500,
          limitFrom: ScopeLimitFrom.newest,
        ),
      );
      addTearDown(ctrl.dispose);

      await tester.pumpWidget(
        wrap(
          TopicAnalysisView(
            topic: topic,
            profile: profile,
            controller: ctrl,
            confirmThresholdProvider: () async => 1000,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('analysis_start_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(estimateCalls, 0);
      expect(started, 1);
    });

    testWidgets(
      'incomplete estimate above threshold shows at least + unreadable + compact hint; cancel keeps idle, confirm starts',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        var started = 0;
        final streamCtrl = StreamController<TopicAnalysisProgress>();
        addTearDown(streamCtrl.close);

        final ctrl = TopicAnalysisController(
          scopeEstimator:
              ({required profile, required topic, required scope}) async =>
                  const AnalysisScopeEstimate(
                    plannedTotal: 2500000,
                    knownTotal: 2500000,
                    complete: false,
                    unreadable: [
                      UnreadablePartition(partition: 2, reason: 'timed out'),
                    ],
                  ),
          streamFactory:
              ({required profile, required topic, required options}) {
                started++;
                return streamCtrl.stream;
              },
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          wrap(
            TopicAnalysisView(
              topic: topic,
              profile: profile,
              controller: ctrl,
              confirmThresholdProvider: () async => 1000000,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('analysis_start_button')));
        await tester.pumpAndSettle();

        expect(find.text('Start large analysis?'), findsOneWidget);
        expect(find.textContaining('at least 2,500,000'), findsOneWidget);
        expect(find.text('Partition 2: timed out'), findsOneWidget);
        expect(find.textContaining('compacted topic'), findsOneWidget);

        // Cancel -> does not start
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(started, 0);

        // Trigger again and confirm -> starts
        await tester.tap(find.byKey(const Key('analysis_start_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Scan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(started, 1);
      },
    );

    testWidgets(
      'estimate error shows size unknown and start button is disabled while estimating',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final completer = Completer<AnalysisScopeEstimate>();
        final ctrl = TopicAnalysisController(
          scopeEstimator:
              ({required profile, required topic, required scope}) =>
                  completer.future,
        );
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          wrap(
            TopicAnalysisView(
              topic: topic,
              profile: profile,
              controller: ctrl,
              confirmThresholdProvider: () async => 1000,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('analysis_start_button')));
        await tester.pump();

        expect(find.text('Estimating…'), findsOneWidget);
        final startBtn = tester.widget<FilledButton>(
          find.byKey(const Key('analysis_start_button')),
        );
        expect(startBtn.onPressed, isNull);

        completer.completeError(Exception('broker unreachable'));
        await tester.pumpAndSettle();

        expect(find.textContaining('Scan size unknown'), findsOneWidget);
      },
    );
  });
}
