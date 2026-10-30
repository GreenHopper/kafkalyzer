import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

void main() {
  group('DuplicateNavigationTarget', () {
    test('instantiates with explicit parameters', () {
      const target = DuplicateNavigationTarget(
        key: 'msg-key',
        payloadPreview: '{"id": 1}',
        count: 12,
        samplePartition: 2,
        sampleOffset: 1234,
        sampleTimestampMs: 1690000000000,
        scope: DuplicateDetectionScope.keyAndPayload,
        filterOccurrences: true,
      );

      expect(target.key, equals('msg-key'));
      expect(target.payloadPreview, equals('{"id": 1}'));
      expect(target.count, equals(12));
      expect(target.samplePartition, equals(2));
      expect(target.sampleOffset, equals(1234));
      expect(target.sampleTimestampMs, equals(1690000000000));
      expect(target.scope, equals(DuplicateDetectionScope.keyAndPayload));
      expect(target.filterOccurrences, isTrue);
    });

    test('builds correctly from TopDuplicateOccurrence', () {
      const occurrence = TopDuplicateOccurrence(
        key: 'sample-key',
        payloadPreview: 'test payload',
        count: 15,
        percentage: 1.5,
        samplePartition: 3,
        sampleOffset: 500,
        sampleTimestampMs: 1700000000,
      );

      final target = DuplicateNavigationTarget.fromOccurrence(
        occurrence: occurrence,
        scope: DuplicateDetectionScope.payloadOnly,
        filterOccurrences: false,
      );

      expect(target.key, equals('sample-key'));
      expect(target.payloadPreview, equals('test payload'));
      expect(target.count, equals(15));
      expect(target.samplePartition, equals(3));
      expect(target.sampleOffset, equals(500));
      expect(target.sampleTimestampMs, equals(1700000000));
      expect(target.scope, equals(DuplicateDetectionScope.payloadOnly));
      expect(target.filterOccurrences, isFalse);
    });
  });
}
