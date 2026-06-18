import 'package:kafkalyzer/src/features/scripting/domain/extraction_utils.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExtractionUtils', () {
    const topic = 'test-topic';

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

    test('extracts null if topic does not match', () {
      final msg = createMessage(key: 'key', payload: 'payload');
      final extraction = ScriptExtraction(
        jsonPath: '',
        variableName: 'var',
        topic: 'other-topic',
      );

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, isNull);
    });

    test('extracts full payload when jsonPath is empty', () {
      final msg = createMessage(key: 'key', payload: '{"foo": "bar"}');
      final extraction = ScriptExtraction(jsonPath: '', variableName: 'var');

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, '{"foo": "bar"}');
    });

    test('extracts full key when source is key and jsonPath is empty', () {
      final msg = createMessage(key: 'my-key', payload: 'payload');
      final extraction = ScriptExtraction(
        jsonPath: '',
        variableName: 'var',
        source: ScriptExtractionSource.key,
      );

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, 'my-key');
    });

    test('extracts simple value from payload JSON', () {
      final msg = createMessage(
        key: 'key',
        payload: '{"id": 123, "name": "foo"}',
      );
      final extraction = ScriptExtraction(
        jsonPath: 'name',
        variableName: 'var',
      );

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, 'foo');
    });

    test('extracts nested value from payload JSON', () {
      final msg = createMessage(
        key: 'key',
        payload: '{"user": {"address": {"city": "Berlin"}}}',
      );
      final extraction = ScriptExtraction(
        jsonPath: 'user.address.city',
        variableName: 'var',
      );

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, 'Berlin');
    });

    test('returns null if JSON path does not exist', () {
      final msg = createMessage(key: 'key', payload: '{"a": 1}');
      final extraction = ScriptExtraction(jsonPath: 'b', variableName: 'var');

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, isNull);
    });

    test('returns null on invalid JSON', () {
      final msg = createMessage(key: 'key', payload: 'not json');
      final extraction = ScriptExtraction(jsonPath: 'a', variableName: 'var');

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, isNull);
    });

    test('extracts value from key JSON', () {
      final msg = createMessage(key: '{"id": 999}', payload: 'payload');
      final extraction = ScriptExtraction(
        jsonPath: 'id',
        variableName: 'var',
        source: ScriptExtractionSource.key,
      );

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, '999');
    });

    test('extracts integer value as string', () {
      final msg = createMessage(key: 'key', payload: '{"count": 42}');
      final extraction = ScriptExtraction(
        jsonPath: 'count',
        variableName: 'var',
      );

      final result = ExtractionUtils.extract(extraction, msg);
      expect(result, '42');
    });
  });
}
