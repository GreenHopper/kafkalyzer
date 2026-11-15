import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

class _FakeMetadataService implements KafkaMetadataService {
  Future<PartitionOffsetDistribution> Function()? onOffsets;
  Future<List<TopicConfigResult>> Function()? onConfigs;
  Future<TopicTimeRange> Function()? onTimeRange;

  @override
  Future<PartitionOffsetDistribution> fetchPartitionOffsets({
    required ClusterProfile profile,
    required String topic,
    int? skewThresholdPercent,
  }) => onOffsets!();

  @override
  Future<List<TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) => onConfigs!();

  @override
  Future<TopicTimeRange> fetchTopicTimeRange({
    required ClusterProfile profile,
    required String topic,
  }) => onTimeRange!();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClusterProfile _profile() => const ClusterProfile(
  name: 'prod',
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

void main() {
  late _FakeMetadataService fakeMetadata;
  late TopicFactsController controller;

  setUp(() {
    fakeMetadata = _FakeMetadataService();
    controller = TopicFactsController(
      profile: _profile(),
      topicName: 'orders',
      metadataService: fakeMetadata,
    );
  });

  tearDown(() {
    controller.dispose();
  });

  test('loadFacts loads complete offsets and retention configs', () async {
    fakeMetadata.onOffsets = () async => const PartitionOffsetDistribution(
      topic: 'orders',
      readAtMs: 1_000,
      partitions: [],
      totalSpan: 350,
      knownSpan: 350,
      complete: true,
      skewStatus: OffsetSkewStatus.balanced,
    );
    fakeMetadata.onConfigs = () async => const [
      TopicConfigResult(
        topic: 'orders',
        status: TopicConfigStatus.available,
        entries: [
          TopicConfigEntry(
            name: 'retention.ms',
            value: '129600000',
            source: TopicConfigSource.dynamicTopic,
            isDefault: false,
            isSensitive: false,
            isReadOnly: false,
          ),
          TopicConfigEntry(
            name: 'retention.bytes',
            value: '1073741824',
            source: TopicConfigSource.dynamicTopic,
            isDefault: false,
            isSensitive: false,
            isReadOnly: false,
          ),
        ],
      ),
    ];

    await controller.loadFacts();

    expect(controller.offsets.status, TopicFactStatus.value);
    expect(controller.offsets.data?.complete, isTrue);
    expect(controller.offsets.data?.totalSpan, 350);

    expect(controller.configs.status, TopicFactStatus.value);
    expect(controller.configs.data?.retentionMs, '129600000');
    expect(controller.configs.data?.retentionBytes, '1073741824');
    expect(controller.timeRange.status, TopicFactStatus.idle);
  });

  test(
    'incomplete offsets mark estimate unknown and capture notReadable',
    () async {
      fakeMetadata.onOffsets = () async => const PartitionOffsetDistribution(
        topic: 'orders',
        readAtMs: 1_000,
        partitions: [
          PartitionOffsetRow(
            partition: 0,
            state: PartitionOffsetState.known,
            low: 0,
            high: 10,
            span: 10,
            skewed: false,
          ),
          PartitionOffsetRow(
            partition: 1,
            state: PartitionOffsetState.notReadable,
            error: 'ACL denied',
            skewed: false,
          ),
        ],
        totalSpan: null,
        knownSpan: 10,
        complete: false,
        skewStatus: OffsetSkewStatus.incomplete,
      );
      fakeMetadata.onConfigs = () async => const [
        TopicConfigResult(
          topic: 'orders',
          status: TopicConfigStatus.notReadable,
          message: 'DescribeConfigs denied',
          entries: [],
        ),
      ];

      await controller.loadFacts();

      expect(controller.offsets.status, TopicFactStatus.value);
      expect(controller.offsets.data?.complete, isFalse);
      expect(controller.offsets.data?.totalSpan, isNull);
      expect(controller.offsets.data?.notReadable, isTrue);
      expect(controller.offsets.data?.unreadableReason, 'ACL denied');

      expect(controller.configs.status, TopicFactStatus.error);
      expect(controller.configs.notReadable, isTrue);
    },
  );

  test(
    'loadTimeRange handles partial, empty, error and refresh resets to idle',
    () async {
      fakeMetadata.onOffsets = () async => const PartitionOffsetDistribution(
        topic: 'orders',
        readAtMs: 1_000,
        partitions: [],
        totalSpan: 10,
        knownSpan: 10,
        complete: true,
        skewStatus: OffsetSkewStatus.balanced,
      );
      fakeMetadata.onConfigs = () async => const [];

      fakeMetadata.onTimeRange = () async => const TopicTimeRange(
        oldest: PartitionTimestamp(
          partition: 0,
          offset: 0,
          timestampMs: 1_000,
          timestampType: TimeRangeTimestampKind.createTime,
        ),
        newest: null,
        partitionsTotal: 2,
        partitionsEmpty: 0,
        oldestKnown: 1,
        newestKnown: 0,
        allEmpty: false,
        probes: [],
      );

      await controller.loadTimeRange();
      expect(controller.timeRange.status, TopicFactStatus.value);
      expect(controller.timeRange.data?.oldestKnown, 1);
      expect(controller.timeRange.data?.newestKnown, 0);

      await controller.refresh();
      expect(controller.timeRange.status, TopicFactStatus.idle);

      fakeMetadata.onTimeRange = () async => throw Exception('broker down');
      await controller.loadTimeRange();
      expect(controller.timeRange.status, TopicFactStatus.error);
      expect(controller.timeRange.error, contains('broker down'));

      fakeMetadata.onTimeRange = () async => const TopicTimeRange(
        oldest: null,
        newest: null,
        partitionsTotal: 2,
        partitionsEmpty: 2,
        oldestKnown: 0,
        newestKnown: 0,
        allEmpty: true,
        probes: [],
      );
      await controller.loadTimeRange();
      expect(controller.timeRange.status, TopicFactStatus.value);
      expect(controller.timeRange.data?.allEmpty, isTrue);
    },
  );
}
