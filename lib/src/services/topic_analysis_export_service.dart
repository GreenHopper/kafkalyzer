import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';

/// Handles the file dialog + read/write behind the topic analysis
/// export/import feature. Serialization and validation live in
/// [TopicAnalysisReportFile]; this service only orchestrates the I/O.
class TopicAnalysisExportService {
  final Logger _logger = getIt.isRegistered<Logger>()
      ? getIt<Logger>()
      : Logger();

  /// Exports [file] to a `.json` file.
  ///
  /// Returns the path of the written file, or `null` if the user cancelled the
  /// save dialog. Throws if the file cannot be written.
  Future<String?> export(TopicAnalysisReportFile file) async {
    final timestampStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName =
        '${_sanitizeFileName(file.report.topic)}_analysis_$timestampStr.json';

    final outputFile = await FilePicker.saveFile(
      dialogTitle: 'Export Topic Analysis',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (outputFile == null) return null; // user cancelled

    try {
      await File(outputFile).writeAsString(file.toJson());
    } catch (e, st) {
      _logger.e(
        'Failed to write analysis report to $outputFile',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }

    _logger.i('Exported topic analysis report to $outputFile');
    return outputFile;
  }

  /// Prompts the user to pick an analysis report file and parses it.
  ///
  /// Returns the parsed [TopicAnalysisReportFile], or `null` if the user
  /// cancelled the picker. Throws a [TopicAnalysisImportError] if the chosen
  /// file is not a valid, supported analysis report.
  Future<TopicAnalysisReportFile?> importFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import Topic Analysis',
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return null; // user cancelled

    final picked = result.files.single;
    final List<int>? bytes =
        picked.bytes ??
        (picked.path != null ? File(picked.path!).readAsBytesSync() : null);
    if (bytes == null) {
      throw const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.malformed,
        detail: 'could not read file',
      );
    }

    final String content;
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      throw const TopicAnalysisImportError(
        TopicAnalysisImportErrorKind.malformed,
        detail: 'not valid text',
      );
    }

    return TopicAnalysisReportFile.fromJson(content);
  }

  String _sanitizeFileName(String name) =>
      name.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}
