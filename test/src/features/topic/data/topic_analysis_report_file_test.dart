import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

TopicAnalysisReport _populatedReport() => TopicAnalysisReport(
  topic: 'orders',
  totalMessages: 1000,
  totalBytes: 20480,
  minMessageSize: 1,
  maxMessageSize: 50,
  avgMessageSize: 20.48,
  tombstonesCount: 3,
  isCompacted: true,
  nullKeysCount: 12,
  partitionStats: [
    const PartitionAnalysis(
      partition: 0,
      messageCount: 500,
      byteSize: 10240,
      percentage: 50.0,
      earliestOffset: 0,
      latestOffset: 499,
    ),
    const PartitionAnalysis(
      partition: 1,
      messageCount: 500,
      byteSize: 10240,
      percentage: 50.0,
      earliestOffset: 0,
      latestOffset: 499,
    ),
  ],
  hourlyDistribution: [
    const HourlyCount(hour: 9, count: 100, percentage: 10.0),
    const HourlyCount(hour: 14, count: 200, percentage: 20.0),
  ],
  topKeys: [
    const KeyOccurrence(key: 'k1', count: 50, percentage: 5.0),
    const KeyOccurrence(key: 'k2', count: 30, percentage: 3.0),
  ],
  contentTypeDistribution: [
    const TypeOccurrence(typeName: 'json', count: 900, percentage: 90.0),
    const TypeOccurrence(typeName: 'binary', count: 100, percentage: 10.0),
  ],
  fieldFrequencies: [
    const FieldOccurrence(
      fieldName: 'id',
      count: 900,
      percentage: 90.0,
      topValues: [
        FieldValueOccurrence(
          value: '1',
          count: 10,
          percentage: 1.11,
          truncated: false,
        ),
      ],
      valuesCapped: false,
    ),
    const FieldOccurrence(
      fieldName: 'status',
      count: 800,
      percentage: 80.0,
      topValues: [
        FieldValueOccurrence(
          value: 'paid',
          count: 400,
          percentage: 50.0,
          truncated: false,
        ),
        FieldValueOccurrence(
          value: 'new',
          count: 400,
          percentage: 50.0,
          truncated: false,
        ),
      ],
      valuesCapped: false,
    ),
  ],
  scanDurationMs: 12345,
  messageSizePercentiles: null,
  sizePercentilesEstimated: false,
  estimatedDistinctKeys: 0,
  keyCardinalityCapped: false,
  hourlyTimeline: [
    const HourBucket(epochHour: 498158, count: 500),
    const HourBucket(epochHour: 498159, count: 500),
  ],
  scanReferenceTimeMs: 1793370600000,
  completeFromMs: 1793367000000,
  timelineOutsideCount: 0,
  valueFilterResult: const ValueFilterResult(
    fieldPath: 'status',
    value: 'paid',
    messagesWithField: 800,
    matchedMessages: 400,
    matchedTimeline: [
      HourBucket(epochHour: 498158, count: 200),
      HourBucket(epochHour: 498159, count: 200),
    ],
  ),
  duplicateAnalysisResult: const DuplicateAnalysisResult(
    scope: DuplicateDetectionScope.payloadOnly,
    totalMessages: 1000,
    uniqueMessages: 800,
    duplicateMessages: 200,
    duplicateRate: 20.0,
    topDuplicates: [
      TopDuplicateOccurrence(
        key: 'k1',
        payloadPreview: '{"id":1}',
        count: 50,
        percentage: 5.0,
        samplePartition: 0,
        sampleOffset: 12,
        sampleTimestampMs: 1793370600000,
      ),
    ],
  ),
);

TopicAnalysisReport _emptyReport() => TopicAnalysisReport(
  topic: 'empty-topic',
  totalMessages: 0,
  totalBytes: 0,
  minMessageSize: 0,
  maxMessageSize: 0,
  avgMessageSize: 0.0,
  tombstonesCount: 0,
  isCompacted: false,
  nullKeysCount: 0,
  partitionStats: const [],
  hourlyDistribution: const [],
  topKeys: const [],
  contentTypeDistribution: const [],
  fieldFrequencies: const [],
  scanDurationMs: 0,
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
);

