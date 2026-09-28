import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/utils/json_path_extractor.dart';

void main() {
  group('JsonPathExtractor', () {
    const samplePayload = '''
    {
      "id": 1042,
      "code": "ORD-99",
      "isActive": true,
      "customer": {
        "name": "Acme Corp",
        "address": {
          "city": "Vienna",
          "zip": "1010"
        }
      },
      "items": [
        {
          "sku": "SKU-1",
          "price": 19.99,
          "tags": ["fragile", "express"]
        },
        {
          "sku": "SKU-2",
          "price": 42.0,
          "tags": ["standard"]
        }
      ]
    }
    ''';

    test('extracts top-level primitives from JSON string payload', () {
      expect(JsonPathExtractor.extractFromPayload(samplePayload, 'id'), '1042');
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'code'),
        'ORD-99',
      );
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'isActive'),
        'true',
      );
    });

    test('extracts nested map fields with dot notation', () {
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'customer.name'),
        'Acme Corp',
      );
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'customer.address.city',
        ),
        'Vienna',
      );
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'customer.address.zip',
        ),
        '1010',
      );
    });

    test('extracts array items using bracket notation and dot notation', () {
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'items[0].sku'),
        'SKU-1',
      );
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'items[1].price'),
        '42.0',
      );
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'items[0].tags[1]',
        ),
        'express',
      );
      // dot index notation
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'items.0.sku'),
        'SKU-1',
      );
    });

    test('normalizes paths with leading root. prefix', () {
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'root.customer.name',
        ),
        'Acme Corp',
      );
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'root.items[1].sku',
        ),
        'SKU-2',
      );
    });

    test('returns null for missing keys or out-of-bounds indices', () {
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'nonExistent'),
        isNull,
      );
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'customer.nonExistent',
        ),
        isNull,
      );
      expect(
        JsonPathExtractor.extractFromPayload(samplePayload, 'items[99].sku'),
        isNull,
      );
      expect(
        JsonPathExtractor.extractFromPayload(
          samplePayload,
          'items[-1].sku',
        ),
        isNull,
      );
    });

    test('handles null and malformed payloads gracefully without throwing', () {
      expect(JsonPathExtractor.extractFromPayload(null, 'id'), isNull);
      expect(JsonPathExtractor.extractFromPayload('', 'id'), isNull);
      expect(JsonPathExtractor.extractFromPayload('   ', 'id'), isNull);
      expect(
        JsonPathExtractor.extractFromPayload('not a valid json', 'id'),
        isNull,
      );
      expect(JsonPathExtractor.extractFromPayload('42', 'id'), isNull);
    });

    test('extractRaw returns underlying objects or primitives', () {
      final map = {
        'count': 5,
        'nested': {'flag': false},
        'list': ['a', 'b'],
      };
      expect(JsonPathExtractor.extractRaw(map, 'count'), 5);
      expect(JsonPathExtractor.extractRaw(map, 'nested.flag'), false);
      expect(JsonPathExtractor.extractRaw(map, 'list[1]'), 'b');
      expect(JsonPathExtractor.extractRaw(map, 'nested'), {'flag': false});
    });
  });
}
