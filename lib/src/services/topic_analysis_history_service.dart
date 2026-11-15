import 'dart:io';
import 'dart:isolate';
import 'dart:convert';

import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';

typedef SupportDirectoryProvider = Future<Directory> Function();

class TopicAnalysisHistoryEntry {
  final String filePath;
  final DateTime exportedAt;
  final String? clusterName;
  final TopicAnalysisReport report;

  const TopicAnalysisHistoryEntry({
    required this.filePath,
    required this.exportedAt,
    required this.clusterName,
    required this.report,
  });
}

class HistoryListing {
  final List<TopicAnalysisHistoryEntry> entries;
  final int unreadableCount;

  const HistoryListing({required this.entries, required this.unreadableCount});
}

class HistorySaveResult {
  final String? savedPath;
  final String? cleanupError;

  const HistorySaveResult({this.savedPath, this.cleanupError});
}

class HistoryListingException implements Exception {
  final String message;
  const HistoryListingException(this.message);

  @override
  String toString() => 'HistoryListingException: $message';
}

class HistoryStorageException implements Exception {
  final String message;
  const HistoryStorageException(this.message);

  @override
  String toString() => 'HistoryStorageException: $message';
}

class TopicAnalysisHistoryService {
  static const String rootFolderName = 'analysis_history';
  static final RegExp fileNamePattern = RegExp(r'^\d{13}-\d+\.json$');

  final SupportDirectoryProvider _supportDirectoryProvider;
  final Logger? _logger;
  int _counter = 0;

  TopicAnalysisHistoryService({
    SupportDirectoryProvider? supportDirectoryProvider,
    Logger? logger,
  }) : _supportDirectoryProvider =
           supportDirectoryProvider ?? getApplicationSupportDirectory,
       _logger = logger;

