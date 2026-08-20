import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';

import 'package:kafkalyzer/src/features/topic/data/topic_analysis_report_file.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/topic_analysis_export_service.dart';
import 'package:path/path.dart' as p;

class MockFilePicker extends FilePickerPlatform {
  String? savePath;
  bool saveFileCalled = false;
  String? lastFileName;
  FilePickerResult? pickResult;
  bool pickFilesCalled = false;

  @override
  Future<String?> saveFile({
    String? dialogTitle,
    String? fileName,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Uint8List? bytes,
    bool lockParentWindow = false,
  }) async {
    saveFileCalled = true;
    lastFileName = fileName;
    return savePath;
  }

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    pickFilesCalled = true;
    return pickResult;
  }
}

TopicAnalysisReportFile _sampleFile() => TopicAnalysisReportFile(
  exportedAt: DateTime.utc(2026, 8, 19, 12, 34, 56),
  clusterName: 'prod-eu-1',
  report: TopicAnalysisReport(
    topic: 'orders',
    totalMessages: 1000,
    totalBytes: 20480,
    minMessageSize: 1,
    maxMessageSize: 50,
    avgMessageSize: 20.48,
    tombstonesCount: 3,
    isCompacted: true,
    nullKeysCount: 12,
    partitionStats: const [
      PartitionAnalysis(
        partition: 0,
        messageCount: 500,
        byteSize: 10240,
        percentage: 50.0,
        earliestOffset: 0,
        latestOffset: 499,
      ),
    ],
    hourlyDistribution: const [
      HourlyCount(hour: 9, count: 100, percentage: 10.0),
    ],
    topKeys: const [KeyOccurrence(key: 'k1', count: 50, percentage: 5.0)],
    contentTypeDistribution: const [
      TypeOccurrence(typeName: 'json', count: 900, percentage: 90.0),
    ],
    fieldFrequencies: const [
      FieldOccurrence(
        fieldName: 'id',
        count: 900,
        percentage: 90.0,
        topValues: [
          FieldValueOccurrence(value: '1', count: 10, percentage: 1.11),
        ],
      ),
    ],
    scanDurationMs: 12345,
  ),
);

FilePickerResult _pickResultFor(File file) {
  return FilePickerResult([
    PlatformFile(
      path: file.path,
      name: file.path.split('/').last,
      size: file.lengthSync(),
      bytes: file.readAsBytesSync(),
    ),
  ]);
}

void main() {
  final getIt = GetIt.instance;
  late MockFilePicker mockFilePicker;
  late TopicAnalysisExportService service;
  late String tempDir;

  setUp(() {
    getIt.reset();
    getIt.registerSingleton<Logger>(
      Logger(printer: PrettyPrinter(methodCount: 0)),
    );
    mockFilePicker = MockFilePicker();
    FilePickerPlatform.instance = mockFilePicker;
    tempDir = Directory.systemTemp
        .createTempSync('kafkalyzer_analysis_export_test')
        .path;
    service = TopicAnalysisExportService();
  });

  tearDown(() {
    try {
      Directory(tempDir).deleteSync(recursive: true);
    } catch (_) {}
  });

  group('TopicAnalysisExportService', () {
    test('export writes a valid JSON file that can be re-imported', () async {
      final file = _sampleFile();
      final target = p.join(tempDir, 'orders_analysis.json');
      mockFilePicker.savePath = target;

      final written = await service.export(file);

      expect(written, target);
      expect(mockFilePicker.saveFileCalled, isTrue);
      expect(mockFilePicker.lastFileName, startsWith('orders_analysis_'));
      expect(mockFilePicker.lastFileName, endsWith('.json'));
      expect(File(target).existsSync(), isTrue);

      final reimported = TopicAnalysisReportFile.fromJson(
        File(target).readAsStringSync(),
      );
      expect(reimported.toMap(), file.toMap());
    });

    test('export returns null when the user cancels', () async {
      mockFilePicker.savePath = null;

      final written = await service.export(_sampleFile());

      expect(written, isNull);
      expect(mockFilePicker.saveFileCalled, isTrue);
    });

    test('importFile parses a valid file', () async {
      final file = _sampleFile();
      final source = File(p.join(tempDir, 'in.json'))
        ..writeAsStringSync(file.toJson());
      mockFilePicker.pickResult = _pickResultFor(source);

      final imported = await service.importFile();

      expect(mockFilePicker.pickFilesCalled, isTrue);
      expect(imported, isNotNull);
      expect(imported!.toMap(), file.toMap());
    });

    test('importFile returns null when the user cancels', () async {
      mockFilePicker.pickResult = null;

      final imported = await service.importFile();

      expect(imported, isNull);
    });

    test('importFile rejects a file without the expected identifier', () async {
      final source = File(p.join(tempDir, 'bad.json'))
        ..writeAsStringSync(
          '{"kafkalyzer": "nope", "version": 1, "report": {}}',
        );
      mockFilePicker.pickResult = _pickResultFor(source);

      expect(
        service.importFile(),
        throwsA(
          isA<TopicAnalysisImportError>().having(
            (e) => e.kind,
            'kind',
            TopicAnalysisImportErrorKind.notAnAnalysisFile,
          ),
        ),
      );
    });

    test('importFile rejects an unsupported version', () async {
      final source = File(p.join(tempDir, 'v99.json'))
        ..writeAsStringSync(
          '{"kafkalyzer": "topic-analysis-report", "version": 99, "report": {}}',
        );
      mockFilePicker.pickResult = _pickResultFor(source);

      expect(
        service.importFile(),
        throwsA(
          isA<TopicAnalysisImportError>()
              .having(
                (e) => e.kind,
                'kind',
                TopicAnalysisImportErrorKind.unsupportedVersion,
              )
              .having((e) => e.foundVersion, 'foundVersion', 99),
        ),
      );
    });

    test('importFile rejects malformed content', () async {
      final source = File(p.join(tempDir, 'malformed.json'))
        ..writeAsStringSync('this is not json');
      mockFilePicker.pickResult = _pickResultFor(source);

      expect(
        service.importFile(),
        throwsA(
          isA<TopicAnalysisImportError>().having(
            (e) => e.kind,
            'kind',
            TopicAnalysisImportErrorKind.malformed,
          ),
        ),
      );
    });
  });
}
