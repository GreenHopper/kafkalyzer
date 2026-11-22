import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';
import 'package:logger/logger.dart';

enum TopicConfigViewState { loading, available, notReadable, failed }

class TopicConfigView {
  final TopicConfigViewState state;
  final String? message;
  final String? retentionMs;
  final String? cleanupPolicy;

  const TopicConfigView({
    required this.state,
    this.message,
    this.retentionMs,
    this.cleanupPolicy,
  });

  const TopicConfigView.loading() : this(state: TopicConfigViewState.loading);
}

/// Answers [TopicNameSource] from this module's own topic cache, so other
/// modules can ask which topics exist without importing [TopicController].
class CachedTopicNames implements TopicNameSource {
  const CachedTopicNames(this._controller);

  final TopicController _controller;

  @override
  List<String>? topicNames(ClusterProfile profile) =>
      _controller.getTopics(profile)?.map((t) => t.name).toList();
}

class TopicController extends ChangeNotifier {
  static const int configChunkSize = 100;

  final KafkaMetadataService _metadataService = getIt<KafkaMetadataService>();
  final Logger _logger = getIt.isRegistered<Logger>()
      ? getIt<Logger>()
      : Logger();

  final Map<String, List<api.TopicMetadata>> _cache = {};
  final Map<String, Map<String, api.TopicMetadata>> _index = {};
  final Map<String, DateTime> _fetchedAt = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, String> _errors = {};
  final Map<String, int> _generation = {};

  final Map<String, Map<String, api.TopicConfigResult>> _configs = {};
  final Map<String, LinkedHashSet<String>> _pendingConfigs = {};
  final Map<String, Set<String>> _inFlightConfigs = {};
  final Map<String, Map<String, api.TopicMetadata>> _resolved = {};

  List<api.TopicMetadata>? getTopics(ClusterProfile cluster) =>
      _cache[cluster.name];

  bool hasCachedTopics(ClusterProfile cluster) =>
      _cache.containsKey(cluster.name);

  DateTime? fetchedAt(ClusterProfile cluster) => _fetchedAt[cluster.name];

  bool isLoading(ClusterProfile cluster) => _isLoading[cluster.name] ?? false;

  String? errorFor(ClusterProfile cluster) => _errors[cluster.name];

  api.TopicMetadata? findTopic(ClusterProfile cluster, String name) =>
      _index[cluster.name]?[name];

  Future<api.TopicMetadata> resolveTopic(
    ClusterProfile cluster,
    String name,
  ) async {
    final listed = findTopic(cluster, name);
    if (listed != null) return listed;

    final cachedResolved = _resolved[cluster.name]?[name];
    if (cachedResolved != null) return cachedResolved;

    final meta = await _metadataService.fetchTopicMetadata(
      profile: cluster,
      topic: name,
    );
    (_resolved[cluster.name] ??= {})[name] = meta;
    notifyListeners();
    return meta;
  }

  TopicConfigView configFor(ClusterProfile cluster, String topic) {
    final res = _configs[cluster.name]?[topic];
    if (res == null) {
      return const TopicConfigView.loading();
    }
    switch (res.status) {
      case api.TopicConfigStatus.available:
        String? retentionMs;
        String? cleanupPolicy;
        for (final entry in res.entries) {
          if (entry.name == 'retention.ms') {
            retentionMs = entry.value;
          } else if (entry.name == 'cleanup.policy') {
            cleanupPolicy = entry.value;
          }
        }
        return TopicConfigView(
          state: TopicConfigViewState.available,
          retentionMs: retentionMs,
          cleanupPolicy: cleanupPolicy,
        );
      case api.TopicConfigStatus.notReadable:
        return TopicConfigView(
          state: TopicConfigViewState.notReadable,
          message: res.message,
        );
      case api.TopicConfigStatus.failed:
        return TopicConfigView(
          state: TopicConfigViewState.failed,
          message: res.message,
        );
    }
  }

  void ensureConfig(ClusterProfile cluster, String topic) {
    final name = cluster.name;
    if (_configs[name]?.containsKey(topic) ?? false) return;
    if (_inFlightConfigs[name]?.contains(topic) ?? false) return;

    final pending = _pendingConfigs[name] ??= LinkedHashSet<String>();
    if (pending.contains(topic)) {
      // Move to front so opened topic loads before remaining chunks.
      final rest = pending.where((t) => t != topic).toList();
      pending
        ..clear()
        ..add(topic)
        ..addAll(rest);
    } else {
      final rest = pending.toList();
      pending
        ..clear()
        ..add(topic)
        ..addAll(rest);
    }

    _maybeStartConfigLoader(cluster);
  }

