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

  /// Generates a ready-to-run kcat CLI replay command to produce the message payload back to the origin topic.
  String generateKcatReplayCommand({
    required String bootstrapServers,
    String? key,
    String? payload,
  }) {
    final targetTopic = originalTopic ?? 'TOPIC_NAME';
    final buffer = StringBuffer();

    // Escape single quotes for bash
    final escapedPayload = (payload ?? '').replaceAll("'", "'\\''");
    buffer.write("printf '%s' '$escapedPayload' | kcat -b $bootstrapServers -t $targetTopic -P");

    if (key != null && key.isNotEmpty) {
      final escapedKey = key.replaceAll("'", "'\\''");
      buffer.write(" -k '$escapedKey'");
    }

    return buffer.toString();
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
