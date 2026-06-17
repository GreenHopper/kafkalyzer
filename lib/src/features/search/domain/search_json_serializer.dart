import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';

class SearchJsonSerializer {
  static Map<String, dynamic> serializeTarget(SearchTarget target) {
    return {
      "cluster": target.profile.name,
      "topic": target.topic.name,
      "filterTerm": target.filterTerm,
      "filterTerms": target.filterTerms,
      "filterType": target.filterType.name,
      "searchScope": target.scope.name,
      "startOffset": target.startOffset,
      "startTimestamp": target.startTimestamp,
      "startPartition": target.startPartition,
      "fastTraceEnabled": target.fastTraceEnabled,
      "endStrategy": target.endStrategy.name,
      "endOffset": target.endOffset,
      "endTimestamp": target.endTimestamp,
      "maxResults": target.maxResults,
    };
  }

  static Map<String, dynamic> serializeMessage(KafkaMessage message) {
    return {
      "topic": message.topic,
      "partition": message.partition,
      "offset": message.offset,
      "key": message.key,
      "payload": message.payload,
      "timestamp": message.timestamp,
    };
  }

  static KafkaMessage deserializeMessage(Map<String, dynamic> json) {
    return KafkaMessage(
      topic: json['topic'] ?? "",
      partition: json['partition'] ?? 0,
      offset: json['offset'] ?? 0,
      key: json['key'],
      payload: json['payload'],
      timestamp: json['timestamp'] ?? 0,
    );
  }
}
