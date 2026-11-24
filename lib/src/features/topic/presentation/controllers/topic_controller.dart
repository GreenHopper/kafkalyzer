import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_view_controllers.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_list_preferences_service.dart';
import 'package:kafkalyzer/src/services/topic_name_source.dart';
import 'package:kafkalyzer/src/services/topic_store.dart';
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

class TopicController extends ChangeNotifier implements TopicStore {
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

  /// The per-topic stream, analysis and facts controllers, owned here because
  /// they hang off the cached topic list.
  final TopicViewControllerRegistry viewControllers =
      TopicViewControllerRegistry();

  List<api.TopicMetadata>? getTopics(ClusterProfile cluster) =>
      _cache[cluster.name];

  @override
  bool hasCachedTopics(ClusterProfile cluster) =>
      _cache.containsKey(cluster.name);

  DateTime? fetchedAt(ClusterProfile cluster) => _fetchedAt[cluster.name];

  bool isLoading(ClusterProfile cluster) => _isLoading[cluster.name] ?? false;

  String? errorFor(ClusterProfile cluster) => _errors[cluster.name];

  api.TopicMetadata? findTopic(ClusterProfile cluster, String name) =>
      _index[cluster.name]?[name];

  @override
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

  @override
  List<api.TopicMetadata>? cachedTopics(ClusterProfile profile) =>
      getTopics(profile);

  @override
  Future<void> refreshTopics(ClusterProfile profile) => fetchTopics(profile);

  @override
  void clearTopics(ClusterProfile profile) => clearCache(profile);

  @override
  bool hasRunningTopicOperations(Iterable<String> tabIds) =>
      viewControllers.hasRunningOperations(tabIds);

  @override
  void releaseTopicViews(Iterable<String> tabIds) =>
      viewControllers.release(tabIds);

  @override
  Listenable get topicListenable => this;

  @override
  void releaseTopicViewByName(String topicName, String clusterName) =>
      viewControllers.releaseByName(topicName, clusterName);

  @override
  void startTopicStream(
    String tabId,
    ClusterProfile profile,
    String topicName,
  ) => viewControllers.streamWithDefaults(tabId, profile, topicName);

  /// Forgets the topic list filters, sort order and notice state, e.g. after a
  /// disconnect.
  @override
  void resetTopicListView() {
    _query = const TopicListQuery();
    _unhealthyTopicsOnly = false;
    _preferenceCluster = null;
    _topicPreferencesUnreadable = false;
    _topicPreferencesWriteBlocked = false;
    _memoList = null;
    _memoQuery = null;
    _memoUnhealthyOnly = null;
    _memoView = null;
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
    // The per-topic view state hangs off the cached list, so it goes with it.
    viewControllers.releaseAll();
    notifyListeners();
  }

  // --- topic list view state -------------------------------------------------
  //
  // Query, filter, sort, favourite and unhealthy-only state, plus the memoised
  // view: this is per-topic-list state, so it sits next to the topic cache it
  // reads instead of in the connection controller.

  TopicListQuery _query = const TopicListQuery();
  List<api.TopicMetadata>? _memoList;
  TopicListQuery? _memoQuery;
  bool? _memoUnhealthyOnly;
  TopicListView? _memoView;
  bool _unhealthyTopicsOnly = false;
  String? _preferenceCluster;
  bool _topicPreferencesUnreadable = false;
  bool _topicPreferencesWriteBlocked = false;

  @visibleForTesting
  int viewComputations = 0;

  static const _emptyView = TopicListView(
    rows: [],
    visibleTopics: [],
    hiddenByInternal: 0,
    hiddenByStream: 0,
    hiddenByText: 0,
    patternError: null,
    highlightPattern: null,
    failureGroups: {},
  );

  TopicListQuery get topicListQuery => _query;
  bool get showInternalTopics => _query.showInternal;
  bool get showStreamTopics => _query.showStream;
  String get topicFilter => _query.text;
  TopicFilterMode get topicFilterMode => _query.mode;
  TopicSortOrder get topicSortOrder => _query.sort;
  bool get groupTopicsByPrefix => _query.groupByPrefix;
  Set<String> get favouriteTopics => _query.favourites;
  bool get topicPreferencesUnreadable => _topicPreferencesUnreadable;
  bool get topicPreferencesWriteBlocked => _topicPreferencesWriteBlocked;
  bool get unhealthyTopicsOnly => _unhealthyTopicsOnly;

