import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'rust_mocks.mocks.dart';

void main() {
  late MockRustLibApi mockApi;

  setUpAll(() {
    mockApi = MockRustLibApi();
    RustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    RustLib.dispose();
  });

  setUp(() {
    reset(mockApi);
  });

  const profile = ClusterProfile(
    name: 'test',
    bootstrapServers: 'localhost:9092',
  );

  group('KafkaConsumer', () {
    test('KafkaMessage data class', () {
      const msg = KafkaMessage(
        topic: 'topic',
        partition: 0,
        offset: 10,
        key: 'key',
        payload: 'value',
        timestamp: 1000,
      );

      const other = KafkaMessage(
        topic: 'topic',
        partition: 0,
        offset: 10,
        key: 'key',
        payload: 'value',
        timestamp: 1000,
      );

      // Identical check
      expect(msg == msg, isTrue);

      // Equal objects
      expect(msg, equals(other));
      expect(msg.hashCode, equals(other.hashCode));
      expect(msg.key, 'key');
      expect(msg.payload, 'value');

      // Not equal to null or different type
      expect(msg == null, isFalse);
      expect(msg == 'not a message', isFalse);

      // Mutate each field to test operator == and hashCode changes
      expect(
        msg ==
            const KafkaMessage(
              topic: 'different',
              partition: 0,
              offset: 10,
              key: 'key',
              payload: 'value',
              timestamp: 1000,
            ),
        isFalse,
      );

      expect(
        msg ==
            const KafkaMessage(
              topic: 'topic',
              partition: 1,
              offset: 10,
              key: 'key',
              payload: 'value',
              timestamp: 1000,
            ),
        isFalse,
      );

      expect(
        msg ==
            const KafkaMessage(
              topic: 'topic',
              partition: 0,
              offset: 11,
              key: 'key',
              payload: 'value',
              timestamp: 1000,
            ),
        isFalse,
      );

      expect(
        msg ==
            const KafkaMessage(
              topic: 'topic',
              partition: 0,
              offset: 10,
              key: 'different_key',
              payload: 'value',
              timestamp: 1000,
            ),
        isFalse,
      );

      expect(
        msg ==
            const KafkaMessage(
              topic: 'topic',
              partition: 0,
              offset: 10,
              key: 'key',
              payload: 'different_payload',
              timestamp: 1000,
            ),
        isFalse,
      );

      expect(
        msg ==
            const KafkaMessage(
              topic: 'topic',
              partition: 0,
              offset: 10,
              key: 'key',
              payload: 'value',
              timestamp: 1001,
            ),
        isFalse,
      );
    });

    test('consumeWithFilter calls bridge', () {
      final stream = Stream.fromIterable([
        const KafkaMessage(topic: 't', partition: 0, offset: 1, timestamp: 1),
      ]);

      when(
        mockApi.crateApiKafkaConsumerConsumeWithFilter(
          profile: anyNamed('profile'),
          topic: anyNamed('topic'),
          filterType: anyNamed('filterType'),
          searchScope: anyNamed('searchScope'),
          runForever: anyNamed('runForever'),
          startOffset: anyNamed('startOffset'),
          startTimestamp: anyNamed('startTimestamp'),
          startPartition: anyNamed('startPartition'),
          fastTraceKey: anyNamed('fastTraceKey'),
          endOffset: anyNamed('endOffset'),
          endTimestamp: anyNamed('endTimestamp'),
          maxResults: anyNamed('maxResults'),
          filterTerms: anyNamed('filterTerms'),
          filterField: anyNamed('filterField'),
        ),
      ).thenAnswer((_) => stream);

      final result = consumeWithFilter(
        profile: profile,
        topic: 'topic',
        filterType: FilterType.exact,
        searchScope: SearchScope.key,
        runForever: false,
      );

      expect(result, emits(isA<KafkaMessage>()));
    });
  });
}
