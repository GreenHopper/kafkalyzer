import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// The topic names the app already knows for one cluster profile.
///
/// The schema dialogs list the topics a subject is associated with, so they need
/// the cluster's topic names. Reaching into the topic feature for them would
/// couple the two modules in both directions, so the topic feature answers
/// through this port instead, over its own cache.
abstract class TopicNameSource {
  /// The known topic names for [profile], or `null` when they are not loaded —
  /// which is not the same as a cluster without topics.
  List<String>? topicNames(ClusterProfile profile);
}
