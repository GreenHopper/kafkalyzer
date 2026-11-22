import 'dart:async';

import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';

/// Builds a filtered Kafka message stream for one topic scan.
///
/// The seam every consumer of a scan injects, so a test can substitute a
/// recorded stream. It lives here rather than in a feature because both the
/// topic stream controller and the multi-search controller build on it.
typedef MessageConsumeStreamFactory =
    Stream<KafkaMessage> Function({
      required ClusterProfile profile,
      required String topic,
      List<String>? filterTerms,
      String? filterField,
      required FilterType filterType,
      required SearchScope searchScope,
      String? filterExpression,
      Map<String, List<String>>? filterVariables,
      String? fastTraceKey,
      int? startOffset,
      int? startTimestamp,
      int? startPartition,
      int? maxResults,
      int? endOffset,
      int? endTimestamp,
      required bool runForever,
      bool? startFromTail,
      TopicLocalSchemasDto? localSchemas,
    });

/// The default seam: packs the app's named criteria into the single request
/// object the native layer takes.
Stream<KafkaMessage> bridgeConsumeStream({
  required ClusterProfile profile,
  required String topic,
  List<String>? filterTerms,
  String? filterField,
  required FilterType filterType,
  required SearchScope searchScope,
  String? filterExpression,
  Map<String, List<String>>? filterVariables,
  String? fastTraceKey,
  int? startOffset,
  int? startTimestamp,
  int? startPartition,
  int? maxResults,
  int? endOffset,
  int? endTimestamp,
  required bool runForever,
  bool? startFromTail,
  TopicLocalSchemasDto? localSchemas,
}) => consumeWithFilter(
  request: ConsumeRequest(
    profile: profile,
    topic: topic,
    filterTerms: filterTerms,
    filterField: filterField,
    filterType: filterType,
    searchScope: searchScope,
    filterExpression: filterExpression,
    filterVariables: filterVariables,
    fastTraceKey: fastTraceKey,
    startOffset: startOffset,
    startTimestamp: startTimestamp,
    startPartition: startPartition,
    maxResults: maxResults,
    endOffset: endOffset,
    endTimestamp: endTimestamp,
    runForever: runForever,
    startFromTail: startFromTail,
    localSchemas: localSchemas,
  ),
);
