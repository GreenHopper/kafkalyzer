import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

enum ClusterOverviewStatus { idle, loading, loaded, error }

class ClusterOverviewState {
  final ClusterOverviewStatus status;
  final ClusterOverview? overview;
  final String? error;
  final bool notReadable;

  const ClusterOverviewState._({
    required this.status,
    this.overview,
    this.error,
    this.notReadable = false,
  });

  const ClusterOverviewState.idle()
    : this._(status: ClusterOverviewStatus.idle);

  const ClusterOverviewState.loading({ClusterOverview? previous})
    : this._(status: ClusterOverviewStatus.loading, overview: previous);

  const ClusterOverviewState.loaded(ClusterOverview overview)
    : this._(status: ClusterOverviewStatus.loaded, overview: overview);

  const ClusterOverviewState.error(String message, {bool notReadable = false})
    : this._(
        status: ClusterOverviewStatus.error,
        error: message,
        notReadable: notReadable,
      );
}

class ClusterOverviewController extends ChangeNotifier {
  final KafkaMetadataService? _metadataServiceOverride;
  final TopicController? _topicControllerOverride;
  final Map<String, ClusterOverviewState> _states = {};
  final Map<String, int> _generations = {};

  ClusterOverviewController({
    KafkaMetadataService? metadataService,
    TopicController? topicController,
  }) : _metadataServiceOverride = metadataService,
       _topicControllerOverride = topicController;

  KafkaMetadataService get _metadataService =>
      _metadataServiceOverride ?? getIt<KafkaMetadataService>();

  TopicController? get _topicController {
    if (_topicControllerOverride != null) return _topicControllerOverride;
    return getIt.isRegistered<TopicController>()
        ? getIt<TopicController>()
        : null;
  }

  ClusterOverviewState stateFor(ClusterProfile profile) =>
      _states[profile.name] ?? const ClusterOverviewState.idle();

  Future<void> load(ClusterProfile profile) async {
    final current = stateFor(profile);
    if (current.status == ClusterOverviewStatus.loading ||
        current.status == ClusterOverviewStatus.loaded) {
      return;
    }
    await _fetchOverview(profile);
  }

  Future<void> refresh(ClusterProfile profile) async {
    final brokerFuture = _fetchOverview(profile);
    final topicFuture =
        _topicController?.fetchTopics(profile, force: true) ??
        Future<void>.value();
    await Future.wait([brokerFuture, topicFuture]);
  }

  Future<void> _fetchOverview(ClusterProfile profile) async {
    final key = profile.name;
    final gen = (_generations[key] ?? 0) + 1;
    _generations[key] = gen;

    _states[key] = ClusterOverviewState.loading(
      previous: _states[key]?.overview,
    );
    notifyListeners();

    try {
      final overview = await _metadataService.fetchClusterOverview(
        profile: profile,
      );
      if (_generations[key] != gen) return;
      _states[key] = ClusterOverviewState.loaded(overview);
      notifyListeners();
    } catch (e) {
      if (_generations[key] != gen) return;
      final msg = e.toString();
      final lower = msg.toLowerCase();
      final notReadable =
          lower.contains('not readable') || lower.contains('authorization');
      _states[key] = ClusterOverviewState.error(msg, notReadable: notReadable);
      notifyListeners();
    }
  }

  void clear(String clusterName) {
    _generations.remove(clusterName);
    if (_states.remove(clusterName) != null) {
      notifyListeners();
    }
  }

  void clearAll() {
    _generations.clear();
    if (_states.isNotEmpty) {
      _states.clear();
      notifyListeners();
    }
  }
}
