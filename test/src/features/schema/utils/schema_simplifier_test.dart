import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_simplifier.dart';

void main() {
  group('simplifyAvroSchema', () {
    test('passes through non-map inputs unchanged', () {
      expect(simplifyAvroSchema('string'), equals('string'));
      expect(simplifyAvroSchema(42), equals(42));
      expect(simplifyAvroSchema(null), isNull);
      expect(
        simplifyAvroSchema(['null', 'string']),
        equals(['null', 'string']),
      );
    });

    test('simplifies a record with documented primitives', () {
      final result = simplifyAvroSchema({
        'type': 'record',
        'name': 'Order',
        'doc': 'An order',
        'fields': [
          {'name': 'id', 'type': 'string', 'doc': 'order id'},
          {'name': 'amount', 'type': 'double'},
        ],
      });

      expect(result, isA<Map<String, dynamic>>());
      final map = result as Map<String, dynamic>;
      expect(map['_doc'], equals('An order'));
      expect(map['id'], equals('string (Doc: order id)'));
      expect(map['amount'], equals('double'));
    });

    test('resolves optional unions and nested array items', () {
      final result = simplifyAvroSchema({
        'type': 'record',
        'name': 'Wrapper',
        'fields': [
          {
            'name': 'items',
            'type': {
              'type': 'array',
              'items': {
                'type': 'record',
                'name': 'Item',
                'fields': [
                  {'name': 'sku', 'type': 'string'},
                ],
              },
            },
            'doc': 'line items',
          },
          {
            'name': 'note',
            // JSON-decoded schemas are List<dynamic>, not List<String>.
            'type': <dynamic>['null', 'string'],
            'doc': 'optional note',
          },
        ],
      });

      final map = result as Map<String, dynamic>;
      expect(map.containsKey('items : Array<Item>'), isTrue);
      final items = map['items : Array<Item>'] as Map<String, dynamic>;
      expect(items['sku'], equals('string'));
      expect(items['_doc'], equals('line items'));
      expect(map['note'], equals('string (Optional) (Doc: optional note)'));
    });

    test('parses possible values from field documentation', () {
      final result = simplifyAvroSchema({
        'type': 'record',
        'name': 'StatusHolder',
        'fields': [
          {
            'name': 'status',
            'type': 'string',
            'doc': 'Possible values: OPEN, CLOSED, PENDING',
          },
        ],
      });

      final map = result as Map<String, dynamic>;
      final status = map['status'] as Map<String, dynamic>;
      expect(status['Type'], equals('string'));
      expect(status['Possible Values'], equals(['OPEN', 'CLOSED', 'PENDING']));
    });

    test('simplifies enum schemas', () {
      final result = simplifyAvroSchema({
        'type': 'enum',
        'name': 'Color',
        'symbols': ['RED', 'GREEN'],
        'doc': 'a color',
      });

      expect(
        result,
        equals({
          '_type': 'Enum',
          'symbols': ['RED', 'GREEN'],
          '_doc': 'a color',
        }),
      );
    });

    test('unwraps top-level array schemas to their item type', () {
      final result = simplifyAvroSchema({
        'type': 'array',
        'items': {
          'type': 'record',
          'name': 'Row',
          'fields': [
            {'name': 'n', 'type': 'long'},
          ],
        },
      });

      expect(result, equals({'n': 'long'}));
    });
  });
}
