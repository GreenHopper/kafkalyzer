/// Represents a shareable reference to a specific Kafka message, topic location, and filter context.
class MessageReference {
  final String? cluster;
  final String topic;
  final int? partition;
  final int? offset;
  final String? filter;

  const MessageReference({
    this.cluster,
    required this.topic,
    this.partition,
    this.offset,
    this.filter,
  });

  /// Scheme used for shareable deep links.
  static const String scheme = 'kafkalyzer';
  static const String hostOpen = 'open';

  /// Serializes the reference into a standardized `kafkalyzer://open?...` URI.
  Uri toUri() {
    final queryParams = <String, String>{'topic': topic};

    if (cluster != null && cluster!.isNotEmpty) {
      queryParams['cluster'] = cluster!;
    }
    if (partition != null) {
      queryParams['partition'] = partition.toString();
    }
    if (offset != null) {
      queryParams['offset'] = offset.toString();
    }
    if (filter != null && filter!.isNotEmpty) {
      queryParams['filter'] = filter!;
    }

    return Uri(scheme: scheme, host: hostOpen, queryParameters: queryParams);
  }

  @override
  String toString() => toUri().toString();

  /// Parses a reference URI string into a [MessageReference].
  /// Returns `null` if the string cannot be parsed or lacks a required topic.
  static MessageReference? tryParse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;

    try {
      final uri = Uri.parse(trimmed);
      if (uri.scheme != scheme) {
        return null;
      }

      final queryParams = uri.queryParameters;
      final topic = queryParams['topic'];
      if (topic == null || topic.trim().isEmpty) {
        return null;
      }

      int? partition;
      if (queryParams.containsKey('partition')) {
        partition = int.tryParse(queryParams['partition']!);
      }

      int? offset;
      if (queryParams.containsKey('offset')) {
        offset = int.tryParse(queryParams['offset']!);
      }

      final cluster = queryParams['cluster'];
      final filter = queryParams['filter'];

      return MessageReference(
        topic: topic.trim(),
        cluster: cluster?.trim(),
        partition: partition,
        offset: offset,
        filter: filter,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageReference &&
          runtimeType == other.runtimeType &&
          cluster == other.cluster &&
          topic == other.topic &&
          partition == other.partition &&
          offset == other.offset &&
          filter == other.filter;

  @override
  int get hashCode =>
      cluster.hashCode ^
      topic.hashCode ^
      partition.hashCode ^
      offset.hashCode ^
      filter.hashCode;
}
