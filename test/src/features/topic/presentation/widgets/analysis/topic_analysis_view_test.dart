import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

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
  });
}
