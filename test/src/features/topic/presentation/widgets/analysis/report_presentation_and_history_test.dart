import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/duplicate_analysis_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/key_and_field_distribution_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/report_scope_and_limits_cards.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_report_comparison_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/report_compare.dart';
import 'package:kafkalyzer/src/services/topic_analysis_history_service.dart';
import 'package:material_ui/material_ui.dart';

TopicAnalysisReport _makeReport({
  String topic = 'orders',
  int totalMessages = 100,
  AnalysisScopeSummary? scanScope,
  List<AnalysisLimit>? analysisLimits,
  int? trackedFieldCount,
  DuplicateAnalysisResult? duplicateAnalysisResult,
}) => TopicAnalysisReport(
  topic: topic,
  totalMessages: totalMessages,
  totalBytes: 1000,
  minMessageSize: 10,
  maxMessageSize: 10,
  avgMessageSize: 10.0,
  tombstonesCount: 0,
  isCompacted: false,
  cleanupPolicyUnknown: false,
  nullKeysCount: 0,
  partitionStats: const [],
  hourlyDistribution: const [],
  topKeys: const [],
  contentTypeDistribution: const [],
  fieldFrequencies: const [
    FieldOccurrence(
      fieldName: 'id',
      count: 100,
      percentage: 100.0,
      topValues: [],
      valuesCapped: false,
    ),
  ],
  scanDurationMs: 10,
  sizePercentilesEstimated: false,
  estimatedDistinctKeys: 0,
  keyCardinalityCapped: false,
  hourlyTimeline: const [],
  timelineOutsideCount: 0,
  scanScope: scanScope,
  analysisLimits: analysisLimits,
  trackedFieldCount: trackedFieldCount,
  duplicateAnalysisResult: duplicateAnalysisResult,
);

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('Scope and limits cards + field/duplicate labels (7.1)', () {
    testWidgets(
      'renders scope details, reached limits, and unavailable v3 state',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                ReportScopeCard(
                  scanScope: AnalysisScopeSummary(
                    scope: AnalysisScope(
                      partitions: Int32List.fromList([0, 2]),
                      messageLimit: 10000,
                      limitFrom: ScopeLimitFrom.newest,
                    ),
                    ranges: const [],
                    unreadable: const [
                      UnreadablePartition(partition: 1, reason: 'timed out'),
                    ],
                    excludedByTimeRange: 17,
                  ),
                ),
                const AnalysisLimitsCard(
                  limits: [
                    AnalysisLimit(
                      kind: AnalysisLimitKind.trackedFields,
                      limit: 500,
                      reached: true,
                    ),
                    AnalysisLimit(
                      kind: AnalysisLimitKind.trackedKeys,
                      limit: 50000,
                      reached: false,
                    ),
                  ],
                ),
                const AnalysisLimitsCard(limits: null),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Newest 10,000 · partitions 0, 2'), findsOneWidget);
        expect(find.text('Excluded by time range: 17'), findsOneWidget);
        expect(
          find.text('Unreadable partitions: P1 (timed out)'),
          findsOneWidget,
        );
        expect(find.text('Tracked fields: 500 · Reached'), findsOneWidget);
        expect(
          find.text('Tracked keys: 50,000 · Within limit'),
          findsOneWidget,
        );
        expect(find.text('Not available for this report.'), findsOneWidget);
      },
    );

    testWidgets(
      'field summary and estimated/exact duplicate states render correctly',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            Column(
              children: [
                KeyAndFieldDistributionView(
                  topKeys: const [],
                  contentTypes: const [],
                  fieldFrequencies: _makeReport().fieldFrequencies,
                  totalMessages: 100,
                  trackedFieldCount: 437,
                  trackedFieldsLimitReached: true,
                ),
                const DuplicateAnalysisView(
                  result: DuplicateAnalysisResult(
                    scope: DuplicateDetectionScope.payloadOnly,
                    totalMessages: 1000,
                    uniqueMessages: 900,
                    duplicateMessages: 100,
                    duplicateRate: 10.0,
                    topDuplicates: [],
                    estimated: true,
                    untrackedMessages: 42,
                    fingerprintLimit: 1835008,
                    samplesCapped: true,
                  ),
                ),
                const DuplicateAnalysisView(
                  result: DuplicateAnalysisResult(
                    scope: DuplicateDetectionScope.payloadOnly,
                    totalMessages: 100,
                    uniqueMessages: 90,
                    duplicateMessages: 10,
                    duplicateRate: 10.0,
                    topDuplicates: [],
                    estimated: false,
                    untrackedMessages: 0,
                    fingerprintLimit: 1835008,
                    samplesCapped: false,
                  ),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('1 of 437 fields · Further fields not tracked'),
          findsOneWidget,
        );
        expect(
          find.text('Estimated (at least) · 42 untracked messages'),
          findsOneWidget,
        );
        expect(find.text('List possibly incomplete'), findsOneWidget);
      },
    );
  });

  group('History MenuAnchors (7.2)', () {
    const profile = ClusterProfile(
      name: 'prod',
      bootstrapServers: 'kafka:9092',
      tlsVerification: TlsVerification.enabled,
    );
    const topic = TopicMetadata(
      name: 'orders',
      partitionCount: 2,
      replicationFactor: 1,
    );

    testWidgets(
      'import menu lists saved report and opens it without file picker; empty and error states still show From file',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final savedReport = _makeReport(
          totalMessages: 777,
          scanScope: const AnalysisScopeSummary(
            scope: AnalysisScope(
              messageLimit: 1000,
              limitFrom: ScopeLimitFrom.newest,
            ),
            ranges: [],
            unreadable: [],
            excludedByTimeRange: 0,
          ),
        );

        final fakeHistory = _StubHistoryService(
          listing: HistoryListing(
            entries: [
              TopicAnalysisHistoryEntry(
                filePath: '/tmp/1.json',
                exportedAt: DateTime.utc(2026, 5, 1, 10, 0),
                clusterName: 'prod',
                report: savedReport,
              ),
            ],
            unreadableCount: 1,
          ),
        );
        final ctrl = TopicAnalysisController(historyService: fakeHistory);
        addTearDown(ctrl.dispose);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TopicAnalysisView(
                topic: topic,
                profile: profile,
                controller: ctrl,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('analysis_import_button')));
        await tester.pumpAndSettle();

        expect(find.text('Newest 1,000 · 777 messages'), findsOneWidget);
        expect(find.text('1 unreadable file(s) skipped'), findsOneWidget);
        expect(find.text('From file…'), findsOneWidget);

        await tester.tap(find.text('Newest 1,000 · 777 messages'));
        await tester.pumpAndSettle();
        expect(ctrl.isImported, isTrue);
        expect(ctrl.report?.totalMessages, 777);

        // Empty state
        fakeHistory.listing = const HistoryListing(
          entries: [],
          unreadableCount: 0,
        );
        await tester.tap(find.byKey(const Key('analysis_import_button')));
        await tester.pumpAndSettle();
        expect(find.text('No saved reports for this topic'), findsOneWidget);
        expect(find.text('From file…'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        // Error state
        fakeHistory.error = const HistoryListingException('disk error');
        await tester.tap(find.byKey(const Key('analysis_import_button')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Could not load history:'), findsOneWidget);
        expect(find.text('From file…'), findsOneWidget);
      },
    );
  });

  group('Comparison scope labels and warning (7.3)', () {
    const emptyCmp = ReportComparison(topic: 'orders', metrics: [], fields: []);

    testWidgets('newest 10k vs full shows warning', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TopicReportComparisonView(
            comparison: emptyCmp,
            base: _makeReport(
              scanScope: const AnalysisScopeSummary(
                scope: AnalysisScope(
                  messageLimit: 10000,
                  limitFrom: ScopeLimitFrom.newest,
                ),
                ranges: [],
                unreadable: [],
                excludedByTimeRange: 0,
              ),
            ),
            current: _makeReport(
              scanScope: const AnalysisScopeSummary(
                scope: AnalysisScope(limitFrom: ScopeLimitFrom.newest),
                ranges: [],
                unreadable: [],
                excludedByTimeRange: 0,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comparison_scope_warning')), findsOneWidget);
      expect(find.textContaining('Comparison scopes differ'), findsOneWidget);
      expect(find.text('Newest 10,000'), findsOneWidget);
      expect(find.text('All messages'), findsOneWidget);
    });

    testWidgets('full vs full shows no warning', (tester) async {
      const fullScope = AnalysisScopeSummary(
        scope: AnalysisScope(limitFrom: ScopeLimitFrom.newest),
        ranges: [],
        unreadable: [],
        excludedByTimeRange: 0,
      );
      await tester.pumpWidget(
        _wrap(
          TopicReportComparisonView(
            comparison: emptyCmp,
            base: _makeReport(scanScope: fullScope),
            current: _makeReport(scanScope: fullScope),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('comparison_scope_warning')), findsNothing);
    });

    testWidgets(
      'missing scope shows scope not recorded and cannot-compare warning',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            TopicReportComparisonView(
              comparison: emptyCmp,
              base: _makeReport(scanScope: null),
              current: _makeReport(
                scanScope: const AnalysisScopeSummary(
                  scope: AnalysisScope(limitFrom: ScopeLimitFrom.newest),
                  ranges: [],
                  unreadable: [],
                  excludedByTimeRange: 0,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Scope not recorded'), findsOneWidget);
        expect(
          find.textContaining('cannot be reliably compared'),
          findsOneWidget,
        );
      },
    );
  });
}

class _StubHistoryService extends TopicAnalysisHistoryService {
  HistoryListing listing;
  Exception? error;

  _StubHistoryService({required this.listing});

  @override
  Future<HistoryListing> list(String clusterName, String topic) async {
    if (error != null) throw error!;
    return listing;
  }
}
