import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
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

  group('KafkaMetadata', () {
    test('TopicMetadata data class', () {
      const topic = TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 1,
        cleanupPolicy: 'delete',
        retentionMs: '604800000',
      );

      const other = TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 1,
        cleanupPolicy: 'delete',
        retentionMs: '604800000',
      );

      // Identical check
      expect(topic == topic, isTrue);

      expect(topic, equals(other));
      expect(topic.hashCode, equals(other.hashCode));
      expect(topic.name, 'test-topic');
      expect(topic.cleanupPolicy, 'delete');
      expect(topic.retentionMs, '604800000');

      // Not equal to different type is handled by Dart's strong typing,
      // testing it directly causes linter warnings.

      // Mutate each field
      expect(
        topic ==
            const TopicMetadata(
              name: 'different',
              partitionCount: 3,
              replicationFactor: 1,
              cleanupPolicy: 'delete',
              retentionMs: '604800000',
            ),
        isFalse,
      );

      expect(
        topic ==
            const TopicMetadata(
              name: 'test-topic',
              partitionCount: 4,
              replicationFactor: 1,
              cleanupPolicy: 'delete',
              retentionMs: '604800000',
            ),
        isFalse,
      );

      expect(
        topic ==
            const TopicMetadata(
              name: 'test-topic',
              partitionCount: 3,
              replicationFactor: 2,
              cleanupPolicy: 'delete',
              retentionMs: '604800000',
            ),
        isFalse,
      );

      expect(
        topic ==
            const TopicMetadata(
              name: 'test-topic',
              partitionCount: 3,
              replicationFactor: 1,
              cleanupPolicy: 'compact',
              retentionMs: '604800000',
            ),
        isFalse,
      );

      expect(
        topic ==
            const TopicMetadata(
              name: 'test-topic',
              partitionCount: 3,
              replicationFactor: 1,
              cleanupPolicy: 'delete',
              retentionMs: '3600000',
            ),
        isFalse,
      );
    });

    test('validateConnection calls bridge', () async {
      when(
        mockApi.crateApiKafkaMetadataValidateConnection(profile: profile),
      ).thenAnswer((_) async => true);

      final result = await validateConnection(profile: profile);

      expect(result, isTrue);
      verify(
        mockApi.crateApiKafkaMetadataValidateConnection(profile: profile),
      ).called(1);
    });

    test('fetchTopics calls bridge', () async {
      final topics = [
        const TopicMetadata(
          name: 'topic1',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ];
      when(
        mockApi.crateApiKafkaMetadataFetchTopics(profile: profile),
      ).thenAnswer((_) async => topics);

      final result = await fetchTopics(profile: profile);

      expect(result, topics);
      verify(
        mockApi.crateApiKafkaMetadataFetchTopics(profile: profile),
      ).called(1);
    });

    test('fetchConsumerLags calls bridge', () async {
      final lags = [
        const ConsumerGroupLag(
          groupId: 'g1',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [],
          membersCount: 1,
          topicsCount: 1,
        ),
      ];
      when(
        mockApi.crateApiKafkaMetadataFetchConsumerLags(profile: profile),
      ).thenAnswer((_) async => lags);

      final result = await fetchConsumerLags(profile: profile);

      expect(result, lags);
      verify(
        mockApi.crateApiKafkaMetadataFetchConsumerLags(profile: profile),
      ).called(1);
    });

    test('fetchConsumerGroups calls bridge', () async {
      final lags = [
        const ConsumerGroupLag(
          groupId: 'g1',
          state: 'Stable',
          protocolType: 'consumer',
          partitionLags: [],
          membersCount: 1,
          topicsCount: 1,
        ),
      ];
      when(
        mockApi.crateApiKafkaMetadataFetchConsumerGroups(profile: profile),
      ).thenAnswer((_) async => lags);

      final result = await fetchConsumerGroups(profile: profile);

      expect(result, lags);
      verify(
        mockApi.crateApiKafkaMetadataFetchConsumerGroups(profile: profile),
      ).called(1);
    });

    test('fetchConsumerGroupLag calls bridge', () async {
      const lag = ConsumerGroupLag(
        groupId: 'g1',
        state: 'Stable',
        protocolType: 'consumer',
        partitionLags: [],
        membersCount: 1,
        topicsCount: 1,
      );
      when(
        mockApi.crateApiKafkaMetadataFetchConsumerGroupLag(
          profile: profile,
          groupId: 'g1',
        ),
      ).thenAnswer((_) async => lag);

      final result = await fetchConsumerGroupLag(
        profile: profile,
        groupId: 'g1',
      );

      expect(result, lag);
      verify(
        mockApi.crateApiKafkaMetadataFetchConsumerGroupLag(
          profile: profile,
          groupId: 'g1',
        ),
      ).called(1);
    });
  });
}