  void retryConfig(ClusterProfile cluster, String topic) {
    final name = cluster.name;
    _configs[name]?.remove(topic);
    if (_inFlightConfigs[name]?.contains(topic) ?? false) return;

    final pending = _pendingConfigs[name] ??= LinkedHashSet<String>();
    final rest = pending.where((t) => t != topic).toList();
    pending
      ..clear()
      ..add(topic)
      ..addAll(rest);

    notifyListeners();
    _maybeStartConfigLoader(cluster);
  }

  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    final name = cluster.name;
    if (!force && _cache.containsKey(name)) return;

    _errors.remove(name);
    _isLoading[name] = true;
    notifyListeners();

    try {
      final topics = await _metadataService.fetchTopics(profile: cluster);
      final gen = (_generation[name] ?? 0) + 1;
      _generation[name] = gen;

      _cache[name] = topics;
      _index[name] = {for (final t in topics) t.name: t};
      _fetchedAt[name] = DateTime.now();
      _configs[name] = {};
      _resolved.remove(name);
      _inFlightConfigs[name] = {};

      final pending = _pendingConfigs[name] ??= LinkedHashSet<String>();
      pending
        ..clear()
        ..addAll(topics.map((t) => t.name));

      _isLoading[name] = false;
      notifyListeners();

      if (pending.isNotEmpty) {
        _runConfigLoader(cluster, gen);
      }
    } catch (e, st) {
      _logger.e('Error fetching topics for $name', error: e, stackTrace: st);
      _errors[name] = e.toString();
      _isLoading[name] = false;
      notifyListeners();
    }
  }

  void _maybeStartConfigLoader(ClusterProfile cluster) {
    final name = cluster.name;
    final inFlight = _inFlightConfigs[name];
    if (inFlight != null && inFlight.isNotEmpty) return;
    final pending = _pendingConfigs[name];
    if (pending == null || pending.isEmpty) return;
    final gen = _generation[name] ?? 0;
    _runConfigLoader(cluster, gen);
  }

  Future<void> _runConfigLoader(ClusterProfile cluster, int gen) async {
    final name = cluster.name;
    while (true) {
      if ((_generation[name] ?? 0) != gen) return;
      final pending = _pendingConfigs[name];
      if (pending == null || pending.isEmpty) return;

      final inFlight = _inFlightConfigs[name] ??= {};
      if (inFlight.isNotEmpty) return;

      final chunk = pending.take(configChunkSize).toList();
      for (final t in chunk) {
        pending.remove(t);
        inFlight.add(t);
      }

      List<api.TopicConfigResult> results;
      try {
        results = await _metadataService.describeTopicConfigs(
          profile: cluster,
          topics: chunk,
        );
      } catch (e) {
        results = [
          for (final t in chunk)
            api.TopicConfigResult(
              topic: t,
              status: api.TopicConfigStatus.failed,
              message: e.toString(),
              entries: const [],
            ),
        ];
      }

      if ((_generation[name] ?? 0) != gen || !_cache.containsKey(name)) {
        return;
      }

      final configsMap = _configs[name] ??= {};
      final returnedByTopic = <String, api.TopicConfigResult>{
        for (final r in results) r.topic: r,
      };
      for (final t in chunk) {
        inFlight.remove(t);
        configsMap[t] =
            returnedByTopic[t] ??
            api.TopicConfigResult(
              topic: t,
              status: api.TopicConfigStatus.failed,
              message: null,
              entries: const [],
            );
      }

      notifyListeners();
    }
  }

  void clearCache(ClusterProfile cluster) {
    final name = cluster.name;
    _generation[name] = (_generation[name] ?? 0) + 1;
    _cache.remove(name);
    _index.remove(name);
    _fetchedAt.remove(name);
    _configs.remove(name);
    _pendingConfigs.remove(name);
    _inFlightConfigs.remove(name);
    _resolved.remove(name);
    _errors.remove(name);
    _isLoading.remove(name);
    notifyListeners();
  }
}
