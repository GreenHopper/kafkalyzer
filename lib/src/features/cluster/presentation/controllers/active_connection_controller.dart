import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/topic_store.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

class OpenTopicRecord {
  final String id;
  final TopicMetadata topic;
  final ClusterProfile profile;

  OpenTopicRecord(this.topic, this.profile, {String? id})
    : id =
          id ??
          '${profile.name}:${topic.name}:${DateTime.now().microsecondsSinceEpoch}';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OpenTopicRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class ActiveConnectionController extends ChangeNotifier {
  final Logger _logger = getIt<Logger>();
  final KafkaMetadataService _metadataService = getIt<KafkaMetadataService>();

  // The topic module's cache and per-topic view state, reached through the
  // shared port so this feature does not import the topic module.
  TopicStore get _topics => getIt<TopicStore>();

  ClusterProfile? _activeProfile;
  ClusterProfile? _connectingProfile;
  bool _isConnecting = false;
  ConnectionError? _error;

  void clearError() {
    _error = null;
    notifyListeners();
  }

  ClusterProfile? get activeProfile => _activeProfile;
  ClusterProfile? get connectingProfile => _connectingProfile;
  bool isConnectingCluster(ClusterProfile profile) =>
      _connectingProfile?.name == profile.name;

  bool get isConnecting => _isConnecting;
  ConnectionError? get error => _error;

  OpenTopicRecord? _activeTopic;
  final List<OpenTopicRecord> _openTopics = [];
  final Map<String, String?> _lastActiveTopicByCluster = {};
  bool _restoring = false;
  List<String> _unrestoredTopics = const [];

  OpenTopicRecord? get activeTopic => _activeTopic;
  List<OpenTopicRecord> get openTopics => List.unmodifiable(_openTopics);
  List<String> get unrestoredTopics => _unrestoredTopics;

  void acknowledgeUnrestoredTopics() {
    if (_unrestoredTopics.isEmpty) return;
    _unrestoredTopics = const [];
    notifyListeners();
  }

  bool hasRunningOperations(ClusterProfile profile) =>
      _topics.hasRunningTopicOperations(
        _openTopics
            .where((t) => t.profile.name == profile.name)
            .map((t) => t.id),
      );

  OpenTopicRecord? openTopic({
    required TopicMetadata topic,
    ClusterProfile? profile,
    bool forceNew = false,
  }) {
    final p = profile ?? _activeProfile;
    if (p == null) return null;

    try {
      getIt<RecentTopicsService>().recordVisit(
        clusterName: p.name,
        topicName: topic.name,
      );
    } catch (_) {}

    if (!forceNew) {
      final existing = _openTopics.cast<OpenTopicRecord?>().firstWhere(
        (t) => t?.topic.name == topic.name && t?.profile.name == p.name,
        orElse: () => null,
      );
      if (existing != null) {
        _activeTopic = existing;
        _lastActiveTopicByCluster[p.name] = existing.topic.name;
        notifyListeners();
        _saveSessionTabs(p.name);
        return existing;
      }
    }

    final newRecord = OpenTopicRecord(topic, p);
    _openTopics.add(newRecord);
    _activeTopic = newRecord;
    _lastActiveTopicByCluster[p.name] = newRecord.topic.name;
    notifyListeners();
    _saveSessionTabs(p.name);
    return newRecord;
  }

  Future<OpenTopicRecord?> openTopicByName(
    ClusterProfile profile,
    String name, {
    bool forceNew = false,
  }) async {
    final meta = await _topics.resolveTopic(profile, name);
    return openTopic(topic: meta, profile: profile, forceNew: forceNew);
  }

  OpenTopicRecord? streamTopicWithDefaults(
    TopicMetadata topic, [
    ClusterProfile? profile,
  ]) {
    final record = openTopic(topic: topic, profile: profile, forceNew: false);
    if (record == null) return null;

    _topics.startTopicStream(record.id, record.profile, record.topic.name);
    return record;
  }

  void setActiveTopic(TopicMetadata? topic, [ClusterProfile? profile]) {
    if (topic != null) {
      openTopic(topic: topic, profile: profile, forceNew: false);
    } else {
      _activeTopic = null;
      notifyListeners();
    }
  }

  void setActiveTabId(String tabId) {
    final record = _openTopics.cast<OpenTopicRecord?>().firstWhere(
      (t) => t?.id == tabId,
      orElse: () => null,
    );
    if (record != null) {
      _activeTopic = record;
      _lastActiveTopicByCluster[record.profile.name] = record.topic.name;
      notifyListeners();
      _saveSessionTabs(record.profile.name);
    }
  }

  void setActiveTopicRecord(OpenTopicRecord? record) {
    if (record == null) {
      _activeTopic = null;
      notifyListeners();
      return;
    }
    final existing = _openTopics.cast<OpenTopicRecord?>().firstWhere(
      (t) => t?.id == record.id,
      orElse: () => null,
    );
    if (existing != null) {
      _activeTopic = existing;
    } else {
      _openTopics.add(record);
      _activeTopic = record;
    }
    _lastActiveTopicByCluster[record.profile.name] = record.topic.name;
    notifyListeners();
    _saveSessionTabs(record.profile.name);
  }

  void closeTopicTab(String tabId) {
    final removed = _openTopics.cast<OpenTopicRecord?>().firstWhere(
      (t) => t?.id == tabId,
      orElse: () => null,
    );
    _openTopics.removeWhere((t) => t.id == tabId);

    _topics.releaseTopicViews([tabId]);

    if (_activeTopic?.id == tabId) {
      _activeTopic = _openTopics.isNotEmpty ? _openTopics.last : null;
    }
    if (removed != null) {
      final clusterName = removed.profile.name;
      final remainingForCluster = _openTopics
          .where((t) => t.profile.name == clusterName)
          .toList();
      if (_lastActiveTopicByCluster[clusterName] == removed.topic.name) {
        _lastActiveTopicByCluster[clusterName] = remainingForCluster.isNotEmpty
            ? remainingForCluster.last.topic.name
            : null;
      }
      notifyListeners();
      _saveSessionTabs(clusterName);
      return;
    }
    notifyListeners();
  }

  void closeTopic(TopicMetadata topic, String clusterName) {
    final matching = _openTopics
        .where(
          (t) => t.topic.name == topic.name && t.profile.name == clusterName,
        )
        .toList();
    for (final record in matching) {
      closeTopicTab(record.id);
    }

    _topics.releaseTopicViewByName(topic.name, clusterName);
  }

  void clearOpenTopics() {
    final clusterNames = _openTopics.map((t) => t.profile.name).toSet();
    final ids = _openTopics.map((t) => t.id).toList();
    _openTopics.clear();
    _topics.releaseTopicViews(ids);
    _activeTopic = null;
    _lastActiveTopicByCluster.clear();
    notifyListeners();
    for (final name in clusterNames) {
      _saveSessionTabs(name);
    }
  }

  void _saveSessionTabs(String clusterName) {
    if (_restoring) return;
    try {
      final topicNames = _openTopics
          .where((t) => t.profile.name == clusterName)
          .map((t) => t.topic.name)
          .toList();
      final candidateActive = _activeTopic?.profile.name == clusterName
          ? _activeTopic?.topic.name
          : _lastActiveTopicByCluster[clusterName];
      final activeName =
          (candidateActive != null && topicNames.contains(candidateActive))
          ? candidateActive
          : (topicNames.isNotEmpty ? topicNames.last : null);
      getIt<SessionRestoreService>().saveSession(
        clusterName,
        openTopicNames: topicNames,
        activeTopicName: activeName,
      );
    } catch (_) {}
  }

  Future<void> _restoreSessionTabs(ClusterProfile profile) async {
    try {
      final restoreService = getIt<SessionRestoreService>();
      if (!await restoreService.isRestorationEnabled()) return;

      final session = await restoreService.getSession(profile.name);
      if (session == null || session.openTopicNames.isEmpty) return;

      final topics = _topics.cachedTopics(profile);
      if (topics == null) return;
      final topicMap = {for (final t in topics) t.name: t};

      final missing = <String>[];
      _restoring = true;
      try {
        for (final name in session.openTopicNames) {
          final topic = topicMap[name];
          if (topic != null) {
            openTopic(topic: topic, profile: profile, forceNew: false);
          } else {
            missing.add(name);
          }
        }

        if (session.activeTopicName != null) {
          final activeRecord = _openTopics.cast<OpenTopicRecord?>().firstWhere(
            (t) =>
                t?.profile.name == profile.name &&
                t?.topic.name == session.activeTopicName,
            orElse: () => null,
          );
          if (activeRecord != null) {
            _activeTopic = activeRecord;
            _lastActiveTopicByCluster[profile.name] = activeRecord.topic.name;
          }
        }
        _unrestoredTopics = List.unmodifiable(missing);
        notifyListeners();
      } finally {
        _restoring = false;
      }
      _saveSessionTabs(profile.name);
    } catch (_) {}
  }

  Future<void> connect(ClusterProfile profile) async {
    if (_connectingProfile?.name == profile.name) {
      return;
    }

    final tools = getIt.isRegistered<ClusterProfileTools>()
        ? getIt<ClusterProfileTools>()
        : const ClusterProfileTools();
    final bootstrapIssues = tools.validateBootstrapServers(
      profile.bootstrapServers,
    );
    if (bootstrapIssues.isNotEmpty) {
      _error = ConnectionError(
        kind: ConnectionErrorKind.invalidBootstrapServers,
        detail: bootstrapIssues.first.entry,
      );
      notifyListeners();
      return;
    }

    _connectingProfile = profile;
    _isConnecting = true;
    _error = null;
    notifyListeners();

    var effectiveProfile = profile;
    try {
      if (effectiveProfile.tlsVerification == TlsVerification.unreviewed &&
          getIt.isRegistered<TlsTransitionController>()) {
        final resolution = await getIt<TlsTransitionController>()
            .resolveBeforeConnect(effectiveProfile);
        effectiveProfile = resolution.profile;
        if (resolution.blockedByCertificateRejection) {
          _error = ConnectionError(
            kind: ConnectionErrorKind.tlsVerificationFailed,
            detail: resolution.errorMessage ?? '',
          );
          return;
        }
      }

      debugPrint('🔌 Connecting to: ${effectiveProfile.name}');

      // check if we have cached topics for this profile
      final cachedTopics = _topics.cachedTopics(effectiveProfile);
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        debugPrint('   Found cached topics, skipping validation');
        _activeProfile = effectiveProfile;
        await _topics.loadTopicPreferences(effectiveProfile);
        // This will update listeners but won't fetch if not forced
        await _topics.refreshTopics(effectiveProfile);
        await _restoreSessionTabs(effectiveProfile);
        return;
      }

      debugPrint('   Bootstrap Servers: ${effectiveProfile.bootstrapServers}');
      debugPrint('   Keystore Path: ${effectiveProfile.sslKeystoreLocation}');
      debugPrint(
        '   Truststore Path: ${effectiveProfile.sslTruststoreLocation}',
      );

      final isValid = await _metadataService.validateConnection(
        profile: effectiveProfile,
      );
      if (isValid) {
        if (effectiveProfile.tlsVerification == TlsVerification.unreviewed &&
            getIt.isRegistered<TlsTransitionController>()) {
          effectiveProfile = await getIt<TlsTransitionController>()
              .markVerifiedIfUnreviewed(effectiveProfile);
        }
        _activeProfile = effectiveProfile;
        await _topics.loadTopicPreferences(effectiveProfile);
        // Fetch topics via controller
        await _topics.refreshTopics(effectiveProfile);
        await _restoreSessionTabs(effectiveProfile);
      } else {
        _error = const ConnectionError(
          kind: ConnectionErrorKind.validationFailed,
        );
      }
    } catch (e) {
      _logger.w("Failed to connect: $e");
      _error = classifyConnectionError(e);
    } finally {
      _connectingProfile = null;
      _isConnecting = false;
      notifyListeners();
    }
  }

  void disconnect() {
    final active = _activeProfile;
    _connectingProfile = null;
    _activeProfile = null;
    _topics.resetTopicListView();

    if (active == null) {
      notifyListeners();
      return;
    }

    final toClose = _openTopics
        .where((t) => t.profile.name == active.name)
        .toList();
    for (final record in toClose) {
      _openTopics.removeWhere((t) => t.id == record.id);
    }
    _topics.releaseTopicViews(toClose.map((t) => t.id));

    if (_activeTopic?.profile.name == active.name) {
      _activeTopic = _openTopics.isNotEmpty ? _openTopics.last : null;
    }

    _topics.clearTopics(active);
    notifyListeners();
  }
}
