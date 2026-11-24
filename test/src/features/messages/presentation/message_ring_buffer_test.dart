import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/features/messages/presentation/message_ring_buffer.dart';

KafkaMessage _msg(int offset) => KafkaMessage(
  topic: 't',
  partition: 0,
  offset: offset,
  key: 'k$offset',
  payload: 'p$offset',
  timestamp: 1000 + offset,
);

void main() {
  group('MessageRingBuffer', () {
    test('appends below capacity and tracks receivedTotal/droppedTotal', () {
      final buffer = MessageRingBuffer(5);
      expect(buffer.capacity, 5);
      expect(buffer.length, 0);
      expect(buffer.receivedTotal, 0);
      expect(buffer.droppedTotal, 0);
      expect(buffer.epoch, 0);

      for (var i = 0; i < 3; i++) {
        buffer.add(_msg(i));
      }

      expect(buffer.length, 3);
      expect(buffer.receivedTotal, 3);
      expect(buffer.droppedTotal, 0);

      final snap = buffer.snapshot();
      expect(snap.map((m) => m.offset).toList(), [0, 1, 2]);
      expect(snap.epoch, 0);
      expect(snap.firstSeq, 0);
      expect(snap.endSeq, 3);
    });

    test('evicts oldest in arrival order when exceeding capacity', () {
      final buffer = MessageRingBuffer(3);
      for (var i = 0; i < 5; i++) {
        buffer.add(_msg(i));
      }

      expect(buffer.length, 3);
      expect(buffer.receivedTotal, 5);
      expect(buffer.droppedTotal, 2);

      final snap = buffer.snapshot();
      expect(snap.map((m) => m.offset).toList(), [2, 3, 4]);
      expect(snap.firstSeq, 2);
      expect(snap.endSeq, 5);
    });

    test('snapshot is immutable and unaffected by later adds or clear', () {
      final buffer = MessageRingBuffer(3);
      buffer.add(_msg(1));
      buffer.add(_msg(2));
      final snap = buffer.snapshot();

      buffer.add(_msg(3));
      buffer.add(_msg(4));
      expect(snap.map((m) => m.offset).toList(), [1, 2]);
      expect(snap.firstSeq, 0);
      expect(snap.endSeq, 2);
      expect(() => snap.add(_msg(99)), throwsUnsupportedError);

      buffer.clear();
      expect(buffer.length, 0);
      expect(buffer.receivedTotal, 0);
      expect(buffer.droppedTotal, 0);
      expect(buffer.epoch, 1);
      expect(snap.map((m) => m.offset).toList(), [1, 2]);
    });

    test('10,000 adds at capacity stay fast (O(1) per add)', () {
      final buffer = MessageRingBuffer(1000);
      final sw = Stopwatch()..start();
      for (var i = 0; i < 10000; i++) {
        buffer.add(_msg(i));
      }
      sw.stop();

      expect(buffer.length, 1000);
      expect(buffer.receivedTotal, 10000);
      expect(buffer.droppedTotal, 9000);
      expect(sw.elapsedMilliseconds, lessThan(500));
    });
  });
}
