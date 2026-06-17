import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

class ScriptResultMessage extends KafkaMessage {
  final String stepName;
  final String stepId;

  const ScriptResultMessage({
    required super.topic,
    required super.partition,
    required super.offset,
    super.key,
    super.payload,
    required super.timestamp,
    required this.stepName,
    required this.stepId,
  });
}
