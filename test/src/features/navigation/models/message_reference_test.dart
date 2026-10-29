import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/navigation/models/message_reference.dart';

void main() {
  group('MessageReference', () {
    test('serializes to uri with all components', () {
      const ref = MessageReference(
        cluster: 'prod-kafka',
        topic: 'orders-dlq',
        partition: 3,
        offset: 1042,
        filter: 'failed',
      );

      final uri = ref.toUri();
      expect(uri.scheme, equals('kafkalyzer'));
      expect(uri.host, equals('open'));
      expect(uri.queryParameters['cluster'], equals('prod-kafka'));
      expect(uri.queryParameters['topic'], equals('orders-dlq'));
      expect(uri.queryParameters['partition'], equals('3'));
      expect(uri.queryParameters['offset'], equals('1042'));
      expect(uri.queryParameters['filter'], equals('failed'));
    });

    test('serializes minimal reference with topic only', () {
      const ref = MessageReference(topic: 'payments');
      final uriStr = ref.toString();
      expect(uriStr, equals('kafkalyzer://open?topic=payments'));
    });

    test('parses valid uri string into MessageReference', () {
      const uriStr =
          'kafkalyzer://open?cluster=staging&topic=events&partition=1&offset=500&filter=error';
      final ref = MessageReference.tryParse(uriStr);

      expect(ref, isNotNull);
      expect(ref!.cluster, equals('staging'));
      expect(ref.topic, equals('events'));
      expect(ref.partition, equals(1));
      expect(ref.offset, equals(500));
      expect(ref.filter, equals('error'));
    });

    test('returns null for invalid scheme or missing topic', () {
      expect(MessageReference.tryParse('https://example.com'), isNull);
      expect(MessageReference.tryParse('kafkalyzer://open'), isNull);
      expect(
        MessageReference.tryParse('kafkalyzer://open?cluster=prod'),
        isNull,
      );
      expect(MessageReference.tryParse('not a uri'), isNull);
      expect(MessageReference.tryParse(''), isNull);
    });

    test('equality and hashCode support', () {
      const ref1 = MessageReference(
        cluster: 'prod',
        topic: 'logs',
        partition: 0,
        offset: 10,
      );
      const ref2 = MessageReference(
        cluster: 'prod',
        topic: 'logs',
        partition: 0,
        offset: 10,
      );
      const ref3 = MessageReference(
        cluster: 'staging',
        topic: 'logs',
        partition: 0,
        offset: 10,
      );

      expect(ref1, equals(ref2));
      expect(ref1.hashCode, equals(ref2.hashCode));
      expect(ref1, isNot(equals(ref3)));
    });
  });
}
