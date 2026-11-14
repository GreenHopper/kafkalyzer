import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

void main() {
  group('DlqTopicDetector', () {
    test('identifies DLQ topics with standard suffixes and casing', () {
      expect(DlqTopicDetector.isDlqTopic('orders-dlq'), isTrue);
      expect(DlqTopicDetector.isDlqTopic('orders.DLQ'), isTrue);
      expect(DlqTopicDetector.isDlqTopic('payments_dlq'), isTrue);
      expect(DlqTopicDetector.isDlqTopic('events-dlt'), isTrue);
      expect(DlqTopicDetector.isDlqTopic('notifications.deadletter'), isTrue);
      expect(DlqTopicDetector.isDlqTopic('transactions-error'), isTrue);

      expect(DlqTopicDetector.isDlqTopic('orders'), isFalse);
      expect(DlqTopicDetector.isDlqTopic('dlq-processor'), isFalse);
    });

    test(
      'identifies retry topics with standard suffixes and progression numbers',
      () {
        expect(DlqTopicDetector.isRetryTopic('orders-retry'), isTrue);
        expect(DlqTopicDetector.isRetryTopic('orders.retry'), isTrue);
        expect(DlqTopicDetector.isRetryTopic('orders-retry-0'), isTrue);
        expect(DlqTopicDetector.isRetryTopic('orders-retry-1'), isTrue);
        expect(DlqTopicDetector.isRetryTopic('payments_retry_2'), isTrue);

        expect(DlqTopicDetector.isRetryTopic('orders'), isFalse);
        expect(DlqTopicDetector.isRetryTopic('retry-handler'), isFalse);
      },
    );

    test('resolves base topic correctly', () {
      expect(DlqTopicDetector.resolveBaseTopic('orders-dlq'), equals('orders'));
      expect(DlqTopicDetector.resolveBaseTopic('orders.DLQ'), equals('orders'));
      expect(
        DlqTopicDetector.resolveBaseTopic('orders-retry-1'),
        equals('orders'),
      );
      expect(
        DlqTopicDetector.resolveBaseTopic('orders-retry'),
        equals('orders'),
      );
      expect(DlqTopicDetector.resolveBaseTopic('orders'), equals('orders'));
    });

    test('groups failure topics by base topic', () {
      final topics = [
        'orders',
        'orders-retry-0',
        'orders-retry-1',
        'orders-dlq',
        'customers',
        'customers-dlq',
        'inventory',
      ];

      final grouped = DlqTopicDetector.groupFailureTopicsByBase(topics);
      expect(
        grouped['orders'],
        containsAll(['orders-retry-0', 'orders-retry-1', 'orders-dlq']),
      );
      expect(grouped['customers'], equals(['customers-dlq']));
      expect(grouped.containsKey('inventory'), isFalse);
    });
  });

  group('DlqFailureMetadata', () {
    test('extracts standard and spring failure headers', () {
      final headers = {
        'x-original-topic': 'orders',
        'x-original-partition': '2',
        'x-original-offset': '1042',
        'x-exception-message': 'JsonParseException: Unexpected character',
        'x-exception-class': 'com.fasterxml.jackson.core.JsonParseException',
        'x-exception-stacktrace':
            'at com.example.Consumer.process(Consumer.java:42)',
      };

      final meta = DlqFailureMetadata.fromHeaders(headers);
      expect(meta, isNotNull);
      expect(meta!.originalTopic, equals('orders'));
      expect(meta.originalPartition, equals(2));
      expect(meta.originalOffset, equals(1042));
      expect(meta.exceptionMessage, contains('JsonParseException'));
      expect(meta.exceptionClass, contains('JsonParseException'));
      expect(meta.exceptionStacktrace, contains('Consumer.java:42'));
      expect(meta.hasCoordinates, isTrue);
      expect(meta.hasException, isTrue);
    });

    test('extracts spring kafka_dlt headers', () {
      final headers = {
        'kafka_dlt-original-topic': 'payments',
        'kafka_dlt-original-partition': '0',
        'kafka_dlt-original-offset': '99',
        'kafka_dlt-exception-message': 'TimeoutException',
        'kafka_dlt-exception-fqcn': 'java.util.concurrent.TimeoutException',
      };

      final meta = DlqFailureMetadata.fromHeaders(headers);
      expect(meta, isNotNull);
      expect(meta!.originalTopic, equals('payments'));
      expect(meta.originalPartition, equals(0));
      expect(meta.originalOffset, equals(99));
      expect(meta.exceptionMessage, equals('TimeoutException'));
      expect(
        meta.exceptionClass,
        equals('java.util.concurrent.TimeoutException'),
      );
    });

    test('returns null when no failure headers are present', () {
      final headers = {'content-type': 'application/json', 'traceId': 'abc'};
      final meta = DlqFailureMetadata.fromHeaders(headers);
      expect(meta, isNull);
    });

    test(
      'toFailureReport includes full metadata, dlqMessage, original, and exception',
      () {
        const meta = DlqFailureMetadata(
          originalTopic: 'orders',
          originalPartition: 0,
          originalOffset: 123,
          exceptionMessage: 'Boom',
          exceptionClass: 'java.lang.IllegalStateException',
        );
        final msg = KafkaMessage(
          topic: 'orders-dlq',
          partition: 1,
          offset: 42,
          timestamp: 1700000000000,
          key: 'order-1',
          payload: '{"id": 1}',
          headers: const [
            KafkaHeader(key: 'x-exception-message', value: 'Boom'),
          ],
        );

        final report = meta.toFailureReport(msg);
        expect(report['dlqMessage'], {
          'topic': 'orders-dlq',
          'partition': 1,
          'offset': 42,
          'timestamp': 1700000000000,
          'key': 'order-1',
          'value': '{"id": 1}',
          'headers': {'x-exception-message': 'Boom'},
        });
        expect(report['original'], {
          'topic': 'orders',
          'partition': 0,
          'offset': 123,
        });
        expect(report['exception'], {
          'message': 'Boom',
          'class': 'java.lang.IllegalStateException',
        });
      },
    );

    test('toFailureReport omits original and exception when absent', () {
      const meta = DlqFailureMetadata();
      final msg = KafkaMessage(
        topic: 'orders-dlq',
        partition: 0,
        offset: 1,
        timestamp: 1700000000000,
      );

      final report = meta.toFailureReport(msg);
      expect(report.containsKey('original'), isFalse);
      expect(report.containsKey('exception'), isFalse);
    });

    test(
      'toFailureReport distinguishes null key vs empty key and null value tombstone',
      () {
        const meta = DlqFailureMetadata(
          originalTopic: 'orders',
          originalPartition: 0,
          originalOffset: 10,
        );
        final nullKeyTombstone = KafkaMessage(
          topic: 'orders-dlq',
          partition: 0,
          offset: 2,
          timestamp: 1700000000000,
          key: null,
          payload: null,
        );
        final emptyKeyMsg = KafkaMessage(
          topic: 'orders-dlq',
          partition: 0,
          offset: 3,
          timestamp: 1700000000000,
          key: '',
          payload: '',
        );

        final r1 = meta.toFailureReport(nullKeyTombstone);
        final d1 = r1['dlqMessage'] as Map<String, Object?>;
        expect(d1.containsKey('key'), isTrue);
        expect(d1['key'], isNull);
        expect(d1.containsKey('value'), isTrue);
        expect(d1['value'], isNull);

        final r2 = meta.toFailureReport(emptyKeyMsg);
        final d2 = r2['dlqMessage'] as Map<String, Object?>;
        expect(d2['key'], '');
        expect(d2['value'], '');
      },
    );
  });
}
