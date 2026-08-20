import 'dart:convert';

import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// The kind of failure when importing a topic analysis report file.
enum TopicAnalysisImportErrorKind {
  notAnAnalysisFile,
  unsupportedVersion,
  malformed,
}

/// Thrown when a selected file cannot be imported as a topic analysis report.
class TopicAnalysisImportError implements Exception {
  final TopicAnalysisImportErrorKind kind;
  final int? foundVersion;
  final String? detail;

  const TopicAnalysisImportError(this.kind, {this.foundVersion, this.detail});

  @override
  String toString() {
    switch (kind) {
      case TopicAnalysisImportErrorKind.notAnAnalysisFile:
        return 'Not a Kafkalyzer analysis report';
      case TopicAnalysisImportErrorKind.unsupportedVersion:
        return 'Unsupported format version: $foundVersion';
      case TopicAnalysisImportErrorKind.malformed:
        return 'Malformed analysis report${detail == null ? '' : ': $detail'}';
    }
  }
}

/// A [TopicAnalysisReport] wrapped in a stable, versioned, self-describing
/// envelope that also carries provenance (source cluster name + export time).
///
/// This is the single source of truth for the on-disk file format used by the
/// export/import feature. All (de)serialization lives here so the schema stays
/// in one place and can be evolved (and unit-tested) without touching the UI.
class TopicAnalysisReportFile {
  static const String formatIdentifier = 'topic-analysis-report';
  static const int currentVersion = 1;
  static const Set<int> supportedVersions = {1};

  final int version;
  final DateTime exportedAt;
  final String? clusterName;
  final TopicAnalysisReport report;

  TopicAnalysisReportFile({
    this.version = currentVersion,
    required this.exportedAt,
    this.clusterName,
    required this.report,
  });

  /// Serializes the envelope and report to a JSON-encodable map using the
  /// canonical snake_case keys defined by the file format.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'kafkalyzer': formatIdentifier,
      'version': version,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'clusterName': clusterName,
      'report': _reportToMap(report),
    };
  }

  /// Serializes to a pretty-printed JSON string.
  String toJson() => const JsonEncoder.withIndent('  ').convert(toMap());

  /// Parses and validates [source], throwing a [TopicAnalysisImportError]
  /// when it is not a valid, supported analysis report file.
  factory TopicAnalysisReportFile.fromMap(Map<String, dynamic> source) {
    if (source['kafkalyzer'] != formatIdentifier) {
      throw const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.notAnAnalysisFile,
      );
    }

    final dynamic rawVersion = source['version'];
    final int? version = rawVersion is int ? rawVersion : null;
    if (version == null || !supportedVersions.contains(version)) {
      throw TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.unsupportedVersion,
        foundVersion: version,
      );
    }

    final dynamic reportRaw = source['report'];
    if (reportRaw is! Map<String, dynamic>) {
      throw const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.malformed,
        detail: 'missing or invalid "report"',
      );
    }

    final TopicAnalysisReport report;
    try {
      report = _reportFromMap(reportRaw);
    } catch (e) {
      throw TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.malformed,
        detail: e.toString(),
      );
    }

    var exportedAt = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    final dynamic exportedRaw = source['exportedAt'];
    if (exportedRaw is String) {
      final parsed = DateTime.tryParse(exportedRaw);
      if (parsed != null) exportedAt = parsed.toUtc();
    }

    final dynamic clusterRaw = source['clusterName'];
    final String? clusterName = clusterRaw is String && clusterRaw.isNotEmpty
        ? clusterRaw
        : null;

    return TopicAnalysisReportFile(
      version: version,
      exportedAt: exportedAt,
      clusterName: clusterName,
      report: report,
    );
  }

  factory TopicAnalysisReportFile.fromJson(String source) {
    dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } catch (_) {
      throw const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.malformed,
        detail: 'invalid JSON',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.notAnAnalysisFile,
      );
    }
    return TopicAnalysisReportFile.fromMap(decoded);
  }
}

// --- Report (de)serialization helpers -----------------------------------------

Map<String, dynamic> _reportToMap(TopicAnalysisReport r) => <String, dynamic>{
  'topic': r.topic,
  'total_messages': r.totalMessages.toInt(),
  'total_bytes': r.totalBytes.toInt(),
  'min_message_size': r.minMessageSize.toInt(),
  'max_message_size': r.maxMessageSize.toInt(),
  'avg_message_size': r.avgMessageSize,
  'tombstones_count': r.tombstonesCount.toInt(),
  'is_compacted': r.isCompacted,
  'null_keys_count': r.nullKeysCount.toInt(),
  'partition_stats': r.partitionStats.map(_partitionToMap).toList(),
  'hourly_distribution': r.hourlyDistribution.map(_hourlyToMap).toList(),
  'top_keys': r.topKeys.map(_keyToMap).toList(),
  'content_type_distribution': r.contentTypeDistribution
      .map(_typeToMap)
      .toList(),
  'field_frequencies': r.fieldFrequencies.map(_fieldToMap).toList(),
  'scan_duration_ms': r.scanDurationMs.toInt(),
};

