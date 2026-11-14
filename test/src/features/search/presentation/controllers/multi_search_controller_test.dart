import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final getIt = GetIt.instance;
  late StreamController<KafkaMessage> streamController;
  late int configuredLimit;
  late MultiSearchController controller;

  const profile = ClusterProfile(
    name: 'c1',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
  );
  const topic = TopicMetadata(
    name: 'orders',
    partitionCount: 1,
    replicationFactor: 1,
  );

  KafkaMessage msg(int offset) => KafkaMessage(
    topic: 'orders',
    partition: 0,
    offset: offset,
    key: 'k$offset',
    payload: 'p$offset',
    timestamp: 1000 + offset,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
    streamController = StreamController<KafkaMessage>.broadcast();
    configuredLimit = 5000;
    controller = MultiSearchController(
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
      bufferLimitProvider: () => configuredLimit,
    );
  });

  tearDown(() async {
    controller.dispose();
    if (!streamController.isClosed) {
      await streamController.close();
    }
  });

  test(
    'retains up to buffer limit, tracks dropped and received counts',
    () async {
      final target = SearchTarget(
        profile: profile,
        topic: topic,
        filterTerm: '',
        filterType: FilterType.contains,
        scope: SearchScope.both,
      );
      controller.addTarget(target);

      for (var i = 0; i < 6000; i++) {
        streamController.add(msg(i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));

      expect(controller.getMessagesFor(target), hasLength(5000));
      expect(controller.getMessagesFor(target).first.offset, 1000);
      expect(controller.receivedCountFor(target), 6000);
      expect(controller.droppedCountFor(target), 1000);

      final target2 = SearchTarget(
        profile: profile,
        topic: const TopicMetadata(
          name: 'payments',
          partitionCount: 1,
          replicationFactor: 1,
        ),
        filterTerm: '',
        filterType: FilterType.contains,
        scope: SearchScope.both,
      );
      controller.addTarget(target2);
      for (var i = 0; i < 3000; i++) {
        streamController.add(msg(i));
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(controller.receivedCountFor(target2), 3000);
      expect(controller.droppedCountFor(target2), 0);
    },
  );

  test('trailing notification delivers last burst within 100ms', () async {
    final target = SearchTarget(
      profile: profile,
      topic: topic,
      filterTerm: '',
      filterType: FilterType.contains,
      scope: SearchScope.both,
    );
    controller.addTarget(target);

    var notifications = 0;
    controller.addListener(() => notifications++);

    // First message triggers leading notify
    streamController.add(msg(0));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    final afterFirst = notifications;
    expect(afterFirst, greaterThanOrEqualTo(1));

    // Burst right after leading notify is suppressed at first, then flushed <= 100ms
    streamController.add(msg(1));
    streamController.add(msg(2));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(controller.getMessagesFor(target), hasLength(3));

    await Future<void>.delayed(const Duration(milliseconds: 110));
    expect(notifications, greaterThan(afterFirst));
  });

  test(
    'result file writes all messages as valid JSON even when buffer drops oldest',
    () async {
      configuredLimit = 5;
      final tempDir = Directory.systemTemp.createTempSync('kafkalyzer_msc_');
      try {
        await controller.setDirectory(tempDir.path);
        final target = SearchTarget(
          profile: profile,
          topic: topic,
          filterTerm: '',
          filterType: FilterType.contains,
          scope: SearchScope.both,
        );
        controller.addTarget(target);

        for (var i = 0; i < 12; i++) {
          streamController.add(msg(i));
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        controller.stopTarget(target);
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final files = tempDir.listSync().whereType<File>().toList();
        expect(files, hasLength(1));
        final decoded =
            jsonDecode(files.first.readAsStringSync()) as Map<String, dynamic>;
        final messages = decoded['messages'] as List<dynamic>;
        expect(messages, hasLength(12));
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    },
  );
}
