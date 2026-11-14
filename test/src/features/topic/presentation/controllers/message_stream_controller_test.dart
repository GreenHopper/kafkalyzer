import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

void main() {
  const profile = ClusterProfile(
    name: 'test',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
  );

  late Logger logger;
  late StreamController<KafkaMessage> streamController;
  late MessageStreamController controller;

  KafkaMessage messageAt(int index) => KafkaMessage(
    topic: 'topic',
    partition: 0,
    offset: index,
    key: 'k$index',
    payload: 'payload-$index',
    timestamp: index,
  );

  setUp(() {
    logger = Logger(level: Level.off);
    streamController = StreamController<KafkaMessage>();
    controller = MessageStreamController(
      logger: logger,
      consumeStreamFactory:
          ({
            required profile,
            required topic,
            filterTerms,
            filterField,
            required filterType,
            required searchScope,
            fastTraceKey,
            startOffset,
            startTimestamp,
            startPartition,
            maxResults,
            endOffset,
            endTimestamp,
            required runForever,
            startFromTail,
          }) => streamController.stream,
    );
  });

  tearDown(() async {
    await controller.stopStreaming();
    controller.dispose();
    if (!streamController.isClosed) {
      unawaited(streamController.close());
    }
  });

  Future<void> startUnlimited() => controller.startStreaming(
    profile,
    'topic',
    filterType: FilterType.contains,
    searchScope: SearchScope.both,
    runForever: false,
  );

  Future<void> startWithLimit(int maxResults) => controller.startStreaming(
    profile,
    'topic',
    filterType: FilterType.contains,
    searchScope: SearchScope.both,
    maxResults: maxResults,
    runForever: false,
  );

  test('injectable stream delivers messages into the buffer', () async {
    await startUnlimited();

    streamController.add(messageAt(0));
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages, hasLength(1));
    expect(controller.messages.first.payload, 'payload-0');
  });

  test('unlimited retention keeps more than 1000 matches', () async {
    await startUnlimited();

    for (var i = 0; i < 1500; i++) {
      streamController.add(messageAt(i));
    }
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages, hasLength(1500));
    expect(controller.messages.first.offset, 0);
    expect(controller.messages.last.offset, 1499);
  });

  test('maxResults above 1000 retains N matches', () async {
    await startWithLimit(1500);

    for (var i = 0; i < 1500; i++) {
      streamController.add(messageAt(i));
    }
    // Allow stopStreaming() to settle after hitting the limit.
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages, hasLength(1500));
    expect(controller.isStreaming, isFalse);
  });

  test('maxResults stops and caps retention at N', () async {
    await startWithLimit(200);

    for (var i = 0; i < 500; i++) {
      streamController.add(messageAt(i));
    }
    await Future<void>.delayed(Duration.zero);

    expect(controller.messages, hasLength(200));
    expect(controller.isStreaming, isFalse);
  });

  test(
    'stream error sets error and stops streaming, and new startStreaming clears it',
    () async {
      await startUnlimited();
      streamController.addError(Exception('Broker disconnected'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.isStreaming, isFalse);
      expect(controller.error, contains('Broker disconnected'));

      // New startStreaming clears the error
      streamController = StreamController<KafkaMessage>();
      await startUnlimited();
      expect(controller.error, isNull);
    },
  );

  test('factory throwing sets error and stops streaming', () async {
    final throwingController = MessageStreamController(
      logger: Logger(level: Level.off),
      consumeStreamFactory:
          ({
            required profile,
            required topic,
            filterTerms,
            filterField,
            required filterType,
            required searchScope,
            fastTraceKey,
            startOffset,
            startTimestamp,
            startPartition,
            maxResults,
            endOffset,
            endTimestamp,
            required runForever,
            startFromTail,
          }) => throw StateError('Factory boom'),
    );

    await throwingController.startStreaming(
      profile,
      'orders',
      filterType: FilterType.contains,
      searchScope: SearchScope.both,
    );

    expect(throwingController.isStreaming, isFalse);
    expect(throwingController.error, contains('Factory boom'));
    throwingController.dispose();
  });
}
