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
      final topic = const TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 1,
        cleanupPolicy: 'delete',
        retentionMs: '604800000',
      );

      final other = const TopicMetadata(
        name: 'test-topic',
        partitionCount: 3,
        replicationFactor: 1,
        cleanupPolicy: 'delete',
        retentionMs: '604800000',
      );

      expect(topic, equals(other));
      expect(topic.hashCode, equals(other.hashCode));
      expect(topic.name, 'test-topic');
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
  });
}
