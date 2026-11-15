import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

class _FakeMetadataService implements KafkaMetadataService {
  Future<ClusterOverview> Function(ClusterProfile profile)? onFetchOverview;

  @override
  Future<ClusterOverview> fetchClusterOverview({
    required ClusterProfile profile,
  }) {
    return onFetchOverview!(profile);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTopicController extends ChangeNotifier implements TopicController {
  int fetchTopicsCallCount = 0;
  bool? lastForce;

  @override
  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    fetchTopicsCallCount++;
    lastForce = force;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClusterProfile _profile(String name) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

void main() {
  late _FakeMetadataService fakeMetadata;
  late _FakeTopicController fakeTopicCtrl;
  late ClusterOverviewController controller;
  final cluster = _profile('prod');

  setUp(() {
    fakeMetadata = _FakeMetadataService();
    fakeTopicCtrl = _FakeTopicController();
    controller = ClusterOverviewController(
      metadataService: fakeMetadata,
      topicController: fakeTopicCtrl,
    );
  });

  test(
    'load transitions idle -> loading -> loaded and skips duplicate load',
    () async {
      var calls = 0;
      fakeMetadata.onFetchOverview = (_) async {
        calls++;
        return const ClusterOverview(
          brokers: [BrokerEndpoint(id: 1, host: 'b1', port: 9092)],
          clusterId: 'cid-1',
          controllerId: 1,
        );
      };

      expect(controller.stateFor(cluster).status, ClusterOverviewStatus.idle);
      await controller.load(cluster);
      expect(controller.stateFor(cluster).status, ClusterOverviewStatus.loaded);
      expect(controller.stateFor(cluster).overview?.brokers.length, 1);

      await controller.load(cluster);
      expect(calls, 1);
    },
  );

  test('load classifies authorization error as notReadable', () async {
    fakeMetadata.onFetchOverview = (_) async {
      throw Exception('not readable: ClusterAuthorizationFailed');
    };

    await controller.load(cluster);
    final state = controller.stateFor(cluster);
    expect(state.status, ClusterOverviewStatus.error);
    expect(state.notReadable, isTrue);
  });

  test('load classifies generic error as notReadable=false', () async {
    fakeMetadata.onFetchOverview = (_) async {
      throw Exception('timed out');
    };

    await controller.load(cluster);
    final state = controller.stateFor(cluster);
    expect(state.status, ClusterOverviewStatus.error);
    expect(state.notReadable, isFalse);
    expect(state.error, contains('timed out'));
  });

  test(
    'refresh reloads broker overview and forces topic list reload',
    () async {
      fakeMetadata.onFetchOverview = (_) async => const ClusterOverview(
        brokers: [],
        clusterId: null,
        controllerId: null,
      );

      await controller.refresh(cluster);
      expect(controller.stateFor(cluster).status, ClusterOverviewStatus.loaded);
      expect(fakeTopicCtrl.fetchTopicsCallCount, 1);
      expect(fakeTopicCtrl.lastForce, isTrue);

      controller.clear(cluster.name);
      expect(controller.stateFor(cluster).status, ClusterOverviewStatus.idle);
    },
  );
}
