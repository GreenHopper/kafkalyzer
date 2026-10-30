import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/domain/production_timeline.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/daily_production_view.dart';
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
    'DailyProductionView renders unavailable notice when timeline not available',
    (tester) async {
      final report = _testReport(timeline: const [], scanRefMs: null);
      final domain = ProductionTimeline(report: report);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DailyProductionView(timeline: domain)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Production Distribution'), findsOneWidget);
      expect(
        find.text('Timeline is not available for this report.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'DailyProductionView renders rows newest first with gap day and partial marker',
    (tester) async {
      // Oct 26 (Mon): 1200 msgs. Oct 28 (Wed): 1500 msgs. Gap Oct 27 (Tue): 0 msgs.
      // Coverage started on Oct 26 at 10:00 (making Oct 26 partially covered).
      final monMs = DateTime.utc(2026, 10, 26, 12).millisecondsSinceEpoch;
      final wedMs = DateTime.utc(2026, 10, 28, 14).millisecondsSinceEpoch;
      final refMs = DateTime.utc(2026, 10, 28, 18).millisecondsSinceEpoch;
      final covStartMs = DateTime.utc(2026, 10, 26, 10).millisecondsSinceEpoch;

      final report = _testReport(
        timeline: [
          HourBucket(epochHour: (monMs / 3600000).floor(), count: 1200),
          HourBucket(epochHour: (wedMs / 3600000).floor(), count: 1500),
        ],
        scanRefMs: refMs,
        completeFromMs: covStartMs,
      );

      final domain = ProductionTimeline(
        report: report,
        toLocal: (ms) => DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(body: DailyProductionView(timeline: domain)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Production Distribution'), findsOneWidget);

      // Verify messages counts:
      expect(find.text('1,500 msgs'), findsOneWidget);
      expect(find.text('0 msgs'), findsOneWidget);
      expect(find.text('1,200 msgs'), findsOneWidget);

      // Weekdays
      expect(find.text('Wednesday'), findsOneWidget);
      expect(find.text('Tuesday'), findsOneWidget);
      expect(find.text('Monday'), findsOneWidget);

      // Partial coverage marker on Monday
      expect(find.text('Partial coverage'), findsOneWidget);
    },
  );
}
