import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/domain/connection_error.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
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

  TopicController get _topicController =>
      getIt<
        TopicController
      >(); // Use getter to avoid constructor dependency cycle if any (lazy singleton handles it though)

  ClusterProfile? _activeProfile;
  ClusterProfile? _connectingProfile;
  // _topics removed
  bool _isConnecting = false;
  bool _showInternalTopics = false;
  bool _showStreamTopics = false;
  ConnectionError? _error;
  String _topicFilter = "";

  bool get showInternalTopics => _showInternalTopics;
  bool get showStreamTopics => _showStreamTopics;
  String get topicFilter => _topicFilter;

  void toggleShowInternalTopics(bool value) {
    _showInternalTopics = value;
    notifyListeners();
  }

  void toggleShowStreamTopics(bool value) {
    _showStreamTopics = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  ClusterProfile? get activeProfile => _activeProfile;
  ClusterProfile? get connectingProfile => _connectingProfile;
  bool isConnectingCluster(ClusterProfile profile) =>
      _connectingProfile?.name == profile.name;
  List<TopicMetadata> get topics {
    if (_activeProfile == null) return [];

    final allTopics = _topicController.getTopics(_activeProfile!) ?? [];

    var filtered = allTopics;

    // Filter internal topics if not shown
    if (!_showInternalTopics) {
      filtered = filtered.where((t) => !t.name.startsWith("_")).toList();
    }

    // Filter stream topics if not shown
    if (!_showStreamTopics) {
      filtered = filtered.where((t) {
        final name = t.name.toLowerCase();
        return !name.endsWith("-topic") &&
            !name.endsWith("-changelog") &&
            !name.endsWith("-repartition");
      }).toList();
    }

    if (_topicFilter.isEmpty) {
      return filtered;
    }
    return filtered
        .where((t) => t.name.toLowerCase().contains(_topicFilter.toLowerCase()))
        .toList();
  }

  void updateTopicFilter(String filter) {
    _topicFilter = filter;
    notifyListeners();
  }

  bool get isConnecting =>
      _isConnecting ||
      (_activeProfile != null && _topicController.isLoading(_activeProfile!));
  ConnectionError? get error => _error;

  OpenTopicRecord? _activeTopic;
  final List<OpenTopicRecord> _openTopics = [];
  final Map<String, MessageStreamController> _streamControllers = {};
  final Map<String, TopicAnalysisController> _analysisControllers = {};
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

  bool hasRunningOperations(ClusterProfile profile) {
    for (final record in _openTopics) {
      if (record.profile.name != profile.name) continue;
      if (_streamControllers[record.id]?.isStreaming == true) return true;
      if (_analysisControllers[record.id]?.isAnalyzing == true) return true;
    }
    return false;
  }

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

  OpenTopicRecord? streamTopicWithDefaults(
    TopicMetadata topic, [
    ClusterProfile? profile,
  ]) {
    final record = openTopic(topic: topic, profile: profile, forceNew: false);
    if (record == null) return null;

    final defaultLimit = getIt.isRegistered<SettingsService>()
        ? getIt<SettingsService>().defaultResultLimit.value
        : SettingsService.defaultResultLimitSetting.defaultValue;
    final controller = getStreamController(record.id);
    controller.startStreaming(
      record.profile,
      record.topic.name,
      filterType: FilterType.contains,
      searchScope: SearchScope.both,
      maxResults: defaultLimit,
      startFromTail: true,
      runForever: false,
    );
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

  String _getTopicKey(String topicName, String clusterName) {
    return '$clusterName:$topicName';
  }

  MessageStreamController getStreamController(
    String tabIdOrTopicName, [
    String? clusterName,
  ]) {
    final key = clusterName != null
        ? _getTopicKey(tabIdOrTopicName, clusterName)
        : tabIdOrTopicName;
    if (!_streamControllers.containsKey(key)) {
      _streamControllers[key] = MessageStreamController();
    }
    return _streamControllers[key]!;
  }

  TopicAnalysisController getAnalysisController(
    String tabIdOrTopicName, [
    String? clusterName,
  ]) {
    final key = clusterName != null
        ? _getTopicKey(tabIdOrTopicName, clusterName)
        : tabIdOrTopicName;
    if (!_analysisControllers.containsKey(key)) {
      _analysisControllers[key] = TopicAnalysisController();
    }
    return _analysisControllers[key]!;
  }

  void closeTopicTab(String tabId) {
    final removed = _openTopics.cast<OpenTopicRecord?>().firstWhere(
      (t) => t?.id == tabId,
      orElse: () => null,
    );
    _openTopics.removeWhere((t) => t.id == tabId);

    _streamControllers[tabId]?.dispose();
    _streamControllers.remove(tabId);

    _analysisControllers[tabId]?.dispose();
    _analysisControllers.remove(tabId);

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

    final key = _getTopicKey(topic.name, clusterName);
    _streamControllers[key]?.dispose();
    _streamControllers.remove(key);

    _analysisControllers[key]?.dispose();
    _analysisControllers.remove(key);
  }

  void clearOpenTopics() {
    final clusterNames = _openTopics.map((t) => t.profile.name).toSet();
    _openTopics.clear();
    for (final controller in _streamControllers.values) {
      controller.dispose();
    }
    _streamControllers.clear();
    for (final controller in _analysisControllers.values) {
      controller.dispose();
    }
    _analysisControllers.clear();
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

      final topics = _topicController.getTopics(profile);
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
      final cachedTopics = _topicController.getTopics(effectiveProfile);
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        debugPrint('   Found cached topics, skipping validation');
        _activeProfile = effectiveProfile;
        // This will update listeners but won't fetch if not forced
        await _topicController.fetchTopics(effectiveProfile);
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
        // Fetch topics via controller
        await _topicController.fetchTopics(effectiveProfile);
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
    _topicFilter = "";

    if (active == null) {
      notifyListeners();
      return;
    }

    final toClose = _openTopics
        .where((t) => t.profile.name == active.name)
        .toList();
    for (final record in toClose) {
      _openTopics.removeWhere((t) => t.id == record.id);
      _streamControllers[record.id]?.dispose();
      _streamControllers.remove(record.id);
      _analysisControllers[record.id]?.dispose();
      _analysisControllers.remove(record.id);
    }

    if (_activeTopic?.profile.name == active.name) {
      _activeTopic = _openTopics.isNotEmpty ? _openTopics.last : null;
    }

    _topicController.clearCache(active);
    notifyListeners();
  }
}
