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
}