  /// Computes the 16-hex-digit FNV-1a-64 digest of UTF-8
  /// `clusterName + "\u0000" + topic`.
  static String directoryKeyFor(String clusterName, String topic) {
    final bytes = utf8.encode('$clusterName\u0000$topic');
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = BigInt.parse('cbf29ce484222325', radix: 16);
    for (final b in bytes) {
      hash = ((hash ^ BigInt.from(b)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  Future<Directory> _rootDirectory() async {
    final support = await _supportDirectoryProvider();
    return Directory(p.join(support.path, rootFolderName));
  }

  Future<Directory> _topicDirectory(String clusterName, String topic) async {
    final root = await _rootDirectory();
    final key = directoryKeyFor(clusterName, topic);
    if (!isSafePathSegment(key)) {
      throw const HistoryStorageException('Invalid history directory key');
    }
    final normalizedRoot = p.normalize(root.path);
    final target = p.normalize(p.join(normalizedRoot, key));
    if (!p.isWithin(normalizedRoot, target)) {
      throw const HistoryStorageException(
        'Resolved history directory escapes root',
      );
    }
    return Directory(target);
  }

  /// Saves [report] for ([clusterName], [report.topic]) and prunes older
  /// entries beyond [maxPerTopic]. When [maxPerTopic] <= 0, nothing is saved
  /// and nothing is deleted.
  ///
  /// Throws [HistoryStorageException] if writing fails. Cleanup deletion
  /// failures are returned in [HistorySaveResult.cleanupError] rather than
  /// failing the save.
  Future<HistorySaveResult> save({
    required String clusterName,
    required TopicAnalysisReport report,
    required int maxPerTopic,
    DateTime? now,
  }) async {
    if (maxPerTopic <= 0) {
      return const HistorySaveResult();
    }

    final dir = await _topicDirectory(clusterName, report.topic);
    final timestampMs =
        report.scanReferenceTimeMs?.toInt() ??
        (now ?? DateTime.now().toUtc()).millisecondsSinceEpoch;
    final tsPrefix = timestampMs
        .clamp(0, 9999999999999)
        .toString()
        .padLeft(13, '0');
    final seq = ++_counter;
    final fileName = '$tsPrefix-$seq.json';
    final filePath = p.join(dir.path, fileName);
    final tmpPath = p.join(dir.path, '$fileName.tmp');

    final envelope = TopicAnalysisReportFile(
      exportedAt: (now ?? DateTime.now().toUtc()).toUtc(),
      clusterName: clusterName,
      report: report,
    );

    try {
      await dir.create(recursive: true);
      final tmpFile = File(tmpPath);
      await tmpFile.writeAsString(envelope.toJson(), flush: true);
      await tmpFile.rename(filePath);
    } catch (e) {
      _logger?.w('Failed to save topic analysis history: $e');
      try {
        final tmpFile = File(tmpPath);
        if (await tmpFile.exists()) {
          await tmpFile.delete();
        }
      } catch (_) {}
      throw HistoryStorageException(e.toString());
    }

    String? cleanupError;
    try {
      final matching = <File>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final base = p.basename(entity.path);
        if (fileNamePattern.hasMatch(base)) {
          matching.add(entity);
        }
      }
      matching.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));
      if (matching.length > maxPerTopic) {
        final failures = <String>[];
        for (final old in matching.sublist(maxPerTopic)) {
          try {
            await old.delete();
          } catch (e) {
            failures.add(e.toString());
          }
        }
        if (failures.isNotEmpty) {
          cleanupError = failures.first;
          _logger?.w(
            'Failed to prune old analysis history entries: ${failures.join('; ')}',
          );
        }
      }
    } catch (e) {
      cleanupError = e.toString();
      _logger?.w('Failed to list analysis history for pruning: $e');
    }

    return HistorySaveResult(savedPath: filePath, cleanupError: cleanupError);
  }

  /// Lists saved reports for ([clusterName], [topic]), newest first.
  ///
  /// Throws [HistoryListingException] if the directory cannot be listed.
  Future<HistoryListing> list(String clusterName, String topic) async {
    final dir = await _topicDirectory(clusterName, topic);
    if (!await dir.exists()) {
      return const HistoryListing(entries: [], unreadableCount: 0);
    }

    final List<String> candidatePaths;
    try {
      final files = <String>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final base = p.basename(entity.path);
        if (fileNamePattern.hasMatch(base)) {
          files.add(entity.path);
        }
      }
      files.sort((a, b) => p.basename(b).compareTo(p.basename(a)));
      candidatePaths = files;
    } catch (e) {
      throw HistoryListingException(e.toString());
    }

    if (candidatePaths.isEmpty) {
      return const HistoryListing(entries: [], unreadableCount: 0);
    }

    return Isolate.run(() => _parseEntries(candidatePaths, clusterName, topic));
  }

  static HistoryListing _parseEntries(
    List<String> paths,
    String expectedCluster,
    String expectedTopic,
  ) {
    final entries = <TopicAnalysisHistoryEntry>[];
    var unreadableCount = 0;

    for (final path in paths) {
      try {
        final raw = File(path).readAsStringSync();
        final file = TopicAnalysisReportFile.fromJson(raw);
        if (file.clusterName != expectedCluster ||
            file.report.topic != expectedTopic) {
          continue;
        }
        entries.add(
          TopicAnalysisHistoryEntry(
            filePath: path,
            exportedAt: file.exportedAt,
            clusterName: file.clusterName,
            report: file.report,
          ),
        );
      } catch (_) {
        unreadableCount += 1;
      }
    }

    return HistoryListing(entries: entries, unreadableCount: unreadableCount);
  }

  /// Deletes all saved analysis history across all clusters and topics.
  ///
  /// Throws [HistoryStorageException] if deletion fails.
  Future<void> clearAll() async {
    final root = await _rootDirectory();
    if (!await root.exists()) return;
    try {
      await root.delete(recursive: true);
    } catch (e) {
      _logger?.w('Failed to clear analysis history: $e');
      throw HistoryStorageException(e.toString());
    }
  }
}
