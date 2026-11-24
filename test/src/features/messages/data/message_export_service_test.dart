import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/src/features/messages/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/features/messages/data/message_export_service.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/projected_column.dart';
import 'package:kafkalyzer/src/features/messages/presentation/models/table_column_config.dart';
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
      await service.exportMessages([], dialogTitle: 'Export Messages');
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

      await service.exportMessages(messages, dialogTitle: 'Export Messages');

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

      await service.exportMessages(messages, dialogTitle: 'Export Messages');

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

      final result = await service.exportMessages(
        messages,
        dialogTitle: 'Export Messages',
      );

      expect(mockFilePicker.saveFileCalled, isTrue);
      expect(result, isNull);
    });

    test('exportMessages returns saved file path on success', () async {
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

      final targetPath = p.join(tempDir, 'returned_path.json');
      mockFilePicker.savePath = targetPath;

      final result = await service.exportMessages(
        messages,
        dialogTitle: 'Export Messages',
      );

      expect(result, equals(targetPath));
      expect(File(targetPath).existsSync(), isTrue);
    });

    test('exportMessagesCsv returns null when cancelled', () async {
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

      final result = await service.exportMessagesCsv(
        messages,
        dialogTitle: 'Export Messages',
      );

      expect(mockFilePicker.saveFileCalled, isTrue);
      expect(result, isNull);
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
        () => service.exportMessages(messages, dialogTitle: 'Export Messages'),
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

      await service.exportMessages(
        messages,
        dialogTitle: 'Export Messages',
        format: ExportFormat.csv,
      );

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

        await service.exportMessagesCsv(
          messages,
          dialogTitle: 'Export Messages',
          columnConfig: columnConfig,
        );

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

        await service.exportMessagesCsv(
          messages,
          dialogTitle: 'Export Messages',
        );

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

    test('JSON export includes timestampIso, headers, and schemas', () async {
      final messages = [
        const KafkaMessage(
          topic: 'orders',
          partition: 2,
          offset: 42,
          key: 'order-1',
          payload: '{"amount": 99}',
          timestamp: 1700000000000,
          headers: [
            KafkaHeader(key: 'traceId', value: 'abc'),
            KafkaHeader(key: 'traceId', value: 'def'),
          ],
          keySchema: null,
          valueSchema: MessageSchema(
            schemaId: 128,
            subject: 'orders-value',
            version: 4,
          ),
        ),
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 43,
          key: null,
          payload: null,
          timestamp: 0,
          headers: null,
        ),
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 44,
          key: '',
          payload: 'null',
          timestamp: 1700000000000,
        ),
        const KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 45,
          key: '',
          payload: '',
          timestamp: 1700000000000,
        ),
      ];

      final targetPath = p.join(tempDir, 'metadata.json');
      mockFilePicker.savePath = targetPath;

      await service.exportMessages(messages, dialogTitle: 'Export Messages');

      final parsed =
          jsonDecode(File(targetPath).readAsStringSync()) as List<dynamic>;
      expect(parsed.length, 4);

      expect(parsed[0]['topic'], 'orders');
      expect(parsed[0]['partition'], 2);
      expect(parsed[0]['offset'], '42');
      expect(parsed[0]['timestamp'], '1700000000000');
      expect(parsed[0]['timestampIso'], '2023-11-14T22:13:20.000Z');
      expect(parsed[0]['headers'], [
        {'key': 'traceId', 'value': 'abc'},
        {'key': 'traceId', 'value': 'def'},
      ]);
      expect(parsed[0]['keySchema'], isNull);
      expect(parsed[0]['valueSchema'], {
        'schemaId': 128,
        'subject': 'orders-value',
        'version': 4,
      });

      expect(parsed[1]['timestamp'], '0');
      expect(parsed[1]['timestampIso'], isNull);
      expect(parsed[1]['headers'], isEmpty);
      expect(parsed[1]['key'], isNull);
      expect(parsed[1]['payload'], isNull);

      expect(parsed[2]['key'], '');
      expect(parsed[2]['payload'], 'null');

      expect(parsed[3]['key'], '');
      expect(parsed[3]['payload'], '');
    });

    test(
      'NDJSON single topic writes one compact JSON object per line',
      () async {
        final messages = [
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 1,
            key: 'k1',
            payload: '{"a": 1}',
            timestamp: 1700000000000,
          ),
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 2,
            key: null,
            payload: null,
            timestamp: 0,
          ),
        ];

        final targetPath = p.join(tempDir, 'single.ndjson');
        mockFilePicker.savePath = targetPath;

        await service.exportMessages(
          messages,
          dialogTitle: 'Export Messages',
          format: ExportFormat.ndjson,
        );

        expect(mockFilePicker.saveFileCalled, isTrue);
        expect(mockFilePicker.lastFileName, startsWith('orders_'));
        expect(mockFilePicker.lastFileName, endsWith('.ndjson'));

        final content = File(targetPath).readAsStringSync();
        final lines = const LineSplitter().convert(content);
        expect(lines.length, 2);
        final obj0 = jsonDecode(lines[0]) as Map<String, dynamic>;
        final obj1 = jsonDecode(lines[1]) as Map<String, dynamic>;
        expect(obj0['offset'], '1');
        expect(obj0['timestampIso'], '2023-11-14T22:13:20.000Z');
        expect(obj1['offset'], '2');
        expect(obj1['payload'], isNull);
      },
    );

    test(
      'NDJSON multi-topic writes ZIP with <topic>.ndjson in input order',
      () async {
        final messages = [
          const KafkaMessage(
            topic: 'topic-b',
            partition: 0,
            offset: 1,
            key: 'k1',
            payload: 'p1',
            timestamp: 1700000000000,
          ),
          const KafkaMessage(
            topic: 'topic-a',
            partition: 0,
            offset: 2,
            key: 'k2',
            payload: 'p2',
            timestamp: 1700000000001,
          ),
          const KafkaMessage(
            topic: 'topic-b',
            partition: 0,
            offset: 3,
            key: 'k3',
            payload: 'p3',
            timestamp: 1700000000002,
          ),
        ];

        final targetPath = p.join(tempDir, 'multi_ndjson.zip');
        mockFilePicker.savePath = targetPath;

        await service.exportMessages(
          messages,
          dialogTitle: 'Export Messages',
          format: ExportFormat.ndjson,
        );

        expect(mockFilePicker.saveFileCalled, isTrue);
        expect(mockFilePicker.lastFileName, startsWith('messages_export_'));
        expect(mockFilePicker.lastFileName, endsWith('.zip'));

        final bytes = File(targetPath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        expect(archive.map((f) => f.name).toList(), [
          'topic-b.ndjson',
          'topic-a.ndjson',
        ]);

        final bLines = const LineSplitter().convert(
          utf8.decode(archive[0].content as List<int>),
        );
        expect(bLines.length, 2);
        expect((jsonDecode(bLines[0]) as Map<String, dynamic>)['offset'], '1');
        expect((jsonDecode(bLines[1]) as Map<String, dynamic>)['offset'], '3');
      },
    );

    test(
      'CSV distinguishes null key/payload from empty string and quotes lone LF',
      () async {
        final messages = [
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 1,
            key: null,
            payload: null,
            timestamp: 1000,
          ),
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 2,
            key: '',
            payload: '',
            timestamp: 2000,
          ),
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 3,
            key: 'k3',
            payload: 'line1\nline2',
            timestamp: 3000,
          ),
        ];

        final csv = await service.generateCsvContent(messages);
        expect(
          csv,
          'Timestamp,Partition,Offset,Key,Payload\r\n'
          '1000,0,1,,\r\n'
          '2000,0,2,"",""\r\n'
          '3000,0,3,k3,"line1\nline2"',
        );
      },
    );

    test(
      'CSV includeHeadersColumn appends Headers column with JSON array',
      () async {
        final messages = [
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 1,
            key: 'k1',
            payload: 'p1',
            timestamp: 1000,
            headers: [
              KafkaHeader(key: 'h', value: '1'),
              KafkaHeader(key: 'h', value: '2'),
            ],
          ),
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 2,
            key: 'k2',
            payload: 'p2',
            timestamp: 2000,
            headers: null,
          ),
        ];

        final csvDefault = await service.generateCsvContent(messages);
        expect(
          csvDefault.split('\r\n').first,
          'Timestamp,Partition,Offset,Key,Payload',
        );

        final csvWithHeaders = await service.generateCsvContent(
          messages,
          includeHeadersColumn: true,
        );
        final lines = csvWithHeaders.split('\r\n');
        expect(lines[0], 'Timestamp,Partition,Offset,Key,Payload,Headers');
        expect(
          lines[1],
          '1000,0,1,k1,p1,"[{""key"":""h"",""value"":""1""},{""key"":""h"",""value"":""2""}]"',
        );
        expect(lines[2], '2000,0,2,k2,p2,[]');
      },
    );

    test(
      'CSV Step column holds stepName for ScriptResultMessage and Global otherwise',
      () async {
        final messages = [
          const ScriptResultMessage(
            topic: 'orders',
            partition: 0,
            offset: 1,
            key: 'k1',
            payload: 'p1',
            timestamp: 1000,
            stepName: 'Filter Orders',
            stepId: 'step-1',
          ),
          const KafkaMessage(
            topic: 'orders',
            partition: 0,
            offset: 2,
            key: 'k2',
            payload: 'p2',
            timestamp: 2000,
          ),
        ];

        final csv = await service.generateCsvContent(
          messages,
          isScriptingView: true,
        );
        final lines = csv.split('\r\n');
        expect(lines[0], 'Timestamp,Step,Topic,Partition,Offset,Key,Payload');
        expect(lines[1], '1000,Filter Orders,orders,0,1,k1,p1');
        expect(lines[2], '2000,Global,orders,0,2,k2,p2');
      },
    );

    test(
      'localSchemaUseToMap and localSchemaUseFromMap round-trip and handle missing keys',
      () {
        const use = LocalSchemaUseDto(
          fileName: 'orders.avsc',
          format: LocalSchemaFormatDto.avro,
          messageType: 'acme.Order',
          framing: FramingDto.prefixed,
          wireSchemaId: 42,
          error: LocalSchemaErrorDto(
            kind: LocalDecodeErrorKindDto.trailingBytes,
            detail: '2 unread bytes',
          ),
        );
        final map = localSchemaUseToMap(use);
        expect(localSchemaUseFromMap(map), equals(use));
        expect(localSchemaUseFromMap(null), isNull);
        expect(localSchemaUseFromMap({'wrong': 1}), isNull);
      },
    );
  });
}
