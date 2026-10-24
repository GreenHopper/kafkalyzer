import 'package:kafkalyzer/src/features/scripting/domain/extraction_utils.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../rust/api/rust_mocks.mocks.dart';

/// Stub of the shared Rust field-path resolver. The grammar itself is covered
/// by the Rust tests in `rust/kafkalyzer-core/src/json_path.rs`; these tests
/// cover what `ExtractionUtils` decides around that resolver call.
const Map<String, String> resolved = {
  '{"id": 123, "name": "foo"}|name': 'foo',
  '{"user": {"address": {"city": "Berlin"}}}|user.address.city': 'Berlin',
  '{"count": 42}|count': '42',
  '{"count": 1}|count': '1',
  '{"count": 2}|count': '2',
  '{"id": 999}|id': '999',
  '{"items":[{"sku":"A-1"}]}|items[0].sku': 'A-1',
};

void main() {
  const topic = 'test-topic';
  final requestedPaths = <String>[];
  final mockApi = MockKafkalyzerRustLibApi();

  setUpAll(() => KafkalyzerRustLib.initMock(api: mockApi));
  tearDownAll(() => KafkalyzerRustLib.dispose());

  setUp(() {
    requestedPaths.clear();
    reset(mockApi);
    when(
      mockApi.crateApiJsonPathResolveJsonPathBatch(
        payloads: anyNamed('payloads'),
        paths: anyNamed('paths'),
      ),
    ).thenAnswer((invocation) async {
      final payloads = invocation.namedArguments[#payloads] as List<String>;
      final paths = invocation.namedArguments[#paths] as List<String>;
      requestedPaths.addAll(paths);
      return [
        for (final payload in payloads)
          for (final path in paths) resolved['$payload|$path'],
      ];
    });
  });

  group('ExtractionUtils', () {
    KafkaMessage createMessage({required String key, required String payload}) {
      return KafkaMessage(
        topic: topic,
        partition: 0,
        offset: 0,
        timestamp: 0,
        key: key,
        payload: payload,
      );
    }

    test('extracts null if topic does not match', () async {
      final msg = createMessage(key: 'key', payload: 'payload');
      final extraction = ScriptExtraction(
        jsonPath: '',
        variableName: 'var',
        topic: 'other-topic',
      );

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, isNull);
    });

    test('extracts full payload when jsonPath is empty', () async {
      final msg = createMessage(key: 'key', payload: '{"foo": "bar"}');
      final extraction = ScriptExtraction(jsonPath: '', variableName: 'var');

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, '{"foo": "bar"}');
      expect(requestedPaths, isEmpty);
    });

    test(
      'extracts full key when source is key and jsonPath is empty',
      () async {
        final msg = createMessage(key: 'my-key', payload: 'payload');
        final extraction = ScriptExtraction(
          jsonPath: '',
          variableName: 'var',
          source: ScriptExtractionSource.key,
        );

        final result = await ExtractionUtils.extract(extraction, msg);
        expect(result, 'my-key');
      },
    );

    test('extracts simple value from payload JSON', () async {
      final msg = createMessage(
        key: 'key',
        payload: '{"id": 123, "name": "foo"}',
      );
      final extraction = ScriptExtraction(
        jsonPath: 'name',
        variableName: 'var',
      );

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, 'foo');
    });

    test('extracts nested value from payload JSON', () async {
      final msg = createMessage(
        key: 'key',
        payload: '{"user": {"address": {"city": "Berlin"}}}',
      );
      final extraction = ScriptExtraction(
        jsonPath: 'user.address.city',
        variableName: 'var',
      );

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, 'Berlin');
    });

    test('returns null if JSON path does not exist', () async {
      final msg = createMessage(key: 'key', payload: '{"a": 1}');
      final extraction = ScriptExtraction(jsonPath: 'b', variableName: 'var');

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, isNull);
    });

    test('returns null on invalid JSON', () async {
      final msg = createMessage(key: 'key', payload: 'not json');
      final extraction = ScriptExtraction(jsonPath: 'a', variableName: 'var');

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, isNull);
    });

    test('extracts value from key JSON', () async {
      final msg = createMessage(key: '{"id": 999}', payload: 'payload');
      final extraction = ScriptExtraction(
        jsonPath: 'id',
        variableName: 'var',
        source: ScriptExtractionSource.key,
      );

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, '999');
    });

    test('extracts integer value as string', () async {
      final msg = createMessage(key: 'key', payload: '{"count": 42}');
      final extraction = ScriptExtraction(
        jsonPath: 'count',
        variableName: 'var',
      );

      final result = await ExtractionUtils.extract(extraction, msg);
      expect(result, '42');
    });

    test('sends bracket paths to the resolver exactly as configured', () async {
      final msg = createMessage(
        key: 'key',
        payload: '{"items":[{"sku":"A-1"}]}',
      );
      final extraction = ScriptExtraction(
        jsonPath: 'items[0].sku',
        variableName: 'var',
      );

      final result = await ExtractionUtils.extract(extraction, msg);

      // A projected column configured with the same path reaches the same
      // resolver with the same string, which is what makes both agree.
      expect(requestedPaths, ['items[0].sku']);
      expect(result, 'A-1');
    });

    test('extractAll resolves a whole batch in one resolver call', () async {
      final messages = [
        createMessage(key: 'k1', payload: '{"count": 1}'),
        createMessage(key: 'k2', payload: '{"count": 2}'),
      ];
      final extraction = ScriptExtraction(
        jsonPath: 'count',
        variableName: 'var',
      );

      final values = await ExtractionUtils.extractAll(extraction, messages);

      expect(values, ['1', '2']);
      expect(requestedPaths, ['count']);
    });
  });
}
