import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// Predefined scan modes that replace the manual combination of
/// start and end strategy matrices.
enum TopicScanMode {
  /// Bounded fetch of the latest N messages up to high watermark.
  latestN,

  /// Continuous live streaming of newly produced messages.
  liveTail,

  /// Bounded time-window consumption using start and end timestamps.
  timeRange,

  /// Consumption starting from earliest topic offset or explicit partition offsets.
  offsetEarliest;

  /// Human-readable label using application localizations.
  String label(AppLocalizations l10n) {
    switch (this) {
      case TopicScanMode.latestN:
        return l10n.scanModeLatestN;
      case TopicScanMode.liveTail:
        return l10n.scanModeLiveTail;
      case TopicScanMode.timeRange:
        return l10n.scanModeTimeRange;
      case TopicScanMode.offsetEarliest:
        return l10n.scanModeOffsetEarliest;
    }
  }

  /// Icon representing this scan mode.
  IconData get icon {
    switch (this) {
      case TopicScanMode.latestN:
        return Icons.bolt;
      case TopicScanMode.liveTail:
        return Icons.sensors;
      case TopicScanMode.timeRange:
        return Icons.schedule;
      case TopicScanMode.offsetEarliest:
        return Icons.pin_end;
    }
  }

  /// Default starting strategy mapped to this scan mode.
  MultiSearchStartStrategy get defaultStartStrategy {
    switch (this) {
      case TopicScanMode.latestN:
      case TopicScanMode.liveTail:
        return MultiSearchStartStrategy.latest;
      case TopicScanMode.timeRange:
        return MultiSearchStartStrategy.customTimestamp;
      case TopicScanMode.offsetEarliest:
        return MultiSearchStartStrategy.earliest;
    }
  }

  /// Default ending strategy mapped to this scan mode.
  MultiSearchEndStrategy get defaultEndStrategy {
    switch (this) {
      case TopicScanMode.latestN:
        return MultiSearchEndStrategy.latest;
      case TopicScanMode.liveTail:
        return MultiSearchEndStrategy.live;
      case TopicScanMode.timeRange:
        return MultiSearchEndStrategy.customTimestamp;
      case TopicScanMode.offsetEarliest:
        return MultiSearchEndStrategy.latest;
    }
  }

  /// Whether this mode streams indefinitely until manually stopped.
  bool get isLiveStream => this == TopicScanMode.liveTail;

  /// Infer the matching [TopicScanMode] from raw start and end strategies.
  static TopicScanMode fromStrategies({
    required MultiSearchStartStrategy startStrategy,
    required MultiSearchEndStrategy endStrategy,
  }) {
    if (endStrategy == MultiSearchEndStrategy.live) {
      return TopicScanMode.liveTail;
    }
    if (startStrategy == MultiSearchStartStrategy.customTimestamp ||
        endStrategy == MultiSearchEndStrategy.customTimestamp) {
      return TopicScanMode.timeRange;
    }
    if (startStrategy == MultiSearchStartStrategy.customOffset ||
        startStrategy == MultiSearchStartStrategy.earliest ||
        endStrategy == MultiSearchEndStrategy.customOffset) {
      return TopicScanMode.offsetEarliest;
    }
    return TopicScanMode.latestN;
  }
}

/// Immutable snapshot of topic search configuration parameters
/// used for tracking dirty state.
@immutable
class TopicSearchParams {
  final TopicScanMode scanMode;
  final String quickFilter;
  final String field;
  final FilterType filterType;
  final SearchScope searchScope;
  final bool limitResults;
  final int? maxResults;
  final String partition;
  final bool fastTraceEnabled;
  final MultiSearchStartStrategy startStrategy;
  final MultiSearchEndStrategy endStrategy;
  final String startOffset;
  final String endOffset;
  final String startTimestamp;
  final String endTimestamp;

  const TopicSearchParams({
    required this.scanMode,
    required this.quickFilter,
    required this.field,
    required this.filterType,
    required this.searchScope,
    required this.limitResults,
    required this.maxResults,
    required this.partition,
    required this.fastTraceEnabled,
    required this.startStrategy,
    required this.endStrategy,
    required this.startOffset,
    required this.endOffset,
    required this.startTimestamp,
    required this.endTimestamp,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicSearchParams &&
          runtimeType == other.runtimeType &&
          scanMode == other.scanMode &&
          quickFilter.trim() == other.quickFilter.trim() &&
          field.trim() == other.field.trim() &&
          filterType == other.filterType &&
          searchScope == other.searchScope &&
          limitResults == other.limitResults &&
          maxResults == other.maxResults &&
          partition.trim() == other.partition.trim() &&
          fastTraceEnabled == other.fastTraceEnabled &&
          startStrategy == other.startStrategy &&
          endStrategy == other.endStrategy &&
          startOffset.trim() == other.startOffset.trim() &&
          endOffset.trim() == other.endOffset.trim() &&
          startTimestamp.trim() == other.startTimestamp.trim() &&
          endTimestamp.trim() == other.endTimestamp.trim();

  @override
  int get hashCode => Object.hashAll([
    scanMode,
    quickFilter.trim(),
    field.trim(),
    filterType,
    searchScope,
    limitResults,
    maxResults,
    partition.trim(),
    fastTraceEnabled,
    startStrategy,
    endStrategy,
    startOffset.trim(),
    endOffset.trim(),
    startTimestamp.trim(),
    endTimestamp.trim(),
  ]);
}
