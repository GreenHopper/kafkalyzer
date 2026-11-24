import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_history_service.dart';

TopicAnalysisReport _makeReport({
  required String topic,
  required int scanReferenceTimeMs,
  int totalMessages = 10,
}) => TopicAnalysisReport(
  topic: topic,
  totalMessages: totalMessages,
  totalBytes: totalMessages * 100,
  minMessageSize: 10,
  maxMessageSize: 100,
  avgMessageSize: 50.0,
  tombstonesCount: 0,
  isCompacted: false,
  cleanupPolicyUnknown: false,
  nullKeysCount: 0,
  partitionStats: const [],
  hourlyDistribution: const [],
  topKeys: const [],
  contentTypeDistribution: const [],
  fieldFrequencies: const [],
  scanDurationMs: 100,
  messageSizePercentiles: null,
  sizePercentilesEstimated: false,
  estimatedDistinctKeys: 0,
  keyCardinalityCapped: false,
  hourlyTimeline: const [],
  scanReferenceTimeMs: scanReferenceTimeMs,
  completeFromMs: null,
  timelineOutsideCount: 0,
  valueFilterResult: null,
  duplicateAnalysisResult: null,
);

void main() {
  late Directory tempDir;
  late TopicAnalysisHistoryService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('kafkalyzer_hist_test_');
    service = TopicAnalysisHistoryService(
      supportDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves and lists entries newest first', () async {
    await service.save(
      clusterName: 'prod',
      report: _makeReport(
        topic: 'orders',
        scanReferenceTimeMs: 1700000001000,
        totalMessages: 1,
      ),
      maxPerTopic: 10,
    );
    await service.save(
      clusterName: 'prod',
      report: _makeReport(
        topic: 'orders',
        scanReferenceTimeMs: 1700000003000,
        totalMessages: 3,
      ),
      maxPerTopic: 10,
    );
    await service.save(
      clusterName: 'prod',
      report: _makeReport(
        topic: 'orders',
        scanReferenceTimeMs: 1700000002000,
        totalMessages: 2,
      ),
      maxPerTopic: 10,
    );

    final listing = await service.list('prod', 'orders');
    expect(listing.unreadableCount, 0);
    expect(
      listing.entries.map((e) => e.report.totalMessages.toInt()).toList(),
      [3, 2, 1],
    );
  });

  test(
    '11th save with N=10 deletes only oldest of that topic; other topic untouched',
    () async {
      await service.save(
        clusterName: 'prod',
        report: _makeReport(
          topic: 'other',
          scanReferenceTimeMs: 1700000000000,
          totalMessages: 99,
        ),
        maxPerTopic: 10,
      );

      for (var i = 1; i <= 11; i++) {
        await service.save(
          clusterName: 'prod',
          report: _makeReport(
            topic: 'orders',
            scanReferenceTimeMs: 1700000000000 + i * 1000,
            totalMessages: i,
          ),
          maxPerTopic: 10,
        );
      }

      final orders = await service.list('prod', 'orders');
      expect(orders.entries.length, 10);
      expect(orders.entries.last.report.totalMessages.toInt(), 2);
      expect(orders.entries.first.report.totalMessages.toInt(), 11);

      final other = await service.list('prod', 'other');
      expect(other.entries.length, 1);
      expect(other.entries.first.report.totalMessages.toInt(), 99);
    },
  );

  test('maxPerTopic=0 saves nothing and deletes nothing', () async {
    await service.save(
      clusterName: 'prod',
      report: _makeReport(topic: 'orders', scanReferenceTimeMs: 1700000001000),
      maxPerTopic: 10,
    );

    final res = await service.save(
      clusterName: 'prod',
      report: _makeReport(topic: 'orders', scanReferenceTimeMs: 1700000002000),
      maxPerTopic: 0,
    );
    expect(res.savedPath, isNull);

    final listing = await service.list('prod', 'orders');
    expect(listing.entries.length, 1);
    expect(listing.entries.first.report.scanReferenceTimeMs, 1700000001000);
  });

  test(
    'special names ../x, a/b, a_b stay inside root and use distinct directories',
    () async {
      final rootPath = p.join(
        tempDir.path,
        TopicAnalysisHistoryService.rootFolderName,
      );
      final paths = <String>[];
      for (final topic in ['../x', 'a/b', 'a_b']) {
        final res = await service.save(
          clusterName: 'c1',
          report: _makeReport(topic: topic, scanReferenceTimeMs: 1700000001000),
          maxPerTopic: 10,
        );
        expect(res.savedPath, isNotNull);
        expect(p.isWithin(rootPath, res.savedPath!), isTrue);
        paths.add(p.dirname(res.savedPath!));
      }
      expect(paths.toSet().length, 3);
    },
  );

  test(
    'foreign and corrupt matching files are preserved and counted as unreadable; envelope mismatch skipped',
    () async {
      final saved = await service.save(
        clusterName: 'prod',
        report: _makeReport(
          topic: 'orders',
          scanReferenceTimeMs: 1700000001000,
        ),
        maxPerTopic: 10,
      );
      final topicDir = Directory(p.dirname(saved.savedPath!));

      // Non-matching file is ignored and never deleted.
      final notesFile = File(p.join(topicDir.path, 'notes.txt'));
      await notesFile.writeAsString('keep me');

      // Matching filename with corrupt JSON -> unreadable, not deleted.
      final corruptFile = File(p.join(topicDir.path, '1700000002000-1.json'));
      await corruptFile.writeAsString('{not valid json');

      // Matching filename with foreign JSON -> unreadable, not deleted.
      final foreignFile = File(p.join(topicDir.path, '1700000003000-1.json'));
      await foreignFile.writeAsString('{"hello": "world"}');

      // Matching filename with wrong cluster/topic in envelope -> skipped, not unreadable.
      final mismatchFile = File(p.join(topicDir.path, '1700000004000-1.json'));
      final mismatchEnvelope = TopicAnalysisReportFile(
        exportedAt: DateTime.utc(2026, 1, 1),
        clusterName: 'other-cluster',
        report: _makeReport(
          topic: 'orders',
          scanReferenceTimeMs: 1700000004000,
        ),
      );
      await mismatchFile.writeAsString(mismatchEnvelope.toJson());

      final listing = await service.list('prod', 'orders');
      expect(listing.entries.length, 1);
      expect(listing.unreadableCount, 2);
      expect(await notesFile.exists(), isTrue);
      expect(await corruptFile.exists(), isTrue);
      expect(await foreignFile.exists(), isTrue);
      expect(await mismatchFile.exists(), isTrue);
    },
  );

  test('write failure throws HistoryStorageException', () async {
    // Create a regular file where the root directory should be so create(recursive: true) fails.
    final blockingFile = File(
      p.join(tempDir.path, TopicAnalysisHistoryService.rootFolderName),
    );
    await blockingFile.writeAsString('not a directory');

    await expectLater(
      service.save(
        clusterName: 'prod',
        report: _makeReport(
          topic: 'orders',
          scanReferenceTimeMs: 1700000001000,
        ),
        maxPerTopic: 10,
      ),
      throwsA(isA<HistoryStorageException>()),
    );
  });

  test('clearAll deletes all saved reports', () async {
    await service.save(
      clusterName: 'prod',
      report: _makeReport(topic: 'orders', scanReferenceTimeMs: 1700000001000),
      maxPerTopic: 10,
    );
    await service.save(
      clusterName: 'staging',
      report: _makeReport(
        topic: 'payments',
        scanReferenceTimeMs: 1700000002000,
      ),
      maxPerTopic: 10,
    );

    await service.clearAll();
    expect((await service.list('prod', 'orders')).entries, isEmpty);
    expect((await service.list('staging', 'payments')).entries, isEmpty);
  });
}
