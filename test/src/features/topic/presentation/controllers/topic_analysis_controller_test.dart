import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_export_service.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_history_service.dart';

class FakeExportService extends TopicAnalysisExportService {
  String? exportResult;
  TopicAnalysisReportFile? importResult;
  TopicAnalysisImportError? importError;
  bool exportCalled = false;
  bool importCalled = false;

  @override
  Future<String?> export(
    TopicAnalysisReportFile file, {
    required String dialogTitle,
  }) async {
    exportCalled = true;
    return exportResult;
  }

  @override
  Future<TopicAnalysisReportFile?> importFile({
    required String dialogTitle,
  }) async {
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
    cleanupPolicyUnknown: false,
    nullKeysCount: 12,
    partitionStats: const [],
    hourlyDistribution: const [],
    topKeys: const [],
    contentTypeDistribution: const [],
    fieldFrequencies: const [],
    scanDurationMs: 12345,
    messageSizePercentiles: null,
    sizePercentilesEstimated: false,
    estimatedDistinctKeys: 0,
    keyCardinalityCapped: false,
    hourlyTimeline: const [],
    scanReferenceTimeMs: null,
    completeFromMs: null,
    timelineOutsideCount: 0,
    valueFilterResult: null,
    duplicateAnalysisResult: null,
  ),
);

