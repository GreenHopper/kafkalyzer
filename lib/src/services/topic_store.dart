import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// The topic module's cached topic list and per-topic view state, as far as the
/// rest of the app needs to drive it.
///
/// Implemented by the session-wide topic controller: a module can then fetch or
/// clear topics and release a closed tab's controllers without importing the
/// topic feature. It is an alias for that controller, not extra session-wide
/// state.
abstract class TopicStore {
  List<TopicMetadata>? cachedTopics(ClusterProfile profile);

  bool hasCachedTopics(ClusterProfile profile);

  Future<void> refreshTopics(ClusterProfile profile);

  Future<TopicMetadata> resolveTopic(ClusterProfile profile, String name);

  /// Drops the cached topic list and, with it, the per-topic view state.
  void clearTopics(ClusterProfile profile);

  Future<void> loadTopicPreferences(ClusterProfile profile);

  void resetTopicListView();

  bool hasRunningTopicOperations(Iterable<String> tabIds);

  void releaseTopicViews(Iterable<String> tabIds);

  /// Releases the view state a caller only knows by name, e.g. a topic closed
  /// from the sidebar.
  void releaseTopicViewByName(String topicName, String clusterName);

  void startTopicStream(String tabId, ClusterProfile profile, String topicName);

  /// What repaints the cached topic list, e.g. a topic list row or a picker that
  /// marks clusters with cached topics.
  Listenable get topicListenable;
}