void main() {
  group('TopicAnalysisReportFile', () {
    test(
      'round-trips a fully populated report (all sub-lists incl. top_values)',
      () {
        final report = _populatedReport();
        final file = TopicAnalysisReportFile(
          exportedAt: DateTime.utc(2026, 8, 19, 12, 34, 56, 789),
          clusterName: 'prod-eu-1',
          report: report,
        );

        final json = file.toJson();
        final decoded = TopicAnalysisReportFile.fromJson(json);

        // Compare the full serialized structure (deep) rather than the report
        // object directly, since the generated `==` compares nested lists by
        // identity, not by value.
        expect(decoded.toMap(), file.toMap());
        expect(decoded.clusterName, 'prod-eu-1');
        expect(decoded.version, 3);
        expect(
          decoded.exportedAt.toUtc(),
          DateTime.utc(2026, 8, 19, 12, 34, 56, 789),
        );
      },
    );

    test('round-trips an empty report', () {
      final report = _emptyReport();
      final file = TopicAnalysisReportFile(
        exportedAt: DateTime.utc(2026, 1, 1),
        clusterName: null,
        report: report,
      );

      final decoded = TopicAnalysisReportFile.fromJson(file.toJson());

      expect(decoded.toMap(), file.toMap());
      expect(decoded.clusterName, isNull);
    });

    test('toMap uses the canonical snake_case shape and identifier', () {
      final file = TopicAnalysisReportFile(
        exportedAt: DateTime.utc(2026, 1, 1),
        report: _populatedReport(),
      );
      final map = file.toMap();

      expect(map['kafkalyzer'], 'topic-analysis-report');
      expect(map['version'], 3);
      expect(map['report']['total_messages'], 1000);
      expect(map['report']['avg_message_size'], 20.48);
      expect(map['report']['is_compacted'], true);
      expect(
        map['report']['partition_stats'],
        isA<List<dynamic>>().having(
          (l) => l.first['message_count'],
          'first message_count',
          500,
        ),
      );
      expect(
        map['report']['field_frequencies'][0]['top_values'][0]['value'],
        '1',
      );
      expect(map['report']['hourly_timeline'], isNotEmpty);
      expect(map['report']['value_filter_result']['field_path'], 'status');
      expect(
        map['report']['duplicate_analysis_result']['duplicate_messages'],
        200,
      );
    });

    test(
      'imports a version 1 file and marks new timeline, filter and duplicates as absent',
      () {
        const v1Json = '''{
        "kafkalyzer": "topic-analysis-report",
        "version": 1,
        "exportedAt": "2026-08-19T12:34:56.789Z",
        "clusterName": "legacy-cluster",
        "report": {
          "topic": "v1-topic",
          "total_messages": 100,
          "total_bytes": 2048,
          "min_message_size": 10,
          "max_message_size": 100,
          "avg_message_size": 20.48,
          "tombstones_count": 0,
          "is_compacted": false,
          "null_keys_count": 0,
          "partition_stats": [],
          "hourly_distribution": [],
          "top_keys": [],
          "content_type_distribution": [],
          "field_frequencies": [],
          "scan_duration_ms": 1000
        }
      }''';

        final file = TopicAnalysisReportFile.fromJson(v1Json);
        expect(file.version, 1);
        expect(file.clusterName, 'legacy-cluster');
        expect(file.report.topic, 'v1-topic');
        expect(file.report.hourlyTimeline, isEmpty);
        expect(file.report.scanReferenceTimeMs, isNull);
        expect(file.report.completeFromMs, isNull);
        expect(file.report.timelineOutsideCount, 0);
        expect(file.report.valueFilterResult, isNull);
        expect(file.report.duplicateAnalysisResult, isNull);
      },
    );

    test('imports a version 2 file without duplicate detection', () {
      const v2Json = '''{
        "kafkalyzer": "topic-analysis-report",
        "version": 2,
        "exportedAt": "2026-10-30T10:00:00.000Z",
        "clusterName": "v2-cluster",
        "report": {
          "topic": "v2-topic",
          "total_messages": 50,
          "total_bytes": 1000,
          "min_message_size": 20,
          "max_message_size": 20,
          "avg_message_size": 20.0,
          "tombstones_count": 0,
          "is_compacted": false,
          "null_keys_count": 0,
          "partition_stats": [],
          "hourly_distribution": [],
          "top_keys": [],
          "content_type_distribution": [],
          "field_frequencies": [],
          "scan_duration_ms": 500,
          "hourly_timeline": [],
          "value_filter_result": null
        }
      }''';

      final file = TopicAnalysisReportFile.fromJson(v2Json);
      expect(file.version, 2);
      expect(file.clusterName, 'v2-cluster');
      expect(file.report.topic, 'v2-topic');
      expect(file.report.duplicateAnalysisResult, isNull);
    });

    test('rejects version 4 as unsupported', () {
      const v4Json = '''{
        "kafkalyzer": "topic-analysis-report",
        "version": 4,
        "report": {
          "topic": "v4-topic"
        }
      }''';

      expect(
        () => TopicAnalysisReportFile.fromJson(v4Json),
        throwsA(
          isA<TopicAnalysisImportError>()
              .having(
                (e) => e.kind,
                'kind',
                TopicAnalysisImportErrorKind.unsupportedVersion,
              )
              .having((e) => e.foundVersion, 'foundVersion', 4),
        ),
      );
    });

    test('rejects a file without the expected identifier', () {
      const json =
          '{ "kafkalyzer": "something-else", "version": 1, '
          '"report": {} }';

      expect(
        () => TopicAnalysisReportFile.fromJson(json),
        throwsA(
          isA<TopicAnalysisImportError>().having(
            (e) => e.kind,
            'kind',
            TopicAnalysisImportErrorKind.notAnAnalysisFile,
          ),
        ),
      );
    });

    test('rejects an unsupported version (carrying the found version)', () {
      const json =
          '{ "kafkalyzer": "topic-analysis-report", "version": 99, '
          '"report": {} }';

      expect(
        () => TopicAnalysisReportFile.fromJson(json),
        throwsA(
          isA<TopicAnalysisImportError>()
              .having(
                (e) => e.kind,
                'kind',
                TopicAnalysisImportErrorKind.unsupportedVersion,
              )
              .having((e) => e.foundVersion, 'foundVersion', 99),
        ),
      );
    });

    test('rejects a JSON array (not an analysis object)', () {
      expect(
        () => TopicAnalysisReportFile.fromJson('[1,2,3]'),
        throwsA(
          isA<TopicAnalysisImportError>().having(
            (e) => e.kind,
            'kind',
            TopicAnalysisImportErrorKind.notAnAnalysisFile,
          ),
        ),
      );
    });

    test('rejects invalid JSON as malformed', () {
      expect(
        () => TopicAnalysisReportFile.fromJson('not json {'),
        throwsA(
          isA<TopicAnalysisImportError>().having(
            (e) => e.kind,
            'kind',
            TopicAnalysisImportErrorKind.malformed,
          ),
        ),
      );
    });

    test('rejects a report with a missing required field as malformed', () {
      final json =
          '{ "kafkalyzer": "topic-analysis-report", "version": 1, '
          '"report": { "topic": "x" } }';

      expect(
        () => TopicAnalysisReportFile.fromJson(json),
        throwsA(
          isA<TopicAnalysisImportError>().having(
            (e) => e.kind,
            'kind',
            TopicAnalysisImportErrorKind.malformed,
          ),
        ),
      );
    });
  });
}
