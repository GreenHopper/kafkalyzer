import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/ui/messages/message_sort_utils.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    getIt.registerSingleton<Logger>(Logger(level: Level.off));
  });

  tearDown(() async {
    await getIt.reset();
  });

  test(
    'stream error stores message in errors[target] and restart clears it',
    () async {
      late StreamController<KafkaMessage> streamCtrl;
      final controller = MultiSearchController(
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
            }) {
              streamCtrl = StreamController<KafkaMessage>();
              return streamCtrl.stream;
            },
      );

      final target = SearchTarget(
        profile: const ClusterProfile(
          name: 'prod',
          bootstrapServers: 'b:9092',
          tlsVerification: TlsVerification.enabled,
        ),
        topic: const TopicMetadata(
          name: 'orders',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      );

      controller.addTarget(target);
      streamCtrl.addError(Exception('Stream boom'));
      await Future<void>.delayed(Duration.zero);

      expect(controller.status[target], SearchStatus.error);
      expect(controller.errors[target], contains('Stream boom'));

      controller.addTarget(target);
      expect(controller.errors[target], isNull);
      expect(controller.status[target], SearchStatus.running);

      await streamCtrl.close();
      controller.dispose();
    },
  );

  test(
    'compareMessageIdentity orders by topic, then partition, then offset',
    () {
      final a = KafkaMessage(
        topic: 'a',
        partition: 0,
        offset: 1,
        timestamp: 100,
      );
      final b = KafkaMessage(
        topic: 'a',
        partition: 0,
        offset: 2,
        timestamp: 100,
      );
      final c = KafkaMessage(
        topic: 'a',
        partition: 1,
        offset: 0,
        timestamp: 100,
      );
      final d = KafkaMessage(
        topic: 'b',
        partition: 0,
        offset: 0,
        timestamp: 100,
      );

      final list = [d, c, b, a]..sort(compareMessageIdentity);
      expect(list, [a, b, c, d]);
    },
  );

  test(
    'getMessagesFor(null) breaks timestamp ties deterministically',
    () async {
      final controllers = <String, StreamController<KafkaMessage>>{};
      final controller = MultiSearchController(
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
            }) {
              final sc = StreamController<KafkaMessage>();
              controllers[topic] = sc;
              return sc.stream;
            },
      );

      const profile = ClusterProfile(
        name: 'prod',
        bootstrapServers: 'b:9092',
        tlsVerification: TlsVerification.enabled,
      );
      final tB = SearchTarget(
        profile: profile,
        topic: const TopicMetadata(
          name: 'b-topic',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      );
      final tA = SearchTarget(
        profile: profile,
        topic: const TopicMetadata(
          name: 'a-topic',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      );

      controller.addTarget(tB);
      controller.addTarget(tA);
      controllers['b-topic']!.add(
        KafkaMessage(topic: 'b-topic', partition: 0, offset: 1, timestamp: 500),
      );
      controllers['a-topic']!.add(
        KafkaMessage(topic: 'a-topic', partition: 0, offset: 9, timestamp: 500),
      );
      await Future<void>.delayed(Duration.zero);

      final merged = controller.getMessagesFor(null);
      expect(merged.map((m) => m.topic).toList(), ['a-topic', 'b-topic']);

      for (final sc in controllers.values) {
        await sc.close();
      }
      controller.dispose();
    },
  );
}
