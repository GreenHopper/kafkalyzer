import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/domain/production_timeline.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/recent_production_chart.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

TopicAnalysisReport _testReport({
  required List<HourBucket> timeline,
  int? scanRefMs,
  int? completeFromMs,
}) {
  return TopicAnalysisReport(
    topic: 'test-topic',
    totalMessages: timeline.fold<int>(0, (s, b) => s + b.count),
    totalBytes: 1000,
    minMessageSize: 10,
    maxMessageSize: 100,
    avgMessageSize: 50.0,
    tombstonesCount: 0,
    isCompacted: false,
    nullKeysCount: 0,
    partitionStats: const [],
    hourlyDistribution: const [],
    topKeys: const [],
    contentTypeDistribution: const [],
    fieldFrequencies: const [],
    scanDurationMs: 500,
    messageSizePercentiles: null,
    sizePercentilesEstimated: false,
    estimatedDistinctKeys: 0,
    keyCardinalityCapped: false,
    hourlyTimeline: timeline,
    scanReferenceTimeMs: scanRefMs,
    completeFromMs: completeFromMs,
    timelineOutsideCount: 0,
    valueFilterResult: null,
  );
}

void main() {
  testWidgets(
    'RecentProductionChart renders unavailable notice when timeline not available',
    (tester) async {
      final report = _testReport(timeline: const [], scanRefMs: null);
      final domain = ProductionTimeline(report: report);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RecentProductionChart(timeline: domain)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Production'), findsOneWidget);
      expect(
        find.text('Timeline is not available for this report.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'RecentProductionChart renders 24 bars by default and switches to 72',
    (tester) async {
      final refDt = DateTime.utc(2026, 10, 30, 12);
      final refMs = refDt.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();

      final timeline = <HourBucket>[];
      for (var d = 1; d <= 7; d++) {
        timeline.add(HourBucket(epochHour: refHour - (24 * d), count: 300));
      }
      timeline.add(HourBucket(epochHour: refHour, count: 900));

      final report = _testReport(timeline: timeline, scanRefMs: refMs);
      final domain = ProductionTimeline(
        report: report,
        toLocal: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RecentProductionChart(timeline: domain)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recent Production'), findsOneWidget);
      expect(find.byType(SegmentedButton<int>), findsOneWidget);

      // Switch to 72h
      await tester.tap(find.text('72h'));
      await tester.pumpAndSettle();

      // Verify 72h is selected
      final segmentedButton = tester.widget<SegmentedButton<int>>(
        find.byType(SegmentedButton<int>),
      );
      expect(segmentedButton.selected, {72});
    },
  );

  testWidgets(
    'RecentProductionChart shows coverage hint when window is partially covered',
    (tester) async {
      final refDt = DateTime.utc(2026, 10, 30, 12);
      final refMs = refDt.millisecondsSinceEpoch;
      final refHour = (refMs / 3600000).floor();
      // Only covered for last 5 hours
      final completeFromMs = refDt
          .subtract(const Duration(hours: 5))
          .millisecondsSinceEpoch;

      final report = _testReport(
        timeline: [HourBucket(epochHour: refHour, count: 100)],
        scanRefMs: refMs,
        completeFromMs: completeFromMs,
      );
      final domain = ProductionTimeline(
        report: report,
        toLocal: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: RecentProductionChart(timeline: domain)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Scan covers the last'), findsOneWidget);
    },
  );
}
