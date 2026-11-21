import 'package:kafkalyzer/src/features/search/models/topic_search_preset.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'rust_mocks.mocks.dart';

void main() {
  late MockKafkalyzerRustLibApi mockApi;

  setUpAll(() {
    mockApi = MockKafkalyzerRustLibApi();
    KafkalyzerRustLib.initMock(api: mockApi);
  });

  tearDownAll(() {
    KafkalyzerRustLib.dispose();
  });

  setUp(() {
    reset(mockApi);
  });

  const profile = ClusterProfile(
    name: 'test',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
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

      // Not equal to different type is handled by Dart's strong typing,
      // testing it directly causes linter warnings.

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
          request: anyNamed('request'),
        ),
      ).thenAnswer((_) => stream);

      final result = consumeWithFilter(
        request: ConsumeRequest(
          profile: profile,
          topic: 'topic',
          filterType: FilterType.exact,
          searchScope: SearchScope.key,
          runForever: false,
        ),
      );

      expect(result, emits(isA<KafkaMessage>()));
    });

    ConsumeRequest capturedRequest() =>
        verify(
              mockApi.crateApiKafkaConsumerConsumeWithFilter(
                request: captureAnyNamed('request'),
              ),
            ).captured.single
            as ConsumeRequest;

    test('a request without the optional criteria keeps the old defaults', () {
      when(
        mockApi.crateApiKafkaConsumerConsumeWithFilter(
          request: anyNamed('request'),
        ),
      ).thenAnswer((_) => const Stream<KafkaMessage>.empty());

      bridgeConsumeStream(
        profile: profile,
        topic: 'topic',
        filterType: FilterType.contains,
        searchScope: SearchScope.both,
        runForever: false,
      );

      final request = capturedRequest();
      expect(request.topic, 'topic');
      expect(request.filterTerms, isNull);
      expect(request.filterField, isNull);
      expect(request.filterExpression, isNull);
      expect(request.filterVariables, isNull);
      expect(request.startOffset, isNull);
      expect(request.startTimestamp, isNull);
      expect(request.startPartition, isNull);
      expect(request.fastTraceKey, isNull);
      expect(request.endOffset, isNull);
      expect(request.endTimestamp, isNull);
      expect(request.maxResults, isNull);
      expect(request.startFromTail, isNull);
      expect(request.localSchemas, isNull);
      expect(request.runForever, isFalse);
    });

    test(
      'a saved search stored before this change replays with the same criteria',
      () {
        // Written in the on-disk format of the previous version.
        final preset = TopicSearchPreset.fromJson({
          'id': 'p1',
          'name': 'errors',
          'clusterName': 'test',
          'topicName': 'orders',
          'filterType': 'regex',
          'searchScope': 'value',
          'filterTerm': 'timeout',
          'filterExpression': 'payload contains "x"',
          'fastTraceEnabled': true,
          'limitResults': true,
          'maxResults': '50',
          'partition': '2',
          'startStrategy': 'customOffset',
          'startOffset': '1000',
          'endStrategy': 'customOffset',
          'endOffset': '2000',
          'createdAt': '2026-01-05T10:00:00.000',
        });

        when(
          mockApi.crateApiKafkaConsumerConsumeWithFilter(
            request: anyNamed('request'),
          ),
        ).thenAnswer((_) => const Stream<KafkaMessage>.empty());

        bridgeConsumeStream(
          profile: profile,
          topic: preset.topicName,
          filterTerms: [preset.filterTerm],
          filterType: preset.filterType,
          searchScope: preset.searchScope,
          filterExpression: preset.filterExpression,
          fastTraceKey: preset.fastTraceEnabled ? preset.filterTerm : null,
          startPartition: int.parse(preset.partition),
          startOffset: int.parse(preset.startOffset),
          endOffset: int.parse(preset.endOffset),
          maxResults: int.parse(preset.maxResults),
          runForever: false,
        );

        final request = capturedRequest();
        expect(request.topic, 'orders');
        expect(request.filterType, FilterType.regex);
        expect(request.searchScope, SearchScope.value);
        expect(request.filterTerms, ['timeout']);
        expect(request.filterExpression, 'payload contains "x"');
        expect(request.fastTraceKey, 'timeout');
        expect(request.startPartition, 2);
        expect(request.startOffset, 1000);
        expect(request.endOffset, 2000);
        expect(request.maxResults, 50);
      },
    );

    test(
      'a stored criterion this version cannot name is reported, not dropped',
      () {
        expect(
          () => TopicSearchPreset.fromJson({
            'id': 'p1',
            'name': 'errors',
            'clusterName': 'test',
            'topicName': 'orders',
            'filterType': 'fuzzy',
            'createdAt': '2026-01-05T10:00:00.000',
          }),
          throwsFormatException,
        );
      },
    );
  });
}