void main() {
  final getIt = GetIt.instance;
  late Logger logger;
  late FakeExportService fake;
  late TopicAnalysisController controller;

  setUp(() {
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

        final ok = await controller.importReport(
          dialogTitle: 'Import Topic Analysis',
        );

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

      final ok = await controller.importReport(
        dialogTitle: 'Import Topic Analysis',
      );

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

      final ok = await controller.importReport(
        dialogTitle: 'Import Topic Analysis',
      );

      expect(ok, isFalse);
      expect(controller.importErrorKind, isNull);
      expect(controller.isImported, isFalse);
    });

    test(
      'exportReport returns the written path when a report exists',
      () async {
        fake.importResult = _sampleFile();
        await controller.importReport(dialogTitle: 'Import Topic Analysis');

        fake.exportResult = '/tmp/orders_analysis.json';
        final path = await controller.exportReport(
          dialogTitle: 'Export Topic Analysis',
          clusterName: 'prod-eu-1',
        );

        expect(fake.exportCalled, isTrue);
        expect(path, '/tmp/orders_analysis.json');
      },
    );

    test(
      'exportReport returns null and skips the service when no report',
      () async {
        expect(controller.report, isNull);
        final path = await controller.exportReport(
          dialogTitle: 'Export Topic Analysis',
        );
        expect(path, isNull);
        expect(fake.exportCalled, isFalse);
      },
    );

    test('clear() resets imported source and provenance to defaults', () async {
      fake.importResult = _sampleFile();
      await controller.importReport(dialogTitle: 'Import Topic Analysis');
      expect(controller.isImported, isTrue);

      controller.clear();

      expect(controller.isImported, isFalse);
      expect(controller.report, isNull);
      expect(controller.reportClusterName, isNull);
      expect(controller.reportExportedAt, isNull);
    });

    test('startAnalysis resets the source to live', () async {
      fake.importResult = _sampleFile();
      await controller.importReport(dialogTitle: 'Import Topic Analysis');
      expect(controller.isImported, isTrue);

      await controller.startAnalysis(
        const ClusterProfile(
          name: 'test',
          bootstrapServers: 'localhost:9092',
          tlsVerification: TlsVerification.enabled,
        ),
        'orders',
      );

      // The scan itself will fail in this environment (no native bridge), but
      // the source must have been reset before the scan was attempted.
      expect(controller.isImported, isFalse);
      expect(controller.reportClusterName, isNull);
      await controller.stopAnalysis();
    });

    test('value filter setters and clearing', () {
      expect(controller.valueFilter, isNull);

      const filter = FieldValueFilter(
        fieldPath: 'attributes.region',
        value: 'EU',
      );
      controller.setValueFilter(filter);
      expect(controller.valueFilter, equals(filter));

      controller.clearValueFilter();
      expect(controller.valueFilter, isNull);
    });

    test(
      'startAnalysis rejects an empty field path and does not start',
      () async {
        const invalidFilter = FieldValueFilter(fieldPath: '   ', value: 'EU');

        await controller.startAnalysis(
          const ClusterProfile(
            name: 'test',
            bootstrapServers: 'localhost:9092',
            tlsVerification: TlsVerification.enabled,
          ),
          'orders',
          valueFilter: invalidFilter,
        );

        expect(controller.isAnalyzing, isFalse);
        expect(controller.errorKind, TopicAnalysisErrorKind.emptyFieldPath);
      },
    );

    test('rescanWithFilter rejects an empty field path', () async {
      const invalidFilter = FieldValueFilter(fieldPath: '', value: 'EU');

      await controller.rescanWithFilter(invalidFilter);

      expect(controller.isAnalyzing, isFalse);
      expect(controller.errorKind, TopicAnalysisErrorKind.emptyFieldPath);
    });

    test('rescanWithFilter rejects if no previous scope exists', () async {
      const filter = FieldValueFilter(fieldPath: 'status', value: 'FAILED');

      await controller.rescanWithFilter(filter);

      expect(controller.isAnalyzing, isFalse);
      expect(controller.errorKind, TopicAnalysisErrorKind.noPreviousScope);
    });

    test('rescanWithFilter uses the last analysis scope', () async {
      const profile = ClusterProfile(
        name: 'staging',
        bootstrapServers: 'kafka:9092',
        tlsVerification: TlsVerification.enabled,
      );
      const topic = 'payments';

      // Start initial scan
      const scoped = AnalysisScope(
        messageLimit: 5000,
        limitFrom: ScopeLimitFrom.newest,
      );
      await controller.startAnalysis(profile, topic, scope: scoped);
      expect(controller.lastProfile, equals(profile));
      expect(controller.lastTopic, equals(topic));
      expect(controller.scope.messageLimit, 5000);

      // Now rescan with a filter
      const filter = FieldValueFilter(fieldPath: 'currency', value: 'EUR');
      await controller.rescanWithFilter(filter);

      expect(controller.valueFilter, equals(filter));
      expect(controller.lastProfile, equals(profile));
      expect(controller.lastTopic, equals(topic));
      expect(controller.scope.messageLimit, 5000);
      await controller.stopAnalysis();
    });

    test(
      'passes scope to stream factory and saves completed live scan once',
      () async {
        TopicAnalysisOptions? capturedOptions;
        final streamCtrl = StreamController<TopicAnalysisProgress>();
        final savedReports = <TopicAnalysisReport>[];
        final fakeHistory = _FakeHistoryService(
          onSave: (cluster, report, maxPerTopic) async {
            savedReports.add(report);
          },
        );
        final ctrl = TopicAnalysisController(
          historyService: fakeHistory,
          historyMaxPerTopicReader: () async => 5,
          streamFactory:
              ({required profile, required topic, required options}) {
                capturedOptions = options;
                return streamCtrl.stream;
              },
        );

        const profile = ClusterProfile(
          name: 'prod',
          bootstrapServers: 'kafka:9092',
          tlsVerification: TlsVerification.enabled,
        );
        const customScope = AnalysisScope(
          messageLimit: 2500,
          limitFrom: ScopeLimitFrom.oldest,
        );
        await ctrl.startAnalysis(profile, 'orders', scope: customScope);
        expect(capturedOptions?.scope, customScope);

        final report = _sampleReport('orders');
        streamCtrl.add(
          TopicAnalysisProgress(
            scannedMessages: 100,
            totalMessagesToScan: 100,
            progress: 1.0,
            messagesPerSecond: 1000,
            currentPartition: 0,
            isComplete: true,
            partialReport: report,
          ),
        );
        // Duplicate completion event should not save twice.
        streamCtrl.add(
          TopicAnalysisProgress(
            scannedMessages: 100,
            totalMessagesToScan: 100,
            progress: 1.0,
            messagesPerSecond: 1000,
            currentPartition: 0,
            isComplete: true,
            partialReport: report,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(savedReports.length, 1);

        // Failed scan should not save.
        final failCtrl = StreamController<TopicAnalysisProgress>();
        final ctrlFail = TopicAnalysisController(
          historyService: fakeHistory,
          historyMaxPerTopicReader: () async => 5,
          streamFactory:
              ({required profile, required topic, required options}) =>
                  failCtrl.stream,
        );
        await ctrlFail.startAnalysis(profile, 'orders');
        failCtrl.add(
          TopicAnalysisProgress(
            scannedMessages: 10,
            totalMessagesToScan: 100,
            progress: 0.1,
            messagesPerSecond: 100,
            currentPartition: 0,
            isComplete: true,
            errorMessage: 'broker error',
            partialReport: report,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(savedReports.length, 1);

        await streamCtrl.close();
        await failCtrl.close();
        ctrl.dispose();
        ctrlFail.dispose();
      },
    );

    test(
      'estimateScope tracks isEstimating and records result or error',
      () async {
        final ctrl = TopicAnalysisController(
          scopeEstimator:
              ({required profile, required topic, required scope}) async =>
                  const AnalysisScopeEstimate(
                    plannedTotal: 42000,
                    knownTotal: 42000,
                    complete: true,
                    unreadable: [],
                  ),
        );
        const profile = ClusterProfile(
          name: 'prod',
          bootstrapServers: 'kafka:9092',
          tlsVerification: TlsVerification.enabled,
        );
        final estimate = await ctrl.estimateScope(profile, 'orders');
        expect(estimate?.plannedTotal, 42000);
        expect(ctrl.isEstimating, isFalse);
        expect(ctrl.estimateError, isNull);

        final errCtrl = TopicAnalysisController(
          scopeEstimator:
              ({required profile, required topic, required scope}) async =>
                  throw Exception('timeout'),
        );
        final failed = await errCtrl.estimateScope(profile, 'orders');
        expect(failed, isNull);
        expect(errCtrl.isEstimating, isFalse);
        expect(errCtrl.estimateError, contains('timeout'));
        ctrl.dispose();
        errCtrl.dispose();
      },
    );

    test('defaults to payloadOnly duplicate scope and allows toggling', () {
      expect(
        controller.duplicateScope,
        equals(DuplicateDetectionScope.payloadOnly),
      );
      var notifyCount = 0;
      controller.addListener(() => notifyCount++);

      controller.setDuplicateScope(DuplicateDetectionScope.keyAndPayload);
      expect(
        controller.duplicateScope,
        equals(DuplicateDetectionScope.keyAndPayload),
      );
      expect(notifyCount, 1);
    });
  });
}

TopicAnalysisReport _sampleReport(String topic) => TopicAnalysisReport(
  topic: topic,
  totalMessages: 100,
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
  fieldFrequencies: const [],
  scanDurationMs: 10,
  sizePercentilesEstimated: false,
  estimatedDistinctKeys: 0,
  keyCardinalityCapped: false,
  hourlyTimeline: const [],
  timelineOutsideCount: 0,
);

class _FakeHistoryService extends TopicAnalysisHistoryService {
  final Future<void> Function(
    String clusterName,
    TopicAnalysisReport report,
    int maxPerTopic,
  )
  onSave;

  _FakeHistoryService({required this.onSave});

  @override
  Future<HistorySaveResult> save({
    required String clusterName,
    required TopicAnalysisReport report,
    required int maxPerTopic,
    DateTime? now,
  }) async {
    await onSave(clusterName, report, maxPerTopic);
    return const HistorySaveResult(savedPath: '/tmp/fake.json');
  }
}
