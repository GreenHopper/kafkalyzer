import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/messages/data/message_export_service.dart';

class SearchJsonSerializer {
  static Map<String, dynamic> serializeTarget(SearchTarget target) {
    return {
      "cluster": target.profile.name,
      "topic": target.topic.name,
      "filterTerm": target.filterTerm,
      "filterTerms": target.filterTerms,
      "filterType": target.filterType.name,
      "searchScope": target.scope.name,
      if (target.filterExpression != null &&
          target.filterExpression!.isNotEmpty)
        "filterExpression": target.filterExpression,
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
      "timestampIso": timestampIsoFromMillis(message.timestamp),
      "headers": (message.headers ?? const [])
          .map((h) => {"key": h.key, "value": h.value})
          .toList(),
      "keySchema": messageSchemaToMap(message.keySchema),
      "valueSchema": messageSchemaToMap(message.valueSchema),
      "keyLocalSchema": localSchemaUseToMap(message.keyLocalSchema),
      "valueLocalSchema": localSchemaUseToMap(message.valueLocalSchema),
    };
  }

  static KafkaMessage deserializeMessage(Map<String, dynamic> json) {
    List<KafkaHeader>? headers;
    final rawHeaders = json['headers'];
    if (rawHeaders is List) {
      final parsed = <KafkaHeader>[];
      for (final item in rawHeaders) {
        if (item is Map && item['key'] is String && item['value'] is String) {
          parsed.add(
            KafkaHeader(
              key: item['key'] as String,
              value: item['value'] as String,
            ),
          );
        }
      }
      headers = parsed;
    }

    return KafkaMessage(
      topic: json['topic'] ?? "",
      partition: json['partition'] ?? 0,
      offset: json['offset'] ?? 0,
      key: json['key'],
      payload: json['payload'],
      timestamp: json['timestamp'] ?? 0,
      headers: headers,
      keySchema: messageSchemaFromMap(json['keySchema']),
      valueSchema: messageSchemaFromMap(json['valueSchema']),
      keyLocalSchema: localSchemaUseFromMap(json['keyLocalSchema']),
      valueLocalSchema: localSchemaUseFromMap(json['valueLocalSchema']),
    );
  }
}
