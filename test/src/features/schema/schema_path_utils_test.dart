import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/schema/utils/schema_path_utils.dart';

void main() {
  group('normalizeSchemaFieldPath', () {
    test('returns empty string for root and empty path', () {
      expect(normalizeSchemaFieldPath(''), equals(''));
      expect(normalizeSchemaFieldPath('   '), equals(''));
      expect(normalizeSchemaFieldPath('root'), equals(''));
      expect(normalizeSchemaFieldPath('root.'), equals(''));
    });

    test('normalizes top-level primitive field', () {
      expect(normalizeSchemaFieldPath('root.orderId'), equals('orderId'));
      expect(normalizeSchemaFieldPath('orderId'), equals('orderId'));
      expect(normalizeSchemaFieldPath('root.timestamp'), equals('timestamp'));
    });

    test('strips ": Type" from single-level and nested record fields', () {
      expect(
        normalizeSchemaFieldPath('root.customer : Record.id'),
        equals('customer.id'),
      );
      expect(
        normalizeSchemaFieldPath(
          'root.customer : Record.address : AddressRecord.city',
        ),
        equals('customer.address.city'),
      );
      expect(
        normalizeSchemaFieldPath(
          'root.order : OrderRecord.payment : PaymentRecord.amount : double',
        ),
        equals('order.payment.amount'),
      );
    });

    test('preserves array index suffixes while stripping type annotations', () {
      expect(
        normalizeSchemaFieldPath('root.items : Array<Item>[0].name'),
        equals('items[0].name'),
      );
      expect(
        normalizeSchemaFieldPath(
          'root.orders : Array<Order>[2].tags : Array<String>[0]',
        ),
        equals('orders[2].tags[0]'),
      );
    });

    test('handles enums and unions with complex type annotations', () {
      expect(
        normalizeSchemaFieldPath('root.status : Enum (OrderStatus)'),
        equals('status'),
      );
      expect(
        normalizeSchemaFieldPath(
          'root.payload : Union[null, PayloadRecord].id',
        ),
        equals('payload.id'),
      );
    });

    test('returns empty string for schema metadata fields', () {
      expect(normalizeSchemaFieldPath('root._doc'), equals(''));
      expect(
        normalizeSchemaFieldPath('root.customer : Record._doc'),
        equals(''),
      );
      expect(
        normalizeSchemaFieldPath('root.customer : Record._field_doc'),
        equals(''),
      );
      expect(
        normalizeSchemaFieldPath('root.customer : Record.Type'),
        equals(''),
      );
      expect(normalizeSchemaFieldPath('root.status.symbols'), equals(''));
      expect(normalizeSchemaFieldPath('root.doc'), equals('doc')); // not _doc
    });
  });

  group('isSchemaMetadataKey', () {
    test('identifies metadata keys correctly', () {
      expect(isSchemaMetadataKey('_doc'), isTrue);
      expect(isSchemaMetadataKey('_field_doc'), isTrue);
      expect(isSchemaMetadataKey('_type'), isTrue);
      expect(isSchemaMetadataKey('Doc'), isTrue);
      expect(isSchemaMetadataKey('Type'), isTrue);
      expect(isSchemaMetadataKey('Possible Values'), isTrue);
      expect(isSchemaMetadataKey('symbols'), isTrue);
      expect(isSchemaMetadataKey('orderId'), isFalse);
      expect(isSchemaMetadataKey('customer'), isFalse);
    });
  });
}
