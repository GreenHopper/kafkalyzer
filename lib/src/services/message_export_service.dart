import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

enum ExportFormat { json, ndjson, csv }

/// Converts a [MessageSchema] to a JSON-serializable map, or `null` when absent.
Map<String, dynamic>? messageSchemaToMap(MessageSchema? schema) {
  if (schema == null) return null;
  return {
    'schemaId': schema.schemaId,
    'subject': schema.subject,
    'version': schema.version,
  };
}

/// Parses a [MessageSchema] from a JSON map, returning `null` for missing or
/// malformed values.
MessageSchema? messageSchemaFromMap(dynamic raw) {
  if (raw is! Map) return null;
  final schemaId = raw['schemaId'];
  if (schemaId is! int) return null;
  final subject = raw['subject'];
  final version = raw['version'];
  return MessageSchema(
    schemaId: schemaId,
    subject: subject is String ? subject : null,
    version: version is int ? version : null,
  );
}

/// Converts epoch milliseconds to an ISO-8601 UTC string, or `null` when `0`.
String? timestampIsoFromMillis(int timestampMillis) {
  if (timestampMillis == 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    timestampMillis,
    isUtc: true,
  ).toIso8601String();
}

class MessageExportService {
  final Logger _logger = getIt<Logger>();

  /// Exports a list of [KafkaMessage]s in the chosen [format].
  ///
  /// For JSON:
  /// - If all messages belong to a single topic, it exports a single .json file.
  /// - If messages come from multiple topics, it groups them and exports a .zip containing one JSON file per topic.
  ///
  /// For CSV:
  /// - Uses visible standard columns and active dynamic projected columns from [columnConfig].
  /// - If all messages belong to a single topic, exports a single RFC 4180 compliant .csv file.
  /// - If messages come from multiple topics, exports a .zip containing one CSV file per topic.
  Future<String?> exportMessages(
    List<KafkaMessage> messages, {
    required String dialogTitle,
    ExportFormat format = ExportFormat.json,
    TableColumnConfig? columnConfig,
    bool isScriptingView = false,
    bool includeHeadersColumn = false,
  }) async {
    if (messages.isEmpty) return null;

    if (format == ExportFormat.csv) {
      return await exportMessagesCsv(
        messages,
        dialogTitle: dialogTitle,
        columnConfig: columnConfig,
        isScriptingView: isScriptingView,
        includeHeadersColumn: includeHeadersColumn,
      );
    }

    try {
      // Group messages by topic
      final Map<String, List<KafkaMessage>> messagesByTopic = {};
      for (final msg in messages) {
        messagesByTopic.putIfAbsent(msg.topic, () => []).add(msg);
      }

      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final ext = format == ExportFormat.ndjson ? 'ndjson' : 'json';
      String serialize(List<KafkaMessage> list) => format == ExportFormat.ndjson
          ? _serializeMessagesNdjson(list)
          : _serializeMessages(list);

      if (messagesByTopic.length == 1) {
        // Single topic export (JSON / NDJSON)
        final topic = messagesByTopic.keys.first;
        final content = serialize(messagesByTopic[topic]!);

        final fileName = '${topic}_$timestampStr.$ext';
        final outputFile = await FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: [ext],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(content);
          _logger.i('Successfully exported messages to $outputFile');
          return outputFile;
        }
        return null;
      } else {
        // Multi-topic export (ZIP)
        final archive = Archive();

        for (final entry in messagesByTopic.entries) {
          final topic = entry.key;
          final topicMessages = entry.value;

          final content = serialize(topicMessages);
          final bytes = utf8.encode(content);

          final archiveFile = ArchiveFile('$topic.$ext', bytes.length, bytes);
          archive.addFile(archiveFile);
        }

        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);

        final fileName = 'messages_export_$timestampStr.zip';
        final outputFile = await FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(zipBytes);
          _logger.i('Successfully exported messages to $outputFile');
          return outputFile;
        }
        return null;
      }
    } catch (e, st) {
      _logger.e('Failed to export messages', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Exports a list of [KafkaMessage]s as RFC 4180 CSV.
  Future<String?> exportMessagesCsv(
    List<KafkaMessage> messages, {
    required String dialogTitle,
    TableColumnConfig? columnConfig,
    bool isScriptingView = false,
    bool includeHeadersColumn = false,
  }) async {
    if (messages.isEmpty) return null;

    try {
      final Map<String, List<KafkaMessage>> messagesByTopic = {};
      for (final msg in messages) {
        messagesByTopic.putIfAbsent(msg.topic, () => []).add(msg);
      }

      final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      if (messagesByTopic.length == 1) {
        final topic = messagesByTopic.keys.first;
        final csvContent = await generateCsvContent(
          messagesByTopic[topic]!,
          columnConfig: columnConfig,
          isScriptingView: isScriptingView,
          includeHeadersColumn: includeHeadersColumn,
        );

        final fileName = '${topic}_$timestampStr.csv';
        final outputFile = await FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['csv'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsString(csvContent);
          _logger.i('Successfully exported CSV to $outputFile');
          return outputFile;
        }
        return null;
      } else {
        final archive = Archive();

        for (final entry in messagesByTopic.entries) {
          final topic = entry.key;
          final topicMessages = entry.value;

          final csvContent = await generateCsvContent(
            topicMessages,
            columnConfig: columnConfig,
            isScriptingView: isScriptingView,
            includeHeadersColumn: includeHeadersColumn,
          );
          final bytes = utf8.encode(csvContent);

          final archiveFile = ArchiveFile('$topic.csv', bytes.length, bytes);
          archive.addFile(archiveFile);
        }

        final zipEncoder = ZipEncoder();
        final zipBytes = zipEncoder.encode(archive);

        final fileName = 'messages_export_$timestampStr.zip';
        final outputFile = await FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (outputFile != null) {
          final file = File(outputFile);
          await file.writeAsBytes(zipBytes);
          _logger.i('Successfully exported CSV archive to $outputFile');
          return outputFile;
        }
        return null;
      }
    } catch (e, st) {
      _logger.e('Failed to export CSV messages', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Generates RFC 4180 CSV string for the given [messages].
  Future<String> generateCsvContent(
    List<KafkaMessage> messages, {
    TableColumnConfig? columnConfig,
    bool isScriptingView = false,
    bool includeHeadersColumn = false,
  }) async {
    final config = columnConfig ?? const TableColumnConfig();
    final projectedCols = config.projectedColumns;

    final standardColIds = isScriptingView
        ? StandardTableColumns.scriptingStandard
        : StandardTableColumns.explorerStandard;

    final activeStandardCols = standardColIds.where(config.isVisible).toList();

    final headers = <String>[];
    for (final colId in activeStandardCols) {
      switch (colId) {
        case StandardTableColumns.timestamp:
          headers.add('Timestamp');
          break;
        case StandardTableColumns.step:
          headers.add('Step');
          break;
        case StandardTableColumns.topic:
          headers.add('Topic');
          break;
        case StandardTableColumns.partition:
          headers.add('Partition');
          break;
        case StandardTableColumns.offset:
          headers.add('Offset');
          break;
        case StandardTableColumns.key:
          headers.add('Key');
          break;
        case StandardTableColumns.content:
          headers.add('Payload');
          break;
        default:
          headers.add(colId);
      }
    }

    for (final col in projectedCols) {
      headers.add(col.label.isNotEmpty ? col.label : col.path);
    }

    // Resolve projected values in batch if any projected columns exist
    final projectedValuesMap = <KafkaMessage, Map<String, String>>{};
    if (projectedCols.isNotEmpty && messages.isNotEmpty) {
      final paths = projectedCols.map((c) => c.path).toList();
      final payloads = messages.map((m) => m.payload ?? '').toList();
      try {
        final batchResults = await resolveJsonPathBatch(
          payloads: payloads,
          paths: paths,
        );
        for (var i = 0; i < messages.length; i++) {
          final rowMap = <String, String>{};
          for (var j = 0; j < paths.length; j++) {
            final val = batchResults[i * paths.length + j];
            if (val != null) {
              rowMap[paths[j]] = val;
            }
          }
          projectedValuesMap[messages[i]] = rowMap;
        }
      } catch (_) {
        // Fallback in test or headless environment
        for (final msg in messages) {
          final rowMap = <String, String>{};
          if (msg.payload != null) {
            try {
              final dynamic decoded = jsonDecode(msg.payload!);
              for (final path in paths) {
                final val = _extractDartJsonPath(decoded, path);
                if (val != null) rowMap[path] = val.toString();
              }
            } catch (_) {}
          }
          projectedValuesMap[msg] = rowMap;
        }
      }
    }

    final rows = <List<Object?>>[
      [...headers, if (includeHeadersColumn) 'Headers'],
    ];
    for (final msg in messages) {
      final row = <Object?>[];
      for (final colId in activeStandardCols) {
        switch (colId) {
          case StandardTableColumns.timestamp:
            row.add(msg.timestamp.toString());
            break;
          case StandardTableColumns.step:
            row.add(msg is ScriptResultMessage ? msg.stepName : 'Global');
            break;
          case StandardTableColumns.topic:
            row.add(msg.topic);
            break;
          case StandardTableColumns.partition:
            row.add(msg.partition);
            break;
          case StandardTableColumns.offset:
            row.add(msg.offset.toString());
            break;
          case StandardTableColumns.key:
            row.add(msg.key);
            break;
          case StandardTableColumns.content:
            row.add(msg.payload);
            break;
          default:
            row.add(null);
        }
      }

      final msgProjected = projectedValuesMap[msg] ?? const {};
      for (final col in projectedCols) {
        row.add(msgProjected[col.path]);
      }
      if (includeHeadersColumn) {
        final headerList = (msg.headers ?? const [])
            .map((h) => {'key': h.key, 'value': h.value})
            .toList();
        row.add(jsonEncode(headerList));
      }
      rows.add(row);
    }

    return rows.map((r) => r.map(_csvField).join(',')).join('\r\n');
  }

  /// Encodes a single CSV field per RFC 4180, keeping `null` unquoted-empty
  /// and `''` as `""` so tombstones and empty strings stay distinct.
  String _csvField(Object? value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.isEmpty) return '""';
    if (str.contains(',') ||
        str.contains('"') ||
        str.contains('\r') ||
        str.contains('\n')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  dynamic _extractDartJsonPath(dynamic data, String path) {
    var cleanPath = path;
    if (cleanPath.startsWith(r'$.')) {
      cleanPath = cleanPath.substring(2);
    } else if (cleanPath.startsWith(r'$')) {
      cleanPath = cleanPath.substring(1);
    }
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1).replaceAll('/', '.');
    }

    final parts = cleanPath.split('.');
    dynamic current = data;
    for (final part in parts) {
      if (current == null) return null;
      if (part.contains('[') && part.contains(']')) {
        final name = part.substring(0, part.indexOf('['));
        final idxStr = part.substring(part.indexOf('[') + 1, part.indexOf(']'));
        final idx = int.tryParse(idxStr);
        if (name.isNotEmpty) {
          if (current is! Map) return null;
          current = current[name];
        }
        if (idx != null && current is List && idx < current.length) {
          current = current[idx];
        } else {
          return null;
        }
      } else if (int.tryParse(part) != null && current is List) {
        final idx = int.parse(part);
        if (idx < current.length) {
          current = current[idx];
        } else {
          return null;
        }
      } else if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  Map<String, dynamic> _messageToJson(KafkaMessage msg) {
    return {
      'topic': msg.topic,
      'partition': msg.partition,
      'offset': msg.offset.toString(),
      'timestamp': msg.timestamp.toString(),
      'timestampIso': timestampIsoFromMillis(msg.timestamp),
      'key': msg.key,
      'payload': msg.payload != null ? _tryParseJson(msg.payload!) : null,
      'headers': (msg.headers ?? const [])
          .map((h) => {'key': h.key, 'value': h.value})
          .toList(),
      'keySchema': messageSchemaToMap(msg.keySchema),
      'valueSchema': messageSchemaToMap(msg.valueSchema),
    };
  }

  String _serializeMessages(List<KafkaMessage> messages) {
    final list = messages.map(_messageToJson).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  String _serializeMessagesNdjson(List<KafkaMessage> messages) {
    if (messages.isEmpty) return '';
    return '${messages.map((m) => jsonEncode(_messageToJson(m))).join('\n')}\n';
  }

  dynamic _tryParseJson(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded == null) return source;
      return decoded;
    } catch (_) {
      return source;
    }
  }
}
