import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/features/search/models/topic_scan_mode.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// Represents a persistent named search preset for a Kafka topic.
@immutable
class TopicSearchPreset {
  final String id;
  final String name;
  final String clusterName;
  final String topicName;
  final TopicScanMode scanMode;
  final FilterType filterType;
  final SearchScope searchScope;
  final String filterTerm;
  final String filterExpression;
  final bool fastTraceEnabled;
  final bool limitResults;
  final String maxResults;
  final String partition;
  final MultiSearchStartStrategy startStrategy;
  final String startOffset;
  final String startTimestamp;
  final MultiSearchEndStrategy endStrategy;
  final String endOffset;
  final String endTimestamp;
  final DateTime createdAt;

  const TopicSearchPreset({
    required this.id,
    required this.name,
    required this.clusterName,
    required this.topicName,
    this.scanMode = TopicScanMode.latestN,
    this.filterType = FilterType.contains,
    this.searchScope = SearchScope.both,
    this.filterTerm = '',
    this.filterExpression = '',
    this.fastTraceEnabled = false,
    this.limitResults = true,
    this.maxResults = '200',
    this.partition = '',
    this.startStrategy = MultiSearchStartStrategy.latest,
    this.startOffset = '',
    this.startTimestamp = '',
    this.endStrategy = MultiSearchEndStrategy.latest,
    this.endOffset = '',
    this.endTimestamp = '',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'clusterName': clusterName,
    'topicName': topicName,
    'scanMode': scanMode.name,
    'filterType': filterType.name,
    'searchScope': searchScope.name,
    'filterTerm': filterTerm,
    'filterExpression': filterExpression,
    'fastTraceEnabled': fastTraceEnabled,
    'limitResults': limitResults,
    'maxResults': maxResults,
    'partition': partition,
    'startStrategy': startStrategy.name,
    'startOffset': startOffset,
    'startTimestamp': startTimestamp,
    'endStrategy': endStrategy.name,
    'endOffset': endOffset,
    'endTimestamp': endTimestamp,
    'createdAt': createdAt.toIso8601String(),
  };

  factory TopicSearchPreset.fromJson(Map<String, dynamic> json) {
    return TopicSearchPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      clusterName: json['clusterName'] as String? ?? '',
      topicName: json['topicName'] as String? ?? '',
      scanMode: _parseStoredEnum(
        TopicScanMode.values,
        json['scanMode'] as String?,
        TopicScanMode.latestN,
        'scanMode',
      ),
      filterType: _parseStoredEnum(
        FilterType.values,
        json['filterType'] as String?,
        FilterType.contains,
        'filterType',
      ),
      searchScope: _parseStoredEnum(
        SearchScope.values,
        json['searchScope'] as String?,
        SearchScope.both,
        'searchScope',
      ),
      filterTerm: json['filterTerm'] as String? ?? '',
      filterExpression: json['filterExpression'] as String? ?? '',
      fastTraceEnabled: json['fastTraceEnabled'] as bool? ?? false,
      limitResults: json['limitResults'] as bool? ?? true,
      maxResults: json['maxResults']?.toString() ?? '200',
      partition: json['partition']?.toString() ?? '',
      startStrategy: _parseStoredEnum(
        MultiSearchStartStrategy.values,
        json['startStrategy'] as String?,
        MultiSearchStartStrategy.latest,
        'startStrategy',
      ),
      startOffset: json['startOffset']?.toString() ?? '',
      startTimestamp: json['startTimestamp']?.toString() ?? '',
      endStrategy: _parseStoredEnum(
        MultiSearchEndStrategy.values,
        json['endStrategy'] as String?,
        MultiSearchEndStrategy.latest,
        'endStrategy',
      ),
      endOffset: json['endOffset']?.toString() ?? '',
      endTimestamp: json['endTimestamp']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  /// A stored enum criterion: a missing value keeps its documented default, but
  /// a value this version cannot name is an error, so the loader reports it
  /// instead of quietly running the search with something else.
  static T _parseStoredEnum<T extends Enum>(
    List<T> values,
    String? stored,
    T fallback,
    String field,
  ) {
    if (stored == null) return fallback;
    for (final value in values) {
      if (value.name == stored) return value;
    }
    throw FormatException('Unknown $field "$stored"');
  }

  TopicSearchPreset copyWith({
    String? id,
    String? name,
    String? clusterName,
    String? topicName,
    TopicScanMode? scanMode,
    FilterType? filterType,
    SearchScope? searchScope,
    String? filterTerm,
    String? filterExpression,
    bool? fastTraceEnabled,
    bool? limitResults,
    String? maxResults,
    String? partition,
    MultiSearchStartStrategy? startStrategy,
    String? startOffset,
    String? startTimestamp,
    MultiSearchEndStrategy? endStrategy,
    String? endOffset,
    String? endTimestamp,
    DateTime? createdAt,
  }) {
    return TopicSearchPreset(
      id: id ?? this.id,
      name: name ?? this.name,
      clusterName: clusterName ?? this.clusterName,
      topicName: topicName ?? this.topicName,
      scanMode: scanMode ?? this.scanMode,
      filterType: filterType ?? this.filterType,
      searchScope: searchScope ?? this.searchScope,
      filterTerm: filterTerm ?? this.filterTerm,
      filterExpression: filterExpression ?? this.filterExpression,
      fastTraceEnabled: fastTraceEnabled ?? this.fastTraceEnabled,
      limitResults: limitResults ?? this.limitResults,
      maxResults: maxResults ?? this.maxResults,
      partition: partition ?? this.partition,
      startStrategy: startStrategy ?? this.startStrategy,
      startOffset: startOffset ?? this.startOffset,
      startTimestamp: startTimestamp ?? this.startTimestamp,
      endStrategy: endStrategy ?? this.endStrategy,
      endOffset: endOffset ?? this.endOffset,
      endTimestamp: endTimestamp ?? this.endTimestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicSearchPreset &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          clusterName == other.clusterName &&
          topicName == other.topicName;

  @override
  int get hashCode => Object.hash(id, name, clusterName, topicName);
}
