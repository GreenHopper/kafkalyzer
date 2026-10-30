import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_summary_cards.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('TopicAnalysisSummaryCards renders metric cards accurately', (
    tester,
  ) async {
    const report = TopicAnalysisReport(
      topic: 'test-topic',
      totalMessages: 12500,
      totalBytes: 2500000,
      minMessageSize: 50,
      maxMessageSize: 2048,
      avgMessageSize: 200.0,
      tombstonesCount: 250,
      isCompacted: true,
      nullKeysCount: 100,
      partitionStats: [
        PartitionAnalysis(
          partition: 0,
          messageCount: 12500,
          byteSize: 2500000,
          percentage: 100.0,
          earliestOffset: 0,
          latestOffset: 12500,
        ),
      ],
      hourlyDistribution: [],
      topKeys: [],
      contentTypeDistribution: [],
      fieldFrequencies: [],
      scanDurationMs: 1200,
      messageSizePercentiles: null,
      sizePercentilesEstimated: false,
      estimatedDistinctKeys: 0,
      keyCardinalityCapped: false,
      hourlyTimeline: [],
      scanReferenceTimeMs: null,
      completeFromMs: null,
      timelineOutsideCount: 0,
      valueFilterResult: null,
    );

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TopicAnalysisSummaryCards(report: report)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Total Messages'), findsOneWidget);
    expect(find.text('Total Payload Size'), findsOneWidget);
    expect(find.text('Tombstones'), findsOneWidget);
    expect(find.text('Keyed Messages'), findsOneWidget);
    expect(find.text('compact'), findsOneWidget);
  });

  TopicAnalysisReport reportWith({
    SizePercentiles? percentiles,
    bool estimated = false,
    int distinctKeys = 0,
    bool capped = false,
    DuplicateAnalysisResult? duplicateAnalysisResult,
  }) => TopicAnalysisReport(
    topic: 'test-topic',
    totalMessages: 1000,
    totalBytes: 200000,
    minMessageSize: 50,
    maxMessageSize: 2048,
    avgMessageSize: 200.0,
    tombstonesCount: 0,
    isCompacted: false,
    nullKeysCount: 0,
    partitionStats: const [],
    hourlyDistribution: const [],
    topKeys: const [],
    contentTypeDistribution: const [],
    fieldFrequencies: const [],
    scanDurationMs: 1000,
    messageSizePercentiles: percentiles,
    sizePercentilesEstimated: estimated,
    estimatedDistinctKeys: distinctKeys,
    keyCardinalityCapped: capped,
    hourlyTimeline: const [],
    scanReferenceTimeMs: null,
    completeFromMs: null,
    timelineOutsideCount: 0,
    valueFilterResult: null,
    duplicateAnalysisResult: duplicateAnalysisResult,
  );

  Future<void> pump(WidgetTester tester, TopicAnalysisReport report) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: TopicAnalysisSummaryCards(report: report)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exact percentiles and key counts carry no estimate label', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      reportWith(
        percentiles: const SizePercentiles(p50: 512, p95: 1536, p99: 2048),
        distinctKeys: 4200,
      ),
    );

    expect(
      find.textContaining('p50/p95/p99: 512 B / 1.5 KB / 2.0 KB'),
      findsOneWidget,
    );
    expect(find.textContaining('Distinct keys: 4,200'), findsOneWidget);
    expect(find.textContaining('estimated'), findsNothing);
    expect(find.textContaining('capped'), findsNothing);
  });

  testWidgets('an estimated percentile sample and a capped key map say so', (
    WidgetTester tester,
  ) async {
    await pump(
      tester,
      reportWith(
        percentiles: const SizePercentiles(p50: 512, p95: 1536, p99: 2048),
        estimated: true,
        distinctKeys: 10000,
        capped: true,
      ),
    );

    expect(find.textContaining('(estimated)'), findsOneWidget);
    expect(
      find.textContaining('Distinct keys: 10,000 (capped)'),
      findsOneWidget,
    );
  });

  testWidgets(
    'renders duplicate messages card when duplicateAnalysisResult is present',
    (WidgetTester tester) async {
      await pump(
        tester,
        reportWith(
          duplicateAnalysisResult: const DuplicateAnalysisResult(
            scope: DuplicateDetectionScope.payloadOnly,
            totalMessages: 1000,
            uniqueMessages: 850,
            duplicateMessages: 150,
            duplicateRate: 15.0,
            topDuplicates: [],
          ),
        ),
      );

      expect(find.text('Duplicate Messages'), findsOneWidget);
      expect(find.text('150 (15.0%)'), findsOneWidget);
      expect(find.textContaining('850 unique'), findsOneWidget);
    },
  );
}
