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
  static const int currentVersion = 3;
  static const Set<int> supportedVersions = {1, 2, 3};

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
  'message_size_percentiles': _percentilesToMap(r.messageSizePercentiles),
  'size_percentiles_estimated': r.sizePercentilesEstimated,
  'estimated_distinct_keys': r.estimatedDistinctKeys.toInt(),
  'key_cardinality_capped': r.keyCardinalityCapped,
  'hourly_timeline': r.hourlyTimeline.map(_hourBucketToMap).toList(),
  'scan_reference_time_ms': r.scanReferenceTimeMs?.toInt(),
  'complete_from_ms': r.completeFromMs?.toInt(),
  'timeline_outside_count': r.timelineOutsideCount.toInt(),
  'value_filter_result': _valueFilterResultToMap(r.valueFilterResult),
  'duplicate_analysis_result': _duplicateAnalysisResultToMap(
    r.duplicateAnalysisResult,
  ),
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
  messageSizePercentiles: _percentilesFromMap(m['message_size_percentiles']),
  sizePercentilesEstimated: _toBool(m['size_percentiles_estimated'] ?? false),
  estimatedDistinctKeys: _toInt(m['estimated_distinct_keys'] ?? 0),
  keyCardinalityCapped: _toBool(m['key_cardinality_capped'] ?? false),
  hourlyTimeline: _list(m['hourly_timeline']).map(_hourBucketFromMap).toList(),
  scanReferenceTimeMs: _toOptionalInt(m['scan_reference_time_ms']),
  completeFromMs: _toOptionalInt(m['complete_from_ms']),
  timelineOutsideCount: _toInt(m['timeline_outside_count'] ?? 0),
  valueFilterResult: _valueFilterResultFromMap(m['value_filter_result']),
  duplicateAnalysisResult: _duplicateAnalysisResultFromMap(
    m['duplicate_analysis_result'],
  ),
);

Map<String, dynamic> _hourBucketToMap(HourBucket b) => <String, dynamic>{
  'epoch_hour': b.epochHour.toInt(),
  'count': b.count.toInt(),
};

HourBucket _hourBucketFromMap(Map<String, dynamic> m) =>
    HourBucket(epochHour: _toInt(m['epoch_hour']), count: _toInt(m['count']));

Map<String, dynamic>? _valueFilterResultToMap(ValueFilterResult? r) {
  if (r == null) return null;
  return <String, dynamic>{
    'field_path': r.fieldPath,
    'value': r.value,
    'messages_with_field': r.messagesWithField.toInt(),
    'matched_messages': r.matchedMessages.toInt(),
    'matched_timeline': r.matchedTimeline.map(_hourBucketToMap).toList(),
  };
}

ValueFilterResult? _valueFilterResultFromMap(dynamic raw) {
  if (raw is! Map) return null;
  return ValueFilterResult(
    fieldPath: _toStr(raw['field_path']),
    value: _toStr(raw['value']),
    messagesWithField: _toInt(raw['messages_with_field']),
    matchedMessages: _toInt(raw['matched_messages']),
    matchedTimeline: _list(
      raw['matched_timeline'],
    ).map(_hourBucketFromMap).toList(),
  );
}

Map<String, dynamic>? _duplicateAnalysisResultToMap(
  DuplicateAnalysisResult? r,
) {
  if (r == null) return null;
  return <String, dynamic>{
    'scope': r.scope.name,
    'total_messages': r.totalMessages.toInt(),
    'unique_messages': r.uniqueMessages.toInt(),
    'duplicate_messages': r.duplicateMessages.toInt(),
    'duplicate_rate': r.duplicateRate,
    'top_duplicates': r.topDuplicates.map(_topDuplicateToMap).toList(),
  };
}

Map<String, dynamic> _topDuplicateToMap(TopDuplicateOccurrence d) =>
    <String, dynamic>{
      'key': d.key,
      'payload_preview': d.payloadPreview,
      'count': d.count.toInt(),
      'percentage': d.percentage,
      'sample_partition': d.samplePartition,
      'sample_offset': d.sampleOffset.toInt(),
      'sample_timestamp_ms': d.sampleTimestampMs.toInt(),
    };

DuplicateAnalysisResult? _duplicateAnalysisResultFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final scopeStr = _toStr(raw['scope']);
  final scope = DuplicateDetectionScope.values.firstWhere(
    (s) => s.name == scopeStr,
    orElse: () => DuplicateDetectionScope.payloadOnly,
  );
  return DuplicateAnalysisResult(
    scope: scope,
    totalMessages: _toInt(raw['total_messages']),
    uniqueMessages: _toInt(raw['unique_messages']),
    duplicateMessages: _toInt(raw['duplicate_messages']),
    duplicateRate: _toDouble(raw['duplicate_rate']),
    topDuplicates: _list(
      raw['top_duplicates'],
    ).map(_topDuplicateFromMap).toList(),
  );
}

TopDuplicateOccurrence _topDuplicateFromMap(Map<String, dynamic> m) =>
    TopDuplicateOccurrence(
      key: m['key'] as String?,
      payloadPreview: _toStr(m['payload_preview']),
      count: _toInt(m['count']),
      percentage: _toDouble(m['percentage']),
      samplePartition: _toInt(m['sample_partition']),
      sampleOffset: _toInt(m['sample_offset']),
      sampleTimestampMs: _toInt(m['sample_timestamp_ms']),
    );

/// Percentiles are optional in version 1 files: a missing block stays unavailable
/// instead of turning into zeros.
Map<String, dynamic>? _percentilesToMap(SizePercentiles? p) {
  if (p == null) return null;
  return <String, dynamic>{
    'p50': p.p50.toInt(),
    'p95': p.p95.toInt(),
    'p99': p.p99.toInt(),
  };
}

SizePercentiles? _percentilesFromMap(dynamic raw) {
  if (raw is! Map) return null;
  return SizePercentiles(
    p50: _toInt(raw['p50']),
    p95: _toInt(raw['p95']),
    p99: _toInt(raw['p99']),
  );
}

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
      'truncated': f.truncated,
    };

FieldValueOccurrence _fieldValueFromMap(Map<String, dynamic> m) =>
    FieldValueOccurrence(
      value: _toStr(m['value']),
      count: _toInt(m['count']),
      percentage: _toDouble(m['percentage']),
      truncated: _toBool(m['truncated'] ?? false),
    );

Map<String, dynamic> _fieldToMap(FieldOccurrence f) => <String, dynamic>{
  'field_name': f.fieldName,
  'count': f.count.toInt(),
  'percentage': f.percentage,
  'top_values': f.topValues.map(_fieldValueToMap).toList(),
  'values_capped': f.valuesCapped,
};

FieldOccurrence _fieldFromMap(Map<String, dynamic> m) => FieldOccurrence(
  fieldName: _toStr(m['field_name']),
  count: _toInt(m['count']),
  percentage: _toDouble(m['percentage']),
  topValues: _list(m['top_values']).map(_fieldValueFromMap).toList(),
  valuesCapped: _toBool(m['values_capped'] ?? false),
);

// --- Lenient primitive coercion (any throw becomes `malformed`) ---------------

int? _toOptionalInt(dynamic value) {
  if (value == null) return null;
  return _toInt(value);
}

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
