import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

/// Deterministic total-order tie-breaker for [KafkaMessage]s:
/// compares `topic`, then `partition`, then `offset`.
int compareMessageIdentity(KafkaMessage a, KafkaMessage b) {
  final topicCmp = a.topic.compareTo(b.topic);
  if (topicCmp != 0) return topicCmp;
  final partCmp = a.partition.compareTo(b.partition);
  if (partCmp != 0) return partCmp;
  return a.offset.compareTo(b.offset);
}
