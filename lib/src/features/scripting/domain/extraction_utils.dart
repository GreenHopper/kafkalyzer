import 'dart:convert';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

class ExtractionUtils {
  static String? extract(ScriptExtraction extraction, KafkaMessage msg) {
    if (extraction.topic != null && extraction.topic != msg.topic) {
      return null;
    }

    String? data;
    if (extraction.source == ScriptExtractionSource.key) {
      data = msg.key;
    } else {
      data = msg.payload;
    }

    if (data == null) return null;

    if (extraction.jsonPath.isEmpty) {
      return data;
    } else {
      try {
        final dynamic json = jsonDecode(data);
        return _extractValue(json, extraction.jsonPath);
      } catch (e) {
        return null;
      }
    }
  }

  static String? _extractValue(dynamic data, String path) {
    if (path.isEmpty) return null;
    final parts = path.split('.');
    dynamic current = data;

    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current?.toString();
  }
}
