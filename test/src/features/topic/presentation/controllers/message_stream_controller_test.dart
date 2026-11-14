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
  late int configuredLimit;

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
    configuredLimit = 50000;
    controller = MessageStreamController(
      logger: logger,
      bufferLimitProvider: () => configuredLimit,
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
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.messages, hasLength(1));
    expect(controller.messages.first.payload, 'payload-0');
  });

  test('unlimited retention keeps more than 1000 matches', () async {
    await startUnlimited();

    for (var i = 0; i < 1500; i++) {
      streamController.add(messageAt(i));
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));

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

  test(
    'buffer limit 1,000 with 1,250 messages retains 1,000 and tracks drops',
    () async {
      configuredLimit = 1000;
      await startUnlimited();

      for (var i = 0; i < 1250; i++) {
        streamController.add(messageAt(i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(controller.bufferLimit, 1000);
      expect(controller.messages, hasLength(1000));
      expect(controller.messages.first.offset, 250);
      expect(controller.messages.last.offset, 1249);
      expect(controller.droppedCount, 250);
      expect(controller.receivedCount, 1250);
    },
  );

  test('result limit above buffer limit stops on receivedCount', () async {
    configuredLimit = 1000;
    await startWithLimit(1500);

    for (var i = 0; i < 1600; i++) {
      streamController.add(messageAt(i));
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(controller.isStreaming, isFalse);
    expect(controller.receivedCount, 1500);
    expect(controller.messages, hasLength(1000));
    expect(controller.droppedCount, 500);
  });

  test(
    'pause freezes messages identity while pendingCount grows and resume publishes',
    () async {
      await startUnlimited();

      for (var i = 0; i < 10; i++) {
        streamController.add(messageAt(i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final frozen = controller.messages;
      expect(frozen, hasLength(10));

      controller.pause();
      expect(controller.isPaused, isTrue);

      for (var i = 10; i < 25; i++) {
        streamController.add(messageAt(i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(identical(controller.messages, frozen), isTrue);
      expect(controller.pendingCount, 15);
      expect(controller.receivedCount, 25);

      controller.resume();
      expect(controller.isPaused, isFalse);
      expect(controller.pendingCount, 0);
      expect(controller.messages, hasLength(25));
      expect(identical(controller.messages, frozen), isFalse);
    },
  );

  test(
    'EOF and error keep pause and buffer; start/clear reset pause and counts',
    () async {
      await startUnlimited();
      streamController.add(messageAt(0));
      await Future<void>.delayed(const Duration(milliseconds: 80));

      controller.pause();
      streamController.add(messageAt(1));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.pendingCount, 1);

      streamController.addError(Exception('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(controller.isStreaming, isFalse);
      expect(controller.isPaused, isTrue);
      expect(controller.error, contains('boom'));
      expect(controller.messages, hasLength(1));
      expect(controller.pendingCount, 1);

      controller.clearMessages();
      expect(controller.isPaused, isFalse);
      expect(controller.pendingCount, 0);
      expect(controller.droppedCount, 0);
      expect(controller.receivedCount, 0);
      expect(controller.messages, isEmpty);
    },
  );

  test('throttles notifications to at most one per 60ms interval', () async {
    await startUnlimited();
    var notifications = 0;
    controller.addListener(() => notifications++);

    for (var i = 0; i < 50; i++) {
      streamController.add(messageAt(i));
    }
    await Future<void>.delayed(const Duration(milliseconds: 15));
    expect(notifications, 0);

    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(notifications, 1);
  });
}
