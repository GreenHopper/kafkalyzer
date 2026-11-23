/// Utility for detecting DLQ and retry topics by name.
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
    final len = topicName.length;
    if (len < 4) return false;
    final last = topicName.codeUnitAt(len - 1);
    // Must end with 'q'/'Q' (dlq), 't'/'T' (dlt), or 'r'/'R' (deadletter/error).
    if (last != 113 &&
        last != 81 &&
        last != 116 &&
        last != 84 &&
        last != 114 &&
        last != 82) {
      return false;
    }
    return _dlqSuffixRegex.hasMatch(topicName);
  }

  /// Returns true if [topicName] matches retry naming patterns.
  static bool isRetryTopic(String topicName) {
    final len = topicName.length;
    if (len < 6) return false;
    var i = len - 1;
    final last = topicName.codeUnitAt(i);
    if (last >= 48 && last <= 57) {
      while (i >= 0) {
        final c = topicName.codeUnitAt(i);
        if (c < 48 || c > 57) break;
        i--;
      }
      if (i < 6) return false;
      final sep = topicName.codeUnitAt(i);
      if (sep != 45 && sep != 95 && sep != 46) return false;
      i--;
    }
    final y = topicName.codeUnitAt(i);
    if (y != 121 && y != 89) return false;
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
