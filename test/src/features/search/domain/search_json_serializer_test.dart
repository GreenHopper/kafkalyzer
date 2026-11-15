import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/search/domain/search_json_serializer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';

void main() {
  group('SearchJsonSerializer', () {
    test(
      'serializeMessage and deserializeMessage round-trip headers, schemas, and timestampIso',
      () {
        const message = KafkaMessage(
          topic: 'orders',
          partition: 1,
          offset: 42,
          key: 'k1',
          payload: '{"ok":true}',
          timestamp: 1700000000000,
          headers: [
            KafkaHeader(key: 'traceId', value: 'abc'),
            KafkaHeader(key: 'traceId', value: 'def'),
          ],
          keySchema: MessageSchema(
            schemaId: 11,
            subject: 'orders-key',
            version: 1,
          ),
          valueSchema: MessageSchema(
            schemaId: 128,
            subject: 'orders-value',
            version: 4,
          ),
        );

        final serialized = SearchJsonSerializer.serializeMessage(message);
        expect(serialized['offset'], 42);
        expect(serialized['timestamp'], 1700000000000);
        expect(serialized['timestampIso'], '2023-11-14T22:13:20.000Z');
        expect(serialized['headers'], [
          {'key': 'traceId', 'value': 'abc'},
          {'key': 'traceId', 'value': 'def'},
        ]);
        expect(serialized['keySchema'], {
          'schemaId': 11,
          'subject': 'orders-key',
          'version': 1,
        });
        expect(serialized['valueSchema'], {
          'schemaId': 128,
          'subject': 'orders-value',
          'version': 4,
        });

        final decoded =
            jsonDecode(jsonEncode(serialized)) as Map<String, dynamic>;
        final restored = SearchJsonSerializer.deserializeMessage(decoded);
        expect(restored.topic, 'orders');
        expect(restored.partition, 1);
        expect(restored.offset, 42);
        expect(restored.key, 'k1');
        expect(restored.payload, '{"ok":true}');
        expect(restored.timestamp, 1700000000000);
        expect(restored.headers, [
          const KafkaHeader(key: 'traceId', value: 'abc'),
          const KafkaHeader(key: 'traceId', value: 'def'),
        ]);
        expect(
          restored.keySchema,
          const MessageSchema(schemaId: 11, subject: 'orders-key', version: 1),
        );
        expect(
          restored.valueSchema,
          const MessageSchema(
            schemaId: 128,
            subject: 'orders-value',
            version: 4,
          ),
        );
      },
    );

    test('deserializeMessage handles legacy maps without new keys', () {
      final legacy = <String, dynamic>{
        'topic': 'orders',
        'partition': 0,
        'offset': 10,
        'key': 'k',
        'payload': 'p',
        'timestamp': 1000,
      };

      final restored = SearchJsonSerializer.deserializeMessage(legacy);
      expect(restored.topic, 'orders');
      expect(restored.offset, 10);
      expect(restored.headers, isNull);
      expect(restored.keySchema, isNull);
      expect(restored.valueSchema, isNull);
    });

    test('deserializeMessage ignores wrongly typed headers and schemas', () {
      final malformed = <String, dynamic>{
        'topic': 'orders',
        'partition': 0,
        'offset': 10,
        'key': null,
        'payload': null,
        'timestamp': 0,
        'headers': 'not-a-list',
        'keySchema': 'not-a-map',
        'valueSchema': {'subject': 'missing-id'},
      };

      final restored = SearchJsonSerializer.deserializeMessage(malformed);
      expect(restored.headers, isNull);
      expect(restored.keySchema, isNull);
      expect(restored.valueSchema, isNull);
      expect(restored.keyLocalSchema, isNull);
      expect(restored.valueLocalSchema, isNull);
    });

    test(
      'round-trips keyLocalSchema and valueLocalSchema and loads old files without them',
      () {
        const msg = KafkaMessage(
          topic: 'orders',
          partition: 0,
          offset: 7,
          key: 'k',
          payload: '{"id":"1"}',
          timestamp: 1000,
          keyLocalSchema: LocalSchemaUseDto(
            fileName: 'key.avsc',
            format: LocalSchemaFormatDto.avro,
            framing: FramingDto.raw,
          ),
          valueLocalSchema: LocalSchemaUseDto(
            fileName: 'val.desc',
            format: LocalSchemaFormatDto.protobufDescriptor,
            messageType: 'acme.Order',
            framing: FramingDto.prefixed,
            wireSchemaId: 42,
          ),
        );
        final encoded =
            jsonDecode(jsonEncode(SearchJsonSerializer.serializeMessage(msg)))
                as Map<String, dynamic>;
        final restored = SearchJsonSerializer.deserializeMessage(encoded);
        expect(restored.keyLocalSchema, equals(msg.keyLocalSchema));
        expect(restored.valueLocalSchema, equals(msg.valueLocalSchema));

        final legacy = <String, dynamic>{
          'topic': 'orders',
          'partition': 0,
          'offset': 1,
          'timestamp': 1000,
        };
        final legacyRestored = SearchJsonSerializer.deserializeMessage(legacy);
        expect(legacyRestored.keyLocalSchema, isNull);
        expect(legacyRestored.valueLocalSchema, isNull);
      },
    );
  });
}
