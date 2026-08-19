import 'package:kafkalyzer/src/rust/api/kafka_utils.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import 'rust_mocks.mocks.dart';

// Mock specific opaque class if needed, or rely on dynamic dispatch/late binding if generated code allows
class MockClientConfig extends Mock implements ClientConfig {}

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
  );

  group('KafkaUtils', () {
    test('murmur2 calls bridge', () async {
      when(
        mockApi.crateApiKafkaUtilsMurmur2(data: [1, 2, 3]),
      ).thenAnswer((_) async => 12345);

      final result = await murmur2(data: [1, 2, 3]);

      expect(result, 12345);
      verify(mockApi.crateApiKafkaUtilsMurmur2(data: [1, 2, 3])).called(1);
    });

    test('toPositive calls bridge', () async {
      when(
        mockApi.crateApiKafkaUtilsToPositive(number: -5),
      ).thenAnswer((_) async => 5);

      final result = await toPositive(number: -5);

      expect(result, 5);
      verify(mockApi.crateApiKafkaUtilsToPositive(number: -5)).called(1);
    });

    // createConfig returns an opaque type ClientConfig which is tricky to verify equality on
    // without more mocking, but we can verify the call happens.
    test('createConfig calls bridge', () async {
      final config = MockClientConfig();
      when(
        mockApi.crateApiKafkaUtilsCreateConfig(profile: profile),
      ).thenAnswer((_) async => config);

      final result = await createConfig(profile: profile);

      expect(result, config);
      verify(
        mockApi.crateApiKafkaUtilsCreateConfig(profile: profile),
      ).called(1);
    });
  });
}
