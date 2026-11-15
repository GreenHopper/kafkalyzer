import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';

class TopicConfigSideState {
  final bool isLoading;
  final TopicConfigSnapshot? snapshot;

  const TopicConfigSideState._({required this.isLoading, this.snapshot});

  const TopicConfigSideState.idle() : this._(isLoading: false);

  const TopicConfigSideState.loading({TopicConfigSnapshot? previous})
    : this._(isLoading: true, snapshot: previous);

  const TopicConfigSideState.loaded(TopicConfigSnapshot snapshot)
    : this._(isLoading: false, snapshot: snapshot);

  bool get isLoaded => !isLoading && snapshot != null;
}

class TopicConfigCompareTarget {
  final ClusterProfile profile;
  final String topic;
  final TopicConfigSideState right;

  const TopicConfigCompareTarget({
    required this.profile,
    required this.topic,
    required this.right,
  });

  TopicConfigCompareTarget copyWith({
    ClusterProfile? profile,
    String? topic,
    TopicConfigSideState? right,
  }) => TopicConfigCompareTarget(
    profile: profile ?? this.profile,
    topic: topic ?? this.topic,
    right: right ?? this.right,
  );
}

/// Per-tab controller for inspecting a topic's full configuration and comparing
/// it against a second topic in the same or another saved cluster profile.
class TopicConfigController extends ChangeNotifier {
  final ClusterProfile leftProfile;
  final String leftTopic;
  final TopicConfigService? _serviceOverride;

  TopicConfigSideState _left = const TopicConfigSideState.idle();
  TopicConfigCompareTarget? _compare;
  TopicConfigDiff? _diff;
  bool _nonDefaultOnly = false;
  bool _hasStarted = false;
  bool _disposed = false;
  int _leftToken = 0;
  int _rightToken = 0;

  TopicConfigController({
    required this.leftProfile,
    required this.leftTopic,
    TopicConfigService? service,
  }) : _serviceOverride = service;

  TopicConfigService get _service =>
      _serviceOverride ?? getIt<TopicConfigService>();

  TopicConfigSideState get left => _left;
  TopicConfigCompareTarget? get compare => _compare;
  TopicConfigDiff? get diff => _diff;
  bool get nonDefaultOnly => _nonDefaultOnly;
  bool get isComparing => _compare != null;

  List<TopicConfigEntry> get visibleSingleEntries {
    final entries = _left.snapshot?.entries ?? const <TopicConfigEntry>[];
    if (!_nonDefaultOnly) return entries;
    return entries.where((e) => !e.isDefault).toList(growable: false);
  }

  List<TopicConfigDiffRow> get visibleDiffRows {
    final rows = _diff?.rows ?? const <TopicConfigDiffRow>[];
    if (!_nonDefaultOnly) return rows;
    return rows
        .where(
          (row) =>
              row.nonDefault ||
              row.status == TopicConfigDiffStatus.different ||
              row.status == TopicConfigDiffStatus.onlyLeft ||
              row.status == TopicConfigDiffStatus.onlyRight,
        )
        .toList(growable: false);
  }

  void ensureLoaded() {
    if (_hasStarted) return;
    _hasStarted = true;
    _loadLeft();
  }

  Future<void> refresh() async {
    _hasStarted = true;
    _diff = null;
    final leftFuture = _loadLeft();
    final rightFuture = _compare != null ? _loadRight() : Future<void>.value();
    await Future.wait([leftFuture, rightFuture]);
  }

  Future<void> retryLeft() => _loadLeft();

  Future<void> retryRight() {
    if (_compare == null) return Future<void>.value();
    return _loadRight();
  }

  Future<void> startComparison(ClusterProfile profile, String topic) async {
    _hasStarted = true;
    _diff = null;
    _compare = TopicConfigCompareTarget(
      profile: profile,
      topic: topic,
      right: const TopicConfigSideState.loading(),
    );
    notifyListeners();

    final futures = <Future<void>>[_loadRight()];
    if (!_left.isLoaded && !_left.isLoading) {
      futures.add(_loadLeft());
    }
    await Future.wait(futures);
  }

  void closeComparison() {
    if (_compare == null && _diff == null) return;
    _rightToken++;
    _compare = null;
    _diff = null;
    _safeNotify();
  }

  void setNonDefaultOnly(bool value) {
    if (_nonDefaultOnly == value) return;
    _nonDefaultOnly = value;
    _safeNotify();
  }

  void toggleNonDefaultOnly() => setNonDefaultOnly(!_nonDefaultOnly);

  Future<void> _loadLeft() async {
    final token = ++_leftToken;
    _left = const TopicConfigSideState.loading();
    _diff = null;
    _safeNotify();

    final snapshot = await _fetchSafe(leftProfile, leftTopic);
    if (_disposed || token != _leftToken) return;

    _left = TopicConfigSideState.loaded(snapshot);
    _recomputeDiffIfReady();
    _safeNotify();
  }

  Future<void> _loadRight() async {
    final target = _compare;
    if (target == null) return;
    final token = ++_rightToken;
    _compare = target.copyWith(right: const TopicConfigSideState.loading());
    _diff = null;
    _safeNotify();

    final snapshot = await _fetchSafe(target.profile, target.topic);
    if (_disposed || token != _rightToken || _compare == null) return;

    _compare = _compare!.copyWith(right: TopicConfigSideState.loaded(snapshot));
    _recomputeDiffIfReady();
    _safeNotify();
  }

  Future<TopicConfigSnapshot> _fetchSafe(
    ClusterProfile profile,
    String topic,
  ) async {
    try {
      return await _service.fetchTopicConfig(profile: profile, topic: topic);
    } catch (e) {
      return TopicConfigSnapshot(
        topic: topic,
        availability: TopicConfigAvailability.failed,
        errorMessage: e.toString(),
        entries: const [],
      );
    }
  }

  void _recomputeDiffIfReady() {
    final rightSnap = _compare?.right.snapshot;
    final leftSnap = _left.snapshot;
    if (_left.isLoaded &&
        _compare != null &&
        _compare!.right.isLoaded &&
        leftSnap != null &&
        rightSnap != null) {
      _diff = _service.diffTopicConfigs(left: leftSnap, right: rightSnap);
    } else {
      _diff = null;
    }
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
