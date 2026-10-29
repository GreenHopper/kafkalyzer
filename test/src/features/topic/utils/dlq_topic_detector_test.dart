import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';

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

    test('generates valid kcat replay command', () {
      final meta = const DlqFailureMetadata(
        originalTopic: 'orders',
        originalPartition: 0,
        originalOffset: 123,
      );

      final cmd = meta.generateKcatReplayCommand(
        bootstrapServers: 'localhost:9092',
        key: 'order-1',
        payload: '{"id": 1}',
      );

      expect(cmd, contains("kcat -b localhost:9092 -t orders -P"));
      expect(cmd, contains("-k 'order-1'"));
      expect(cmd, contains("printf '%s' '{\"id\": 1}'"));
    });
  });
}
