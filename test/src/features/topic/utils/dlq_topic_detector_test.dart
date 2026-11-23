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
}
