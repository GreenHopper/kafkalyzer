import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_report_comparison_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/report_compare.dart';

TopicAnalysisReport _report(String topic, int messages) => TopicAnalysisReport(
  topic: topic,
  totalMessages: messages,
  totalBytes: messages * 20,
  minMessageSize: 1,
  maxMessageSize: 50,
  avgMessageSize: 20.0,
  tombstonesCount: 0,
  isCompacted: false,
  nullKeysCount: 0,
  partitionStats: const [],
  hourlyDistribution: const [],
  topKeys: const [],
  contentTypeDistribution: const [],
  fieldFrequencies: const [],
  scanDurationMs: 1000,
  messageSizePercentiles: null,
  sizePercentilesEstimated: false,
  estimatedDistinctKeys: 0,
  keyCardinalityCapped: false,
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ],
  supportedLocales: const [Locale('en')],
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

const _comparison = ReportComparison(
  topic: 'orders',
  metrics: [
    MetricDelta(
      metric: 'total_messages',
      before: 1000,
      after: 1200,
      absolute: 200,
      relativePercent: 20.0,
      comparable: true,
    ),
    MetricDelta(metric: 'size_p95', before: 512, comparable: false),
  ],
  fields: [
    FieldDelta(field: 'coupon', after: 40, added: true, removed: false),
    FieldDelta(field: 'currency', before: 300, added: false, removed: true),
  ],
);

void main() {
  testWidgets('a live report next to an imported one labels both sides', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TopicReportComparisonView(
          comparison: _comparison,
          base: _report('orders', 1000),
          current: _report('orders', 1200),
          baseClusterName: 'staging-eu-1',
          baseMoment: DateTime.utc(2026, 8, 19, 12),
          baseIsImported: true,
          currentIsImported: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final baseSide = find.byKey(const Key('comparison_side_base'));
    final currentSide = find.byKey(const Key('comparison_side_current'));
    expect(
      find.descendant(of: baseSide, matching: find.textContaining('Imported')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: currentSide, matching: find.textContaining('Live')),
      findsOneWidget,
    );
  });

  testWidgets('a metric carries both values, the delta and its percentage', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TopicReportComparisonView(
          comparison: _comparison,
          base: _report('orders', 1000),
          current: _report('orders', 1200),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('comparison_metric_total_messages'));
    expect(
      find.descendant(of: row, matching: find.text('Total Messages')),
      findsOneWidget,
    );
    expect(find.descendant(of: row, matching: find.text('1,000')), findsOne);
    expect(find.descendant(of: row, matching: find.text('1,200')), findsOne);
    expect(
      find.descendant(of: row, matching: find.textContaining('+200')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row, matching: find.textContaining('20.0 %')),
      findsOneWidget,
    );
  });

  testWidgets('a metric missing on one side says not available, never zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TopicReportComparisonView(
          comparison: _comparison,
          base: _report('orders', 1000),
          current: _report('orders', 1200),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('comparison_metric_size_p95'));
    expect(
      find.descendant(of: row, matching: find.text('not available')),
      findsOneWidget,
    );
    expect(find.descendant(of: row, matching: find.text('0')), findsNothing);
  });

  testWidgets('fields that appeared and vanished are listed on their own', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TopicReportComparisonView(
          comparison: _comparison,
          base: _report('orders', 1000),
          current: _report('orders', 1200),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+coupon'), findsOneWidget);
    expect(find.text('-currency'), findsOneWidget);
    expect(find.text('Fields added'), findsOneWidget);
    expect(find.text('Fields removed'), findsOneWidget);
  });
}
