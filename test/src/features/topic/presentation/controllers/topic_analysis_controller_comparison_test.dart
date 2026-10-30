import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:mockito/mockito.dart';

import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/report_compare.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';

import '../../../../rust/api/rust_mocks.mocks.dart';

class FakeExportService extends TopicAnalysisExportService {
  TopicAnalysisReportFile? importResult;
  int importCalls = 0;

  @override
  Future<String?> export(TopicAnalysisReportFile file) async => null;

  @override
  Future<TopicAnalysisReportFile?> importFile() async {
    importCalls++;
    return importResult;
  }
}

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
  fieldFrequencies: const [
    FieldOccurrence(
      fieldName: 'amount',
      count: 800,
      percentage: 80.0,
      topValues: [],
      valuesCapped: false,
    ),
  ],
  scanDurationMs: 1000,
  messageSizePercentiles: null,
  sizePercentilesEstimated: false,
  estimatedDistinctKeys: 0,
  keyCardinalityCapped: false,
  hourlyTimeline: const [],
  scanReferenceTimeMs: null,
  completeFromMs: null,
  timelineOutsideCount: 0,
  valueFilterResult: null,
);

TopicAnalysisReportFile _file(String topic, int messages) =>
    TopicAnalysisReportFile(
      exportedAt: DateTime.utc(2026, 8, 19, 12),
      clusterName: 'staging-eu-1',
      report: _report(topic, messages),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  late Logger logger;
  late FakeExportService fake;
  late TopicAnalysisController controller;

  setUp(() {
    logger = Logger(printer: PrettyPrinter(methodCount: 0));
    fake = FakeExportService();
    controller = TopicAnalysisController(logger: logger, exportService: fake);
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
          MetricDelta(metric: 'size_p95', comparable: false),
        ],
        fields: [
          FieldDelta(
            field: 'amount',
            before: 800,
            after: 900,
            added: false,
            removed: false,
            countDelta: 100,
          ),
          FieldDelta(field: 'coupon', after: 40, added: true, removed: false),
        ],
      ),
    );
  });

  group('report comparison', () {
    test(
      'two imported reports compare without any cluster connection',
      () async {
        fake.importResult = _file('orders', 1000);
        expect(await controller.importReport(), isTrue);

        fake.importResult = _file('orders', 1200);
        await controller.pickComparisonBase();

        expect(fake.importCalls, 2);
        expect(controller.comparison, isNotNull);
        expect(controller.comparison!.metrics.first.relativePercent, 20.0);
        expect(controller.mismatchTopicA, isNull);
      },
    );

    test(
      'a pair of different topics is rejected and names both topics',
      () async {
        fake.importResult = _file('orders', 1000);
        await controller.importReport();

        fake.importResult = _file('shipments', 1000);
        await controller.pickComparisonBase();

        expect(controller.comparison, isNull);
        expect(controller.mismatchTopicA, 'shipments');
        expect(controller.mismatchTopicB, 'orders');
      },
    );

    test(
      'asking for a comparison with a single report prompts for the second',
      () async {
        await controller.pickComparisonBase();

        expect(controller.awaitingSecondReport, isTrue);
        expect(fake.importCalls, 0);
        expect(controller.comparison, isNull);
      },
    );

    test('a new scan drops a stale comparison', () async {
      fake.importResult = _file('orders', 1000);
      await controller.importReport();
      await controller.setComparisonBase(_report('orders', 800));
      expect(controller.comparison, isNotNull);

      await controller.startAnalysis(
        const ClusterProfile(name: 'test', bootstrapServers: 'localhost:9092'),
        'orders',
      );
      await controller.stopAnalysis();

      expect(controller.comparison, isNull);
      expect(controller.baseReport, isNull);
    });
  });
}
