import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/services/message_export_service.dart';
import 'package:kafkalyzer/src/ui/messages/models/projected_column.dart';
import 'package:kafkalyzer/src/ui/messages/models/table_column_config.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;

class MockFilePicker extends FilePickerPlatform {
  String? savePath;
  bool saveFileCalled = false;
  String? lastFileName;

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
}

void main() {
  final getIt = GetIt.instance;
  late MockFilePicker mockFilePicker;
  late MessageExportService service;
  late String tempDir;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<Logger>(
      Logger(printer: PrettyPrinter(methodCount: 0)),
    );

    mockFilePicker = MockFilePicker();
    FilePickerPlatform.instance = mockFilePicker;

    tempDir = Directory.systemTemp
        .createTempSync('kafkalyzer_export_test')
        .path;
    service = MessageExportService();
  });

  tearDown(() {
    try {
      Directory(tempDir).deleteSync(recursive: true);
    } catch (_) {}
  });

  group('MessageExportService', () {
    test('exportMessages does nothing when messages is empty', () async {
      await service.exportMessages([]);
      expect(mockFilePicker.saveFileCalled, isFalse);
    });

    test('exportMessages single topic exports JSON file', () async {
      final messages = [
        const KafkaMessage(
          topic: 'topic-a',
          partition: 0,
          offset: 100,
          key: 'my-key',
          payload: '{"hello": "world"}',
          timestamp: 123456789,
        ),
        const KafkaMessage(
          topic: 'topic-a',
          partition: 1,
          offset: 101,
          key: null,
          payload: 'plain text payload',
          timestamp: 123456790,
        ),
      ];

      final targetPath = p.join(tempDir, 'export.json');
      mockFilePicker.savePath = targetPath;

      await service.exportMessages(messages);

      expect(mockFilePicker.saveFileCalled, isTrue);
      expect(mockFilePicker.lastFileName, startsWith('topic-a_'));
      expect(mockFilePicker.lastFileName, endsWith('.json'));

      final exportedFile = File(targetPath);
      expect(exportedFile.existsSync(), isTrue);

      final fileContent = exportedFile.readAsStringSync();
      final parsedJson = jsonDecode(fileContent) as List<dynamic>;

      expect(parsedJson.length, 2);
      expect(parsedJson[0]['topic'], 'topic-a');
      expect(parsedJson[0]['partition'], 0);
      expect(parsedJson[0]['offset'], '100');
      expect(parsedJson[0]['key'], 'my-key');
      expect(parsedJson[0]['payload'], {'hello': 'world'});
      expect(parsedJson[0]['timestamp'], '123456789');

      expect(parsedJson[1]['topic'], 'topic-a');
      expect(parsedJson[1]['partition'], 1);
      expect(parsedJson[1]['offset'], '101');
      expect(parsedJson[1]['key'], isNull);
      expect(parsedJson[1]['payload'], 'plain text payload');
      expect(parsedJson[1]['timestamp'], '123456790');
    });

    test('exportMessages multiple topics exports ZIP archive', () async {
      final messages = [
        const KafkaMessage(
          topic: 'topic-a',
          partition: 0,
          offset: 100,
          key: 'key-a',
          payload: 'payload-a',
          timestamp: 123456789,
        ),
        const KafkaMessage(
          topic: 'topic-b',
          partition: 0,
          offset: 200,
          key: 'key-b',
          payload: 'payload-b',
          timestamp: 123456790,
        ),
      ];

      final targetPath = p.join(tempDir, 'export.zip');
      mockFilePicker.savePath = targetPath;

      await service.exportMessages(messages);

      expect(mockFilePicker.saveFileCalled, isTrue);
      expect(mockFilePicker.lastFileName, startsWith('messages_export_'));
      expect(mockFilePicker.lastFileName, endsWith('.zip'));

      final exportedFile = File(targetPath);
      expect(exportedFile.existsSync(), isTrue);

      final bytes = exportedFile.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      expect(archive.length, 2);

      final fileNames = archive.map((f) => f.name).toList();
      expect(fileNames, containsAll(['topic-a.json', 'topic-b.json']));

      final topicAFile = archive.firstWhere((f) => f.name == 'topic-a.json');
      final topicAContent = utf8.decode(topicAFile.content as List<int>);
      final topicAJson = jsonDecode(topicAContent) as List<dynamic>;
      expect(topicAJson.length, 1);
      expect(topicAJson[0]['topic'], 'topic-a');
      expect(topicAJson[0]['payload'], 'payload-a');

      final topicBFile = archive.firstWhere((f) => f.name == 'topic-b.json');
      final topicBContent = utf8.decode(topicBFile.content as List<int>);
      final topicBJson = jsonDecode(topicBContent) as List<dynamic>;
      expect(topicBJson.length, 1);
      expect(topicBJson[0]['topic'], 'topic-b');
      expect(topicBJson[0]['payload'], 'payload-b');
    });

    test('exportMessages handles file picker cancel', () async {
      final messages = [
        const KafkaMessage(
          topic: 'topic-a',
          partition: 0,
          offset: 100,
          key: 'key',
          payload: 'payload',
          timestamp: 12345,
        ),
      ];

      mockFilePicker.savePath = null;

      await service.exportMessages(messages);

      expect(mockFilePicker.saveFileCalled, isTrue);
      // No file should be created or written since output file was null
    });

    test('exportMessages propagates exceptions', () async {
      final messages = [
        const KafkaMessage(
          topic: 'topic-a',
          partition: 0,
          offset: 100,
          key: 'key',
          payload: 'payload',
          timestamp: 12345,
        ),
      ];

      // Cause a failure by setting an invalid directory/file path that fails writing
      mockFilePicker.savePath = p.join(
        tempDir,
        'nonexistent_directory_123',
        'file.json',
      );

      expect(
        () => service.exportMessages(messages),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('exportMessagesCsv single topic exports RFC 4180 CSV file', () async {
      final messages = [
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 100,
          key: 'key-1,with,comma',
          payload:
              '{"id": 1, "note": "hello\nworld", "quote": "He said \\"hi\\""}',
          timestamp: 123456789,
        ),
        const KafkaMessage(
          topic: 'orders',
          partition: 1,
          offset: 101,
          key: null,
          payload: '{"id": 2}',
          timestamp: 123456790,
        ),
      ];

      final targetPath = p.join(tempDir, 'orders.csv');
      mockFilePicker.savePath = targetPath;

      await service.exportMessages(messages, format: ExportFormat.csv);

      expect(mockFilePicker.saveFileCalled, isTrue);
      expect(mockFilePicker.lastFileName, startsWith('orders_'));
      expect(mockFilePicker.lastFileName, endsWith('.csv'));

      final exportedFile = File(targetPath);
      expect(exportedFile.existsSync(), isTrue);

      final content = exportedFile.readAsStringSync();
      expect(content, contains('Timestamp,Partition,Offset,Key,Payload'));
      // Check RFC 4180 quoting
      expect(content, contains('"key-1,with,comma"'));
    });

    test(
      'exportMessagesCsv includes dynamic projected columns and respects hidden columns',
      () async {
        final messages = [
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 100,
            key: 'key-1',
            payload: '{"customer": {"id": "CUST-99"}, "amount": 42.5}',
            timestamp: 123456789,
          ),
          const KafkaMessage(
            topic: 'orders',
            partition: 1,
            offset: 101,
            key: 'key-2',
            payload: '{"other": "value"}', // missing customer.id
            timestamp: 123456790,
          ),
        ];

        final targetPath = p.join(tempDir, 'projected.csv');
        mockFilePicker.savePath = targetPath;

        final columnConfig = TableColumnConfig(
          hiddenColumns: {
            StandardTableColumns.timestamp,
            StandardTableColumns.content,
          },
          projectedColumns: const [
            ProjectedColumn(path: 'customer.id', label: 'CustomerID'),
            ProjectedColumn(path: 'amount', label: 'OrderAmount'),
          ],
        );

        await service.exportMessagesCsv(messages, columnConfig: columnConfig);

        final exportedFile = File(targetPath);
        expect(exportedFile.existsSync(), isTrue);

        final content = exportedFile.readAsStringSync();
        // Timestamp and Payload are hidden, so they must not be in the header
        expect(content, isNot(contains('Timestamp')));
        expect(content, isNot(contains('Payload')));
        expect(
          content,
          contains('Partition,Offset,Key,CustomerID,OrderAmount'),
        );

        // Check row with customer.id
        expect(content, contains('0,100,key-1,CUST-99,42.5'));
        // Check row with missing customer.id and amount rendered as empty string
        expect(content, contains('1,101,key-2,,'));
      },
    );

    test(
      'exportMessagesCsv multiple topics bundles into ZIP archive',
      () async {
        final messages = [
          const KafkaMessage(
            topic: 'topic-1',
            partition: 0,
            offset: 100,
            key: 'k1',
            payload: 'p1',
            timestamp: 1000,
          ),
          const KafkaMessage(
            topic: 'topic-2',
            partition: 0,
            offset: 200,
            key: 'k2',
            payload: 'p2',
            timestamp: 2000,
          ),
        ];

        final targetPath = p.join(tempDir, 'export_csv.zip');
        mockFilePicker.savePath = targetPath;

        await service.exportMessagesCsv(messages);

        expect(mockFilePicker.saveFileCalled, isTrue);
        expect(mockFilePicker.lastFileName, startsWith('messages_export_'));
        expect(mockFilePicker.lastFileName, endsWith('.zip'));

        final exportedFile = File(targetPath);
        expect(exportedFile.existsSync(), isTrue);

        final bytes = exportedFile.readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        final fileNames = archive.map((f) => f.name).toList();
        expect(fileNames, containsAll(['topic-1.csv', 'topic-2.csv']));
      },
    );
  });
}
