import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

class MessageExportService {
  final Logger _logger = getIt<Logger>();

  /// Exports a list of [KafkaMessage]s.
  /// If all messages belong to a single topic, it exports a single .json file.
  /// If messages come from multiple topics, it groups them and exports a .zip containing one JSON file per topic.
  Future<void> exportMessages(List<KafkaMessage> messages) async {
    if (messages.isEmpty) return;

    try {
      // Group messages by topic
      final Map<String, List<KafkaMessage>> messagesByTopic = {};
      for (final msg in messages) {
        messagesByTopic.putIfAbsent(msg.topic, () => []).add(msg);
      }

      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (messagesByTopic.length == 1) {
        // Single topic export (JSON)
        final topic = messagesByTopic.keys.first;
        final jsonContent = _serializeMessages(messagesByTopic[topic]!);
        
        final fileName = '${topic}_$timestampStr.json';
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Export Messages',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['json'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(jsonContent);
          _logger.i('Successfully exported messages to $outputFile');
        }
      } else {
        // Multi-topic export (ZIP)
        final archive = Archive();
        
        for (final entry in messagesByTopic.entries) {
          final topic = entry.key;
          final topicMessages = entry.value;
          
          final jsonContent = _serializeMessages(topicMessages);
          final bytes = utf8.encode(jsonContent);
          
          final archiveFile = ArchiveFile('$topic.json', bytes.length, bytes);
          archive.addFile(archiveFile);
        }

        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);

        final fileName = 'messages_export_$timestampStr.zip';
        final outputFile = await FilePicker.saveFile(
          dialogTitle: 'Export Messages',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(zipBytes);
          _logger.i('Successfully exported messages to $outputFile');
        }
      }
    } catch (e, st) {
      _logger.e('Failed to export messages', error: e, stackTrace: st);
      rethrow;
    }
  }

  String _serializeMessages(List<KafkaMessage> messages) {
    final list = messages.map((msg) => {
      'topic': msg.topic,
      'partition': msg.partition,
      'offset': msg.offset.toString(),
      'timestamp': msg.timestamp.toString(),
      'key': msg.key,
      'payload': msg.payload != null ? _tryParseJson(msg.payload!) : null,
    }).toList();

    return const JsonEncoder.withIndent('  ').convert(list);
  }

  dynamic _tryParseJson(String source) {
    try {
      return jsonDecode(source);
    } catch (_) {
      // Return as plain string if it's not valid JSON
      return source;
    }
  }
}
