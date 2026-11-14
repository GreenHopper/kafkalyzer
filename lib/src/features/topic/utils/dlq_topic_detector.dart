import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

/// Utility for detecting DLQ and retry topics and extracting failure metadata from message headers.
class DlqFailureMetadata {
  final String? originalTopic;
  final int? originalPartition;
  final int? originalOffset;
  final String? exceptionMessage;
  final String? exceptionStacktrace;
  final String? exceptionClass;
  final int? originalTimestamp;

  const DlqFailureMetadata({
    this.originalTopic,
    this.originalPartition,
    this.originalOffset,
    this.exceptionMessage,
    this.exceptionStacktrace,
    this.exceptionClass,
    this.originalTimestamp,
  });

  bool get hasCoordinates =>
      originalTopic != null &&
      originalPartition != null &&
      originalOffset != null;

  bool get hasException =>
      (exceptionMessage != null && exceptionMessage!.isNotEmpty) ||
      (exceptionClass != null && exceptionClass!.isNotEmpty);

  bool get hasFailureInfo => hasCoordinates || hasException;

  /// Builds a structured JSON-serializable failure report for [message].
  ///
  /// Preserves `null` vs empty string for `key` and `value`, and omits
  /// `original` and `exception` when unknown.
  Map<String, Object?> toFailureReport(KafkaMessage message) {
    final headersMap = <String, String>{
      for (final h in message.headers ?? const <KafkaHeader>[]) h.key: h.value,
    };

    final report = <String, Object?>{
      'dlqMessage': <String, Object?>{
        'topic': message.topic,
        'partition': message.partition,
        'offset': message.offset,
        'timestamp': message.timestamp,
        'key': message.key,
        'value': message.payload,
        'headers': headersMap,
      },
    };

    if (hasCoordinates) {
      report['original'] = <String, Object?>{
        'topic': originalTopic,
        'partition': originalPartition,
        'offset': originalOffset,
      };
    }

    if (hasException) {
      report['exception'] = <String, Object?>{
        if (exceptionMessage != null && exceptionMessage!.isNotEmpty)
          'message': exceptionMessage,
        if (exceptionClass != null && exceptionClass!.isNotEmpty)
          'class': exceptionClass,
      };
    }

    return report;
  }

  static DlqFailureMetadata? fromHeaders(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) return null;

    final lowerMap = <String, String>{};
    headers.forEach((k, v) => lowerMap[k.toLowerCase()] = v);

    String? getVal(List<String> keys) {
      for (final key in keys) {
        final val = lowerMap[key.toLowerCase()];
        if (val != null && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
      return null;
    }

    int? getIntVal(List<String> keys) {
      final str = getVal(keys);
      if (str == null) return null;
      return int.tryParse(str);
    }

    final originalTopic = getVal([
      'x-original-topic',
      'kafka_dlt-original-topic',
      'deadletter.topic',
      'dlt-original-topic',
      'original-topic',
    ]);

    final originalPartition = getIntVal([
      'x-original-partition',
      'kafka_dlt-original-partition',
      'deadletter.partition',
      'dlt-original-partition',
      'original-partition',
    ]);

    final originalOffset = getIntVal([
      'x-original-offset',
      'kafka_dlt-original-offset',
      'deadletter.offset',
      'dlt-original-offset',
      'original-offset',
    ]);

    final exceptionMessage = getVal([
      'x-exception-message',
      'kafka_dlt-exception-message',
      'deadletter.reason',
      'deadletter.exception-message',
      'exception-message',
    ]);

    final exceptionClass = getVal([
      'x-exception-class',
      'x-exception-fqcn',
      'kafka_dlt-exception-fqcn',
      'deadletter.exception-fqcn',
      'exception-class',
    ]);

    final exceptionStacktrace = getVal([
      'x-exception-stacktrace',
      'kafka_dlt-exception-stacktrace',
      'deadletter.stacktrace',
      'exception-stacktrace',
    ]);

    final originalTimestamp = getIntVal([
      'x-original-timestamp',
      'kafka_dlt-original-timestamp',
      'deadletter.timestamp',
      'original-timestamp',
    ]);

    final metadata = DlqFailureMetadata(
      originalTopic: originalTopic,
      originalPartition: originalPartition,
      originalOffset: originalOffset,
      exceptionMessage: exceptionMessage,
      exceptionClass: exceptionClass,
      exceptionStacktrace: exceptionStacktrace,
      originalTimestamp: originalTimestamp,
    );

    return metadata.hasFailureInfo ? metadata : null;
  }
}

class DlqTopicDetector {
  static final RegExp _dlqSuffixRegex = RegExp(
    r'[-_.](?:dlq|dlt|deadletter|error)$',
    caseSensitive: false,
  );

  static final RegExp _retryPatternRegex = RegExp(
    r'[-_.](?:retry)(?:[-_.]\d+)?$',
    caseSensitive: false,
  );

  /// Returns true if [topicName] matches DLQ naming patterns.
  static bool isDlqTopic(String topicName) {
    return _dlqSuffixRegex.hasMatch(topicName);
  }

  /// Returns true if [topicName] matches retry naming patterns.
  static bool isRetryTopic(String topicName) {
    return _retryPatternRegex.hasMatch(topicName);
  }

  /// Returns true if [topicName] is either a DLQ or retry topic.
  static bool isFailureTopic(String topicName) {
    return isDlqTopic(topicName) || isRetryTopic(topicName);
  }

  /// Resolves the primary/base topic name from a DLQ or retry topic.
  /// If the topic is not a failure topic, returns [topicName] unmodified.
  static String resolveBaseTopic(String topicName) {
    if (isDlqTopic(topicName)) {
      final match = _dlqSuffixRegex.firstMatch(topicName);
      if (match != null) {
        return topicName.substring(0, match.start);
      }
    }

    if (isRetryTopic(topicName)) {
      final match = _retryPatternRegex.firstMatch(topicName);
      if (match != null) {
        return topicName.substring(0, match.start);
      }
    }

    return topicName;
  }

  /// Categorizes a list of topics into base topics and their child failure topics.
  /// Keys are base topic names, and values are lists of associated DLQ and retry topics.
  static Map<String, List<String>> groupFailureTopicsByBase(
    List<String> allTopics,
  ) {
    final Map<String, List<String>> mapping = {};

    for (final topic in allTopics) {
      if (isFailureTopic(topic)) {
        final base = resolveBaseTopic(topic);
        mapping.putIfAbsent(base, () => []).add(topic);
      }
    }

    return mapping;
  }
}
