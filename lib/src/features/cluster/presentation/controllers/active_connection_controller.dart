import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
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
  // _topics removed
  bool _isConnecting = false;
  bool _showInternalTopics = false;
  bool _showStreamTopics = false;
  String? _error;
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
  String? get error => _error;

  OpenTopicRecord? _activeTopic;
  final List<OpenTopicRecord> _openTopics = [];
  final Map<String, MessageStreamController> _streamControllers = {};
  final Map<String, TopicAnalysisController> _analysisControllers = {};

  OpenTopicRecord? get activeTopic => _activeTopic;
  List<OpenTopicRecord> get openTopics => List.unmodifiable(_openTopics);

  OpenTopicRecord? openTopic({
    required TopicMetadata topic,
    ClusterProfile? profile,
    bool forceNew = false,
  }) {
    final p = profile ?? _activeProfile;
    if (p == null) return null;

    if (!forceNew) {
      final existing = _openTopics.cast<OpenTopicRecord?>().firstWhere(
        (t) => t?.topic.name == topic.name && t?.profile.name == p.name,
        orElse: () => null,
      );
      if (existing != null) {
        _activeTopic = existing;
        notifyListeners();
        return existing;
      }
    }

    final newRecord = OpenTopicRecord(topic, p);
    _openTopics.add(newRecord);
    _activeTopic = newRecord;
    notifyListeners();
    return newRecord;
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
      notifyListeners();
    }
  }

  void setActiveTopicRecord(OpenTopicRecord? record) {
    if (record == null) {
      _activeTopic = null;
    } else {
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
    }
    notifyListeners();
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
    _openTopics.removeWhere((t) => t.id == tabId);

    _streamControllers[tabId]?.dispose();
    _streamControllers.remove(tabId);

    _analysisControllers[tabId]?.dispose();
    _analysisControllers.remove(tabId);

    if (_activeTopic?.id == tabId) {
      _activeTopic = _openTopics.isNotEmpty ? _openTopics.last : null;
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
    notifyListeners();
  }

  Future<void> connect(ClusterProfile profile) async {
    _isConnecting = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔌 Connecting to: ${profile.name}');

      // check if we have cached topics for this profile
      final cachedTopics = _topicController.getTopics(profile);
      if (cachedTopics != null && cachedTopics.isNotEmpty) {
        debugPrint('   Found cached topics, skipping validation');
        _activeProfile = profile;
        // This will update listeners but won't fetch if not forced
        await _topicController.fetchTopics(profile);
        _isConnecting = false;
        notifyListeners();
        return;
      }

      debugPrint('   Bootstrap Servers: ${profile.bootstrapServers}');
      debugPrint('   Keystore Path: ${profile.sslKeystoreLocation}');
      debugPrint('   Truststore Path: ${profile.sslTruststoreLocation}');

      final isValid = await _metadataService.validateConnection(
        profile: profile,
      );
      if (isValid) {
        _activeProfile = profile;
        // Fetch topics via controller
        await _topicController.fetchTopics(profile);
      } else {
        _error = "Connection failed validation";
      }
    } catch (e) {
      _logger.w("Failed to connect: $e");
      // Simplify error message for UI
      final errorString = e.toString();
      if (errorString.contains("BrokerTransportFailure")) {
        _error =
            "Connection Failed: Broker Transport Failure. Check your address and network.";
      } else if (errorString.contains("Connection refused")) {
        _error = "Connection Failed: Connection Refused.";
      } else if (errorString.contains("AnyhowException")) {
        // Extract the main message from AnyhowException
        final match = RegExp(
          r"AnyhowException\((.*?)\)",
        ).firstMatch(errorString);
        _error =
            match?.group(1) ??
            "Connection Error: ${errorString.split('\n').first}";
      } else {
        _error = "Connection Failed: ${errorString.split('\n').first}";
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  void disconnect() {
    _activeProfile = null;
    _activeTopic = null;
    _openTopics.clear();
    for (final controller in _streamControllers.values) {
      controller.dispose();
    }
    _streamControllers.clear();
    for (final controller in _analysisControllers.values) {
      controller.dispose();
    }
    _analysisControllers.clear();
    // _topics = []; // managed by controller
    _topicFilter = "";
    notifyListeners();
  }
}
