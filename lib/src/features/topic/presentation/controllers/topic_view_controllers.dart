import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_analysis_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';

/// The per-topic view controllers: one stream, analysis and facts controller per
/// open topic tab, keyed by tab id, or by `cluster:topic` for callers that only
/// know the name.
///
/// They are per-topic view state, so the topic module owns them; the
/// `controller-state-lifetime` capability covers them through the topic
/// controller's own lifetime — clearing the cached topic list clears these too.
class TopicViewControllerRegistry {
  final Map<String, MessageStreamController> _stream = {};
  final Map<String, TopicAnalysisController> _analysis = {};
  final Map<String, TopicFactsController> _facts = {};

  static String topicKey(String topicName, String clusterName) =>
      '$clusterName:$topicName';

  MessageStreamController stream(
    String tabKeyOrTopicName, [
    String? clusterName,
  ]) {
    final key = clusterName == null
        ? tabKeyOrTopicName
        : topicKey(tabKeyOrTopicName, clusterName);
    return _stream.putIfAbsent(key, MessageStreamController.new);
  }

  TopicAnalysisController analysis(
    String tabKeyOrTopicName, [
    String? clusterName,
  ]) {
    final key = clusterName == null
        ? tabKeyOrTopicName
        : topicKey(tabKeyOrTopicName, clusterName);
    return _analysis.putIfAbsent(key, TopicAnalysisController.new);
  }

  TopicFactsController facts(
    String tabKeyOrTopicName,
    ClusterProfile profile,
    String topicName, [
    String? clusterName,
  ]) {
    final key = clusterName == null
        ? tabKeyOrTopicName
        : topicKey(tabKeyOrTopicName, clusterName);
    return _facts.putIfAbsent(
      key,
      () => TopicFactsController(profile: profile, topicName: topicName),
    );
  }

  /// Starts a stream with the user's default result limit, from the tail.
  void streamWithDefaults(
    String tabKey,
    ClusterProfile profile,
    String topicName,
  ) {
    final defaultLimit = getIt.isRegistered<SettingsService>()
        ? getIt<SettingsService>().defaultResultLimit.value
        : SettingsService.defaultResultLimitSetting.defaultValue;
    stream(tabKey).startStreaming(
      profile,
      topicName,
      filterType: FilterType.contains,
      searchScope: SearchScope.both,
      maxResults: defaultLimit,
      startFromTail: true,
      runForever: false,
    );
  }

  bool hasRunningOperations(Iterable<String> tabKeys) {
    for (final key in tabKeys) {
      if (_stream[key]?.isStreaming == true) return true;
      if (_analysis[key]?.isAnalyzing == true) return true;
    }
    return false;
  }

  void release(Iterable<String> tabKeys) {
    for (final key in tabKeys) {
      _stream.remove(key)?.dispose();
      _analysis.remove(key)?.dispose();
      _facts.remove(key)?.dispose();
    }
  }

  void releaseByName(String topicName, String clusterName) =>
      release([topicKey(topicName, clusterName)]);

  void releaseAll() {
    release([..._stream.keys, ..._analysis.keys, ..._facts.keys]);
  }
}
