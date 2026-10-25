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
    TopicScanMode parseScanMode(String? name) {
      return TopicScanMode.values.firstWhere(
        (m) => m.name == name,
        orElse: () => TopicScanMode.latestN,
      );
    }

    FilterType parseFilterType(String? name) {
      return FilterType.values.firstWhere(
        (f) => f.name == name,
        orElse: () => FilterType.contains,
      );
    }

    SearchScope parseSearchScope(String? name) {
      return SearchScope.values.firstWhere(
        (s) => s.name == name,
        orElse: () => SearchScope.both,
      );
    }

    MultiSearchStartStrategy parseStartStrategy(String? name) {
      return MultiSearchStartStrategy.values.firstWhere(
        (s) => s.name == name,
        orElse: () => MultiSearchStartStrategy.latest,
      );
    }

    MultiSearchEndStrategy parseEndStrategy(String? name) {
      return MultiSearchEndStrategy.values.firstWhere(
        (e) => e.name == name,
        orElse: () => MultiSearchEndStrategy.latest,
      );
    }

    return TopicSearchPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled',
      clusterName: json['clusterName'] as String? ?? '',
      topicName: json['topicName'] as String? ?? '',
      scanMode: parseScanMode(json['scanMode'] as String?),
      filterType: parseFilterType(json['filterType'] as String?),
      searchScope: parseSearchScope(json['searchScope'] as String?),
      filterTerm: json['filterTerm'] as String? ?? '',
      fastTraceEnabled: json['fastTraceEnabled'] as bool? ?? false,
      limitResults: json['limitResults'] as bool? ?? true,
      maxResults: json['maxResults']?.toString() ?? '200',
      partition: json['partition']?.toString() ?? '',
      startStrategy: parseStartStrategy(json['startStrategy'] as String?),
      startOffset: json['startOffset']?.toString() ?? '',
      startTimestamp: json['startTimestamp']?.toString() ?? '',
      endStrategy: parseEndStrategy(json['endStrategy'] as String?),
      endOffset: json['endOffset']?.toString() ?? '',
      endTimestamp: json['endTimestamp']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
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
