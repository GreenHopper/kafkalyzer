import 'dart:collection';

import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';

/// Immutable snapshot of a [MessageRingBuffer] in arrival order, carrying
/// sequence bounds so views can compute incremental deltas.
class MessageSnapshot extends UnmodifiableListView<KafkaMessage> {
  final int epoch;
  final int firstSeq;
  final int endSeq;

  MessageSnapshot._({
    required List<KafkaMessage> items,
    required this.epoch,
    required this.firstSeq,
    required this.endSeq,
  }) : super(items);

  factory MessageSnapshot.empty({int epoch = 0}) =>
      MessageSnapshot._(items: const [], epoch: epoch, firstSeq: 0, endSeq: 0);
}

/// Bounded FIFO buffer for [KafkaMessage]s with amortized O(1) append and
/// eviction, tracking total received and dropped counts.
class MessageRingBuffer {
  final int capacity;
  final ListQueue<KafkaMessage> _queue = ListQueue<KafkaMessage>();

  int _receivedTotal = 0;
  int _epoch = 0;

  MessageRingBuffer(this.capacity) : assert(capacity > 0);

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;
  int get receivedTotal => _receivedTotal;
  int get droppedTotal => _receivedTotal - _queue.length;
  int get epoch => _epoch;

  void add(KafkaMessage message) {
    if (_queue.length >= capacity) {
      _queue.removeFirst();
    }
    _queue.addLast(message);
    _receivedTotal++;
  }

  void clear() {
    _queue.clear();
    _receivedTotal = 0;
    _epoch++;
  }

  MessageSnapshot snapshot() {
    return MessageSnapshot._(
      items: List<KafkaMessage>.of(_queue, growable: false),
      epoch: _epoch,
      firstSeq: droppedTotal,
      endSeq: _receivedTotal,
    );
  }
}
