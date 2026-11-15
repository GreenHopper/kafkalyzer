import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

enum TopicFactStatus { idle, loading, value, error }

class TopicFactState<T> {
  final TopicFactStatus status;
  final T? data;
  final String? error;
  final bool notReadable;

  const TopicFactState._({
    required this.status,
    this.data,
    this.error,
    this.notReadable = false,
  });

  const TopicFactState.idle() : this._(status: TopicFactStatus.idle);
  const TopicFactState.loading() : this._(status: TopicFactStatus.loading);
  const TopicFactState.value(T data)
    : this._(status: TopicFactStatus.value, data: data);
  const TopicFactState.error(String message, {bool notReadable = false})
    : this._(
        status: TopicFactStatus.error,
        error: message,
        notReadable: notReadable,
      );
}

class TopicOffsetEstimate {
  final int? totalSpan;
  final bool complete;
  final String? unreadableReason;
  final bool notReadable;

  const TopicOffsetEstimate({
    required this.totalSpan,
    required this.complete,
    this.unreadableReason,
    this.notReadable = false,
  });
}

class TopicRetentionFacts {
  final String? retentionMs;
  final String? retentionBytes;
  final String? cleanupPolicy;

  const TopicRetentionFacts({
    this.retentionMs,
    this.retentionBytes,
    this.cleanupPolicy,
  });
}

class TopicFactsController extends ChangeNotifier {
  final ClusterProfile profile;
  final String topicName;
  final KafkaMetadataService? _metadataServiceOverride;

  TopicFactState<TopicOffsetEstimate> _offsets = const TopicFactState.idle();
  TopicFactState<TopicRetentionFacts> _configs = const TopicFactState.idle();
  TopicFactState<TopicTimeRange> _timeRange = const TopicFactState.idle();

  int _factsGeneration = 0;
  int _timeRangeGeneration = 0;
  bool _disposed = false;

  TopicFactsController({
    required this.profile,
    required this.topicName,
    KafkaMetadataService? metadataService,
  }) : _metadataServiceOverride = metadataService;

  KafkaMetadataService get _metadataService =>
      _metadataServiceOverride ?? getIt<KafkaMetadataService>();

  TopicFactState<TopicOffsetEstimate> get offsets => _offsets;
  TopicFactState<TopicRetentionFacts> get configs => _configs;
  TopicFactState<TopicTimeRange> get timeRange => _timeRange;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> loadFacts() async {
    final futures = <Future<void>>[];
    if (_offsets.status == TopicFactStatus.idle) {
      futures.add(_loadOffsets(_factsGeneration));
    }
    if (_configs.status == TopicFactStatus.idle) {
      futures.add(_loadConfigs(_factsGeneration));
    }
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  Future<void> refresh() async {
    _factsGeneration++;
    _timeRangeGeneration++;
    final gen = _factsGeneration;
    _timeRange = const TopicFactState.idle();
    await Future.wait([_loadOffsets(gen), _loadConfigs(gen)]);
  }

  Future<void> loadTimeRange() async {
    if (_timeRange.status == TopicFactStatus.loading) return;
    final gen = ++_timeRangeGeneration;
    _timeRange = const TopicFactState.loading();
    _safeNotify();

    try {
      final result = await _metadataService.fetchTopicTimeRange(
        profile: profile,
        topic: topicName,
      );
      if (_disposed || _timeRangeGeneration != gen) return;
      _timeRange = TopicFactState.value(result);
      _safeNotify();
    } catch (e) {
      if (_disposed || _timeRangeGeneration != gen) return;
      final msg = e.toString();
      _timeRange = TopicFactState.error(
        msg,
        notReadable: _looksNotReadable(msg),
      );
      _safeNotify();
    }
  }

  Future<void> _loadOffsets(int gen) async {
    _offsets = const TopicFactState.loading();
    _safeNotify();

    try {
      final dist = await _metadataService.fetchPartitionOffsets(
        profile: profile,
        topic: topicName,
      );
      if (_disposed || _factsGeneration != gen) return;

      if (dist.complete && dist.totalSpan != null) {
        _offsets = TopicFactState.value(
          TopicOffsetEstimate(totalSpan: dist.totalSpan, complete: true),
        );
      } else {
        final failedRow = dist.partitions
            .where((r) => r.state != PartitionOffsetState.known)
            .firstOrNull;
        final notReadable = dist.partitions.any(
          (r) => r.state == PartitionOffsetState.notReadable,
        );
        final reason = failedRow?.error ?? failedRow?.state.name;
        _offsets = TopicFactState.value(
          TopicOffsetEstimate(
            totalSpan: null,
            complete: false,
            unreadableReason: reason,
            notReadable: notReadable,
          ),
        );
      }
      _safeNotify();
    } catch (e) {
      if (_disposed || _factsGeneration != gen) return;
      final msg = e.toString();
      _offsets = TopicFactState.error(msg, notReadable: _looksNotReadable(msg));
      _safeNotify();
    }
  }

  Future<void> _loadConfigs(int gen) async {
    _configs = const TopicFactState.loading();
    _safeNotify();

    try {
      final results = await _metadataService.describeTopicConfigs(
        profile: profile,
        topics: [topicName],
      );
      if (_disposed || _factsGeneration != gen) return;

      final match = results.where((r) => r.topic == topicName).firstOrNull;
      if (match == null) {
        _configs = const TopicFactState.value(TopicRetentionFacts());
        _safeNotify();
        return;
      }

      switch (match.status) {
        case TopicConfigStatus.available:
          String? retentionMs;
          String? retentionBytes;
          String? cleanupPolicy;
          for (final entry in match.entries) {
            if (entry.name == 'retention.ms') {
              retentionMs = entry.value;
            } else if (entry.name == 'retention.bytes') {
              retentionBytes = entry.value;
            } else if (entry.name == 'cleanup.policy') {
              cleanupPolicy = entry.value;
            }
          }
          _configs = TopicFactState.value(
            TopicRetentionFacts(
              retentionMs: retentionMs,
              retentionBytes: retentionBytes,
              cleanupPolicy: cleanupPolicy,
            ),
          );
        case TopicConfigStatus.notReadable:
          _configs = TopicFactState.error(
            match.message ?? 'not readable',
            notReadable: true,
          );
        case TopicConfigStatus.failed:
          _configs = TopicFactState.error(
            match.message ?? 'failed to load topic config',
            notReadable: false,
          );
      }
      _safeNotify();
    } catch (e) {
      if (_disposed || _factsGeneration != gen) return;
      final msg = e.toString();
      _configs = TopicFactState.error(msg, notReadable: _looksNotReadable(msg));
      _safeNotify();
    }
  }

  static bool _looksNotReadable(String message) {
    final lower = message.toLowerCase();
    return lower.contains('not readable') || lower.contains('authorization');
  }
}
