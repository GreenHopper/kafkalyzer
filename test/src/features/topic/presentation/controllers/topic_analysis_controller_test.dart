import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';

class FakeExportService extends TopicAnalysisExportService {
  String? exportResult;
  TopicAnalysisReportFile? importResult;
  TopicAnalysisImportError? importError;
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
    if (importError != null) throw importError!;
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
    partitionStats: const [],
    hourlyDistribution: const [],
    topKeys: const [],
    contentTypeDistribution: const [],
    fieldFrequencies: const [],
    scanDurationMs: 12345,
  ),
);

void main() {
  final getIt = GetIt.instance;
  late Logger logger;
  late FakeExportService fake;
  late TopicAnalysisController controller;

  setUp(() {
    getIt.reset();
    logger = Logger(printer: PrettyPrinter(methodCount: 0));
    getIt.registerSingleton<Logger>(logger);
    fake = FakeExportService();
    controller = TopicAnalysisController(logger: logger, exportService: fake);
  });

  group('TopicAnalysisController', () {
    test('defaults to a live (non-imported) source', () {
      expect(controller.isImported, isFalse);
    });

    test(
      'importReport success sets report, imported source, and provenance',
      () async {
        final file = _sampleFile();
        fake.importResult = file;

        final ok = await controller.importReport();

        expect(ok, isTrue);
        expect(fake.importCalled, isTrue);
        expect(controller.isImported, isTrue);
        expect(controller.report, file.report);
        expect(controller.reportClusterName, 'prod-eu-1');
        expect(controller.reportExportedAt, file.exportedAt);
        expect(controller.importErrorKind, isNull);
      },
    );

    test('importReport surfaces a typed error and keeps prior state', () async {
      fake.importError = const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.unsupportedVersion,
        foundVersion: 99,
      );

      final ok = await controller.importReport();

      expect(ok, isFalse);
      expect(controller.isImported, isFalse);
      expect(
        controller.importErrorKind,
        TopicAnalysisImportErrorKind.unsupportedVersion,
      );
      expect(controller.importErrorFoundVersion, 99);
    });

    test('importReport cancel returns false with no error', () async {
      fake.importResult = null;

      final ok = await controller.importReport();

      expect(ok, isFalse);
      expect(controller.importErrorKind, isNull);
      expect(controller.isImported, isFalse);
    });

    test(
      'exportReport returns the written path when a report exists',
      () async {
        fake.importResult = _sampleFile();
        await controller.importReport();

        fake.exportResult = '/tmp/orders_analysis.json';
        final path = await controller.exportReport(clusterName: 'prod-eu-1');

        expect(fake.exportCalled, isTrue);
        expect(path, '/tmp/orders_analysis.json');
      },
    );

    test(
      'exportReport returns null and skips the service when no report',
      () async {
        expect(controller.report, isNull);
        final path = await controller.exportReport();
        expect(path, isNull);
        expect(fake.exportCalled, isFalse);
      },
    );

    test('clear() resets imported source and provenance to defaults', () async {
      fake.importResult = _sampleFile();
      await controller.importReport();
      expect(controller.isImported, isTrue);

      controller.clear();

      expect(controller.isImported, isFalse);
      expect(controller.report, isNull);
      expect(controller.reportClusterName, isNull);
      expect(controller.reportExportedAt, isNull);
    });

    test('startAnalysis resets the source to live', () async {
      fake.importResult = _sampleFile();
      await controller.importReport();
      expect(controller.isImported, isTrue);

      await controller.startAnalysis(
        const ClusterProfile(name: 'test', bootstrapServers: 'localhost:9092'),
        'orders',
      );

      // The scan itself will fail in this environment (no native bridge), but
      // the source must have been reset before the scan was attempted.
      expect(controller.isImported, isFalse);
      expect(controller.reportClusterName, isNull);
      await controller.stopAnalysis();
    });
  });
}