TopicAnalysisReport _reportFromMap(
  Map<String, dynamic> m,
) => TopicAnalysisReport(
  topic: _toStr(m['topic']),
  totalMessages: _toInt(m['total_messages']),
  totalBytes: _toInt(m['total_bytes']),
  minMessageSize: _toInt(m['min_message_size']),
  maxMessageSize: _toInt(m['max_message_size']),
  avgMessageSize: _toDouble(m['avg_message_size']),
  tombstonesCount: _toInt(m['tombstones_count']),
  isCompacted: _toBool(m['is_compacted']),
  nullKeysCount: _toInt(m['null_keys_count']),
  partitionStats: _list(m['partition_stats']).map(_partitionFromMap).toList(),
  hourlyDistribution: _list(
    m['hourly_distribution'],
  ).map(_hourlyFromMap).toList(),
  topKeys: _list(m['top_keys']).map(_keyFromMap).toList(),
  contentTypeDistribution: _list(
    m['content_type_distribution'],
  ).map(_typeFromMap).toList(),
  fieldFrequencies: _list(m['field_frequencies']).map(_fieldFromMap).toList(),
  scanDurationMs: _toInt(m['scan_duration_ms']),
);

Map<String, dynamic> _partitionToMap(PartitionAnalysis p) => <String, dynamic>{
  'partition': p.partition,
  'message_count': p.messageCount.toInt(),
  'byte_size': p.byteSize.toInt(),
  'percentage': p.percentage,
  'earliest_offset': p.earliestOffset.toInt(),
  'latest_offset': p.latestOffset.toInt(),
};

PartitionAnalysis _partitionFromMap(Map<String, dynamic> m) =>
    PartitionAnalysis(
      partition: _toInt(m['partition']),
      messageCount: _toInt(m['message_count']),
      byteSize: _toInt(m['byte_size']),
      percentage: _toDouble(m['percentage']),
      earliestOffset: _toInt(m['earliest_offset']),
      latestOffset: _toInt(m['latest_offset']),
    );

Map<String, dynamic> _hourlyToMap(HourlyCount h) => <String, dynamic>{
  'hour': h.hour,
  'count': h.count.toInt(),
  'percentage': h.percentage,
};

HourlyCount _hourlyFromMap(Map<String, dynamic> m) => HourlyCount(
  hour: _toInt(m['hour']),
  count: _toInt(m['count']),
  percentage: _toDouble(m['percentage']),
);

Map<String, dynamic> _keyToMap(KeyOccurrence k) => <String, dynamic>{
  'key': k.key,
  'count': k.count.toInt(),
  'percentage': k.percentage,
};

KeyOccurrence _keyFromMap(Map<String, dynamic> m) => KeyOccurrence(
  key: _toStr(m['key']),
  count: _toInt(m['count']),
  percentage: _toDouble(m['percentage']),
);

Map<String, dynamic> _typeToMap(TypeOccurrence t) => <String, dynamic>{
  'type_name': t.typeName,
  'count': t.count.toInt(),
  'percentage': t.percentage,
};

TypeOccurrence _typeFromMap(Map<String, dynamic> m) => TypeOccurrence(
  typeName: _toStr(m['type_name']),
  count: _toInt(m['count']),
  percentage: _toDouble(m['percentage']),
);

Map<String, dynamic> _fieldValueToMap(FieldValueOccurrence f) =>
    <String, dynamic>{
      'value': f.value,
      'count': f.count.toInt(),
      'percentage': f.percentage,
    };

FieldValueOccurrence _fieldValueFromMap(Map<String, dynamic> m) =>
    FieldValueOccurrence(
      value: _toStr(m['value']),
      count: _toInt(m['count']),
      percentage: _toDouble(m['percentage']),
    );

Map<String, dynamic> _fieldToMap(FieldOccurrence f) => <String, dynamic>{
  'field_name': f.fieldName,
  'count': f.count.toInt(),
  'percentage': f.percentage,
  'top_values': f.topValues.map(_fieldValueToMap).toList(),
};

FieldOccurrence _fieldFromMap(Map<String, dynamic> m) => FieldOccurrence(
  fieldName: _toStr(m['field_name']),
  count: _toInt(m['count']),
  percentage: _toDouble(m['percentage']),
  topValues: _list(m['top_values']).map(_fieldValueFromMap).toList(),
);

// --- Lenient primitive coercion (any throw becomes `malformed`) ---------------

List<Map<String, dynamic>> _list(dynamic value) {
  if (value == null) return <Map<String, dynamic>>[];
  if (value is List) {
    return value.map((dynamic e) => e as Map<String, dynamic>).toList();
  }
  throw const FormatException('expected a list of objects');
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is BigInt) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  throw const FormatException('expected an integer');
}

double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is BigInt) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  throw const FormatException('expected a number');
}

String _toStr(dynamic value) => value?.toString() ?? '';

bool _toBool(dynamic value) =>
    value is bool ? value : (value == 1 || value == 'true');
