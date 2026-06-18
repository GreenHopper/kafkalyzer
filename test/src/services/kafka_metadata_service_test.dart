import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../rust/api/rust_mocks.mocks.dart';

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

  group('KafkaMetadataService', () {
    test('validateConnection delegates to API', () async {
      when(
        mockApi.crateApiKafkaMetadataValidateConnection(profile: profile),
      ).thenAnswer((_) async => true);

      final service = KafkaMetadataService();
      final result = await service.validateConnection(profile: profile);

      expect(result, isTrue);
      verify(
        mockApi.crateApiKafkaMetadataValidateConnection(profile: profile),
      ).called(1);
    });

    test('fetchTopics delegates to API', () async {
      final topics = [
        const api.TopicMetadata(
          name: 'topic1',
          partitionCount: 1,
          replicationFactor: 1,
        ),
      ];
      when(
        mockApi.crateApiKafkaMetadataFetchTopics(profile: profile),
      ).thenAnswer((_) async => topics);

      final service = KafkaMetadataService();
      final result = await service.fetchTopics(profile: profile);

      expect(result, topics);
      verify(
        mockApi.crateApiKafkaMetadataFetchTopics(profile: profile),
      ).called(1);
    });

    test('fetchConsumerLags delegates to API', () async {
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

      final service = KafkaMetadataService();
      final result = await service.fetchConsumerLags(profile: profile);

      expect(result, lags);
      verify(
        mockApi.crateApiKafkaMetadataFetchConsumerLags(profile: profile),
      ).called(1);
    });

    test('fetchConsumerGroups delegates to API', () async {
      final groups = [
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
      ).thenAnswer((_) async => groups);

      final service = KafkaMetadataService();
      final result = await service.fetchConsumerGroups(profile: profile);

      expect(result, groups);
      verify(
        mockApi.crateApiKafkaMetadataFetchConsumerGroups(profile: profile),
      ).called(1);
    });

    test('fetchConsumerGroupLag delegates to API', () async {
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

      final service = KafkaMetadataService();
      final result = await service.fetchConsumerGroupLag(
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