  TopicListView topicListView(ClusterProfile? profile) {
    if (profile == null) return _emptyView;

    final allTopics = getTopics(profile) ?? const [];
    if (identical(_memoList, allTopics) &&
        _memoQuery == _query &&
        _memoUnhealthyOnly == _unhealthyTopicsOnly &&
        _memoView != null) {
      return _memoView!;
    }

    final TopicListView view;
    if (_unhealthyTopicsOnly) {
      final unhealthy = allTopics
          .where(
            (t) =>
                ((t.underReplicatedPartitions ?? 0) +
                    (t.leaderlessPartitions ?? 0)) >
                0,
          )
          .toList(growable: false);
      view = buildTopicListView(
        unhealthy,
        _query.copyWith(
          text: '',
          showInternal: true,
          showStream: true,
          groupByPrefix: false,
        ),
      );
    } else {
      view = buildTopicListView(allTopics, _query);
    }
    viewComputations++;
    _memoList = allTopics;
    _memoQuery = _query;
    _memoUnhealthyOnly = _unhealthyTopicsOnly;
    _memoView = view;
    return view;
  }

  List<api.TopicMetadata> topics(ClusterProfile? profile) =>
      topicListView(profile).visibleTopics;

  void toggleShowInternalTopics(bool value) {
    if (_query.showInternal == value) return;
    _query = _query.copyWith(showInternal: value);
    notifyListeners();
    _saveTopicPreferences();
  }

  void toggleShowStreamTopics(bool value) {
    if (_query.showStream == value) return;
    _query = _query.copyWith(showStream: value);
    notifyListeners();
    _saveTopicPreferences();
  }

  void setTopicFilterMode(TopicFilterMode mode) {
    if (_query.mode == mode) return;
    _query = _query.copyWith(mode: mode);
    notifyListeners();
    _saveTopicPreferences();
  }

  void setTopicSortOrder(TopicSortOrder sort) {
    if (_query.sort == sort) return;
    _query = _query.copyWith(sort: sort);
    notifyListeners();
    _saveTopicPreferences();
  }

  void setGroupByPrefix(bool value) {
    if (_query.groupByPrefix == value) return;
    _query = _query.copyWith(groupByPrefix: value);
    notifyListeners();
    _saveTopicPreferences();
  }

  void toggleGroupByPrefix() => setGroupByPrefix(!_query.groupByPrefix);

  void toggleFavourite(String topicName) {
    final next = Set<String>.from(_query.favourites);
    if (!next.add(topicName)) {
      next.remove(topicName);
    }
    _query = _query.copyWith(favourites: next);
    notifyListeners();
    _saveTopicPreferences();
  }

  void toggleGroupCollapsed(String prefix) {
    final next = Set<String>.from(_query.collapsedGroups);
    if (!next.add(prefix)) {
      next.remove(prefix);
    }
    _query = _query.copyWith(collapsedGroups: next);
    notifyListeners();
  }

  void showAllTopics() {
    _query = _query.copyWith(text: '', showInternal: true, showStream: true);
    notifyListeners();
    _saveTopicPreferences();
  }

  void showUnhealthyTopicsOnly() {
    _unhealthyTopicsOnly = true;
    _query = _query.copyWith(text: '');
    notifyListeners();
  }

  void clearUnhealthyTopicsOnly() {
    if (!_unhealthyTopicsOnly) return;
    _unhealthyTopicsOnly = false;
    notifyListeners();
  }

  void updateTopicFilter(String filter) {
    if (_query.text == filter) return;
    _query = _query.copyWith(text: filter);
    notifyListeners();
  }

  void dismissTopicPreferencesNotice() {
    if (!_topicPreferencesUnreadable && !_topicPreferencesWriteBlocked) return;
    _topicPreferencesUnreadable = false;
    _topicPreferencesWriteBlocked = false;
    notifyListeners();
  }

  /// Loads the saved topic list preferences for the cluster being connected to.
  @override
  Future<void> loadTopicPreferences(ClusterProfile profile) async {
    _unhealthyTopicsOnly = false;
    _preferenceCluster = profile.name;
    if (!getIt.isRegistered<TopicListPreferencesService>()) {
      _query = const TopicListQuery();
      _topicPreferencesUnreadable = false;
      _topicPreferencesWriteBlocked = false;
      return;
    }
    final service = getIt<TopicListPreferencesService>();
    final result = await service.load(profile.name);
    _query = result.preferences.toQuery();
    _topicPreferencesUnreadable = result.unreadable;
    _topicPreferencesWriteBlocked = false;
    _memoList = null;
    _memoQuery = null;
    _memoView = null;
  }

  Future<void> _saveTopicPreferences() async {
    final cluster = _preferenceCluster;
    if (cluster == null) return;
    if (!getIt.isRegistered<TopicListPreferencesService>()) return;
    final service = getIt<TopicListPreferencesService>();
    final saved = await service.save(
      cluster,
      TopicListPreferences.fromQuery(_query),
    );
    if (!saved && service.isWriteBlocked(cluster)) {
      _topicPreferencesWriteBlocked = true;
      notifyListeners();
    }
  }
}
