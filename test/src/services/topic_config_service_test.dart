import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/topic_config.dart';
import 'package:kafkalyzer/src/rust/frb_generated.dart';
import 'package:kafkalyzer/src/services/topic_config_service.dart';
import 'package:mockito/mockito.dart';

import '../rust/api/rust_mocks.mocks.dart';

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
    name: 'c1',
    bootstrapServers: 'localhost:9092',
    tlsVerification: TlsVerification.enabled,
  );

  test('TopicConfigService delegates fetch and diff', () async {
    const snap = TopicConfigSnapshot(
      topic: 'orders',
      availability: TopicConfigAvailability.available,
      entries: [],
    );
    const diff = TopicConfigDiff(rows: [], differenceCount: 0);

    when(
      mockApi.crateApiTopicConfigFetchTopicConfig(
        profile: profile,
        topic: 'orders',
      ),
    ).thenAnswer((_) async => snap);
    when(
      mockApi.crateApiTopicConfigDiffTopicConfigs(left: snap, right: snap),
    ).thenReturn(diff);

    final service = TopicConfigService();
    expect(
      await service.fetchTopicConfig(profile: profile, topic: 'orders'),
      snap,
    );
    expect(service.diffTopicConfigs(left: snap, right: snap), diff);
  });
}
