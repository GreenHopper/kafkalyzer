import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kafkalyzer/src/rust/api/report_compare.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';

import '../../../../../rust/api/rust_mocks.mocks.dart';

import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_summary_cards.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_view.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';

class FakeExportService extends TopicAnalysisExportService {
  String? exportResult;
  TopicAnalysisReportFile? importResult;
  bool exportCalled = false;
  bool importCalled = false;

  @override
  Future<String?> export(TopicAnalysisReportFile file) async {
    exportCalled = true;
    return exportResult;
  }

  @override
  Future<TopicAnalysisReportFile?> importFile() async {
    importCalled = true;
    return importResult;
  }
}

TopicAnalysisReportFile _file(String topic, int messages) =>
    TopicAnalysisReportFile(
      exportedAt: DateTime.utc(2026, 9, 1, 8),
      clusterName: 'staging-eu-1',
      report: TopicAnalysisReport(
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
      ),
    );

TopicAnalysisReportFile _sampleFile() => TopicAnalysisReportFile(
  exportedAt: DateTime.utc(2026, 8, 19, 12, 34, 56),
  clusterName: 'prod-eu-1',
  report: TopicAnalysisReport(
    topic: 'orders',
    totalMessages: 1000,
    totalBytes: 20480,
    minMessageSize: 1,
    maxMessageSize: 50,
    avgMessageSize: 20.48,
    tombstonesCount: 3,
    isCompacted: true,
    nullKeysCount: 12,
    partitionStats: const [
      PartitionAnalysis(
        partition: 0,
        messageCount: 500,
        byteSize: 10240,
        percentage: 50.0,
        earliestOffset: 0,
        latestOffset: 499,
      ),
    ],
    hourlyDistribution: const [
      HourlyCount(hour: 9, count: 100, percentage: 10.0),
    ],
    topKeys: const [KeyOccurrence(key: 'k1', count: 50, percentage: 5.0)],
    contentTypeDistribution: const [
      TypeOccurrence(typeName: 'json', count: 900, percentage: 90.0),
    ],
    fieldFrequencies: const [
      FieldOccurrence(
        fieldName: 'id',
        count: 900,
        percentage: 90.0,
        topValues: [
          FieldValueOccurrence(value: '1', count: 10, percentage: 1.11),
        ],
      ),
    ],
    scanDurationMs: 12345,
    messageSizePercentiles: null,
    sizePercentilesEstimated: false,
    estimatedDistinctKeys: 0,
    keyCardinalityCapped: false,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    KafkalyzerRustLib.initMock(api: mockApi);
  });

  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final getIt = GetIt.instance;
    await getIt.reset();
    getIt.registerSingleton<Logger>(
      Logger(printer: PrettyPrinter(methodCount: 0)),
    );
  });

  const topic = TopicMetadata(
    name: 'orders',
    partitionCount: 2,
    replicationFactor: 3,
  );
  const profile = ClusterProfile(
    name: 'prod-eu-1',
    bootstrapServers: 'localhost:9092',
  );

  Widget buildView(TopicAnalysisController controller) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: const [Locale('en')],
      home: Scaffold(
        body: TopicAnalysisView(
          topic: topic,
          profile: profile,
          controller: controller,
        ),
      ),
    );
  }

  setUp(() {
    resetMockitoState();
    when(
      mockApi.crateApiReportCompareCompareReports(
        before: anyNamed('before'),
        after: anyNamed('after'),
      ),
    ).thenAnswer(
      (_) async => const ReportComparison(
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
        ],
        fields: [],
      ),
    );
  });

  void useBigTestSurface(WidgetTester tester) {
    final originalSize = tester.view.physicalSize;
    final originalRatio = tester.view.devicePixelRatio;
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.physicalSize = originalSize;
      tester.view.devicePixelRatio = originalRatio;
    });
  }

  group('TopicAnalysisView', () {
    testWidgets('export is disabled and import enabled with no report', (
      tester,
    ) async {
      final controller = TopicAnalysisController();
      await tester.pumpWidget(buildView(controller));
      await tester.pumpAndSettle();

      expect(find.text('Import Analysis Report'), findsOneWidget);
      expect(find.text('Export Analysis Report'), findsOneWidget);

      final importButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Import Analysis Report'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        importButton.onPressed,
        isNotNull,
        reason: 'import must be enabled',
      );

      final exportButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Export Analysis Report'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        exportButton.onPressed,
        isNull,
        reason: 'export must be disabled when there is no report',
      );

      expect(find.textContaining('Imported from'), findsNothing);
    });

    testWidgets('importing a report renders the dashboard and the indicator', (
      tester,
    ) async {
      // Give the dashboard enough room (the real app scrolls; the default test
      // surface is too small for the full report).
      final originalSize = tester.view.physicalSize;
      final originalRatio = tester.view.devicePixelRatio;
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.physicalSize = originalSize;
        tester.view.devicePixelRatio = originalRatio;
      });

      final fake = FakeExportService()..importResult = _sampleFile();
      final controller = TopicAnalysisController(exportService: fake);

      await tester.pumpWidget(buildView(controller));
      await tester.pumpAndSettle();

      // Before import: no dashboard.
      expect(find.byType(TopicAnalysisSummaryCards), findsNothing);

      // Tap the Import button's label.
      await tester.tap(find.text('Import Analysis Report'));
      await tester.pumpAndSettle();

      expect(fake.importCalled, isTrue);
      expect(controller.isImported, isTrue);

      // The dashboard is rendered from the imported report...
      expect(find.byType(TopicAnalysisSummaryCards), findsOneWidget);
      // ...and the "Imported from" provenance indicator is shown.
      expect(find.textContaining('Imported from prod-eu-1'), findsOneWidget);

      // Export is now enabled.
      final exportButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Export Analysis Report'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(
        exportButton.onPressed,
        isNotNull,
        reason: 'export must be enabled once a report is available',
      );
    });

    testWidgets('comparing against a second report renders the delta rows', (
      tester,
    ) async {
      useBigTestSurface(tester);

      final fake = FakeExportService()..importResult = _file('orders', 1000);
      final controller = TopicAnalysisController(exportService: fake);
      await tester.pumpWidget(buildView(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import Analysis Report'));
      await tester.pumpAndSettle();

      fake.importResult = _file('orders', 1200);
      await tester.tap(find.byKey(const Key('analysis_compare_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report_comparison_view')), findsOneWidget);
      expect(
        find.byKey(const Key('comparison_metric_total_messages')),
        findsOneWidget,
      );
      expect(find.textContaining('+200'), findsOneWidget);
    });

    testWidgets('a pair of different topics is rejected and both are named', (
      tester,
    ) async {
      useBigTestSurface(tester);

      final fake = FakeExportService()..importResult = _file('orders', 1000);
      final controller = TopicAnalysisController(exportService: fake);
      await tester.pumpWidget(buildView(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import Analysis Report'));
      await tester.pumpAndSettle();

      fake.importResult = _file('shipments', 1200);
      await tester.tap(find.byKey(const Key('analysis_compare_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report_comparison_view')), findsNothing);
      expect(
        find.byKey(const Key('comparison_topic_mismatch')),
        findsOneWidget,
      );
      expect(
        find.textContaining('shipments', findRichText: true),
        findsOneWidget,
      );
      expect(find.textContaining('orders', findRichText: true), findsWidgets);
    });

    testWidgets('cancelling the second report leaves no partial comparison', (
      tester,
    ) async {
      useBigTestSurface(tester);

      final fake = FakeExportService()..importResult = _file('orders', 1000);
      final controller = TopicAnalysisController(exportService: fake);
      await tester.pumpWidget(buildView(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import Analysis Report'));
      await tester.pumpAndSettle();

      fake.importResult = null;
      await tester.tap(find.byKey(const Key('analysis_compare_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('report_comparison_view')), findsNothing);
      expect(controller.comparison, isNull);
    });

    testWidgets('renders partition health section when report is present', (
      tester,
    ) async {
      useBigTestSurface(tester);
      final fake = FakeExportService()..importResult = _sampleFile();
      final controller = TopicAnalysisController(exportService: fake);
      await tester.pumpWidget(buildView(controller));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import Analysis Report'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('analysis_partition_health_card')),
        findsOneWidget,
      );
      expect(find.text('Partition Health & Replication'), findsOneWidget);
    });
  });
}
