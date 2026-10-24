import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

class ExtractionUtils {
  /// Resolve one extraction for a single message.
  static Future<String?> extract(
    ScriptExtraction extraction,
    KafkaMessage msg,
  ) async {
    final values = await extractAll(extraction, [msg]);
    return values.isEmpty ? null : values.first;
  }

  /// Resolve one extraction for many messages in a single resolver call.
  ///
  /// The path grammar lives in `kafkalyzer_core::json_path`, so an extraction
  /// path means the same thing as a projected table column path and a message
  /// filter field.
  static Future<List<String?>> extractAll(
    ScriptExtraction extraction,
    List<KafkaMessage> messages,
  ) async {
    final sources = messages.map((msg) {
      if (extraction.topic != null && extraction.topic != msg.topic) {
        return null;
      }
      return extraction.source == ScriptExtractionSource.key
          ? msg.key
          : msg.payload;
    }).toList();

    if (extraction.jsonPath.isEmpty) {
      // No path configured: the whole value or key is the extracted value.
      return sources;
    }

    final payloads = sources.map((source) => source ?? '').toList();
    final values = await resolveJsonPathBatch(
      payloads: payloads,
      paths: [extraction.jsonPath],
    );

    return [
      for (var i = 0; i < messages.length; i++)
        sources[i] == null ? null : values[i],
    ];
  }
}
