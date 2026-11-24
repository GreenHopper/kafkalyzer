import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/profile_tools.dart';
import 'package:kafkalyzer/src/services/cluster_profile_tools.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/features/cluster/data/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/features/topic/data/topic_list_preferences_service.dart';
import 'package:kafkalyzer/src/services/topic_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMetadataService implements KafkaMetadataService {
  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Supplies the topic cache; the list view state under test is the real
/// `TopicController` behaviour.
class _FakeTopicController extends TopicController {
  final Map<String, List<TopicMetadata>> _byCluster = {};

  void setTopics(String clusterName, List<TopicMetadata> topics) {
    _byCluster[clusterName] = topics;
    notifyListeners();
  }

  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) =>
      _byCluster[cluster.name];

  @override
  bool hasCachedTopics(ClusterProfile cluster) =>
      _byCluster.containsKey(cluster.name);

  @override
  Future<void> refreshTopics(
    ClusterProfile cluster, {
    bool force = false,
  }) async {}

  @override
  void clearTopics(ClusterProfile cluster) {
    _byCluster.remove(cluster.name);
  }
}

class _FakeClusterProfileTools implements ClusterProfileTools {
  @override
  List<BootstrapServerIssue> validateBootstrapServers(String value) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClusterProfile _profile(String name) => ClusterProfile(
  name: name,
  bootstrapServers: 'localhost:9092',
  tlsVerification: TlsVerification.disabled,
);

void main() {
  late _FakeTopicController fakeTopicCtrl;
  late ActiveConnectionController controller;
  final clusterA = _profile('cluster-a');
  final clusterB = _profile('cluster-b');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<Logger>(Logger(level: Level.off));
    GetIt.instance.registerSingleton<KafkaMetadataService>(
      _FakeMetadataService(),
    );
    fakeTopicCtrl = _FakeTopicController();
    GetIt.instance.registerSingleton<TopicController>(fakeTopicCtrl);
    GetIt.instance.registerLazySingleton<TopicStore>(
      () => GetIt.instance<TopicController>(),
    );
    GetIt.instance.registerSingleton<SettingsService>(SettingsService());
    GetIt.instance.registerSingleton<RecentTopicsService>(
      RecentTopicsService(),
    );
    GetIt.instance.registerSingleton<SessionRestoreService>(
      SessionRestoreService(),
    );
    GetIt.instance.registerSingleton<TopicListPreferencesService>(
      TopicListPreferencesService(),
    );
    GetIt.instance.registerSingleton<ClusterProfileTools>(
      _FakeClusterProfileTools(),
    );
    controller = ActiveConnectionController();
  });

  tearDown(() async {
    controller.dispose();
    await GetIt.instance.reset();
  });

  test(
    'showUnhealthyTopicsOnly includes internal topics, clears to regular filters, updates on refresh, and resets on cluster switch',
    () async {
      fakeTopicCtrl.setTopics('cluster-a', const [
        TopicMetadata(
          name: '__consumer_offsets',
          partitionCount: 50,
          replicationFactor: 3,
          underReplicatedPartitions: 1,
          leaderlessPartitions: 0,
        ),
        TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 3,
          underReplicatedPartitions: 0,
          leaderlessPartitions: 1,
        ),
        TopicMetadata(
          name: 'healthy',
          partitionCount: 3,
          replicationFactor: 3,
          underReplicatedPartitions: 0,
          leaderlessPartitions: 0,
        ),
      ]);

      await controller.connect(clusterA);
      // Regular filters hide internal topics by default.
      expect(fakeTopicCtrl.topics(clusterA).map((t) => t.name).toList(), [
        'healthy',
        'orders',
      ]);

      fakeTopicCtrl.showUnhealthyTopicsOnly();
      expect(fakeTopicCtrl.unhealthyTopicsOnly, isTrue);
      expect(fakeTopicCtrl.topics(clusterA).map((t) => t.name).toList(), [
        '__consumer_offsets',
        'orders',
      ]);

      // Refresh heals 'orders' -> disappears from filtered list.
      fakeTopicCtrl.setTopics('cluster-a', const [
        TopicMetadata(
          name: '__consumer_offsets',
          partitionCount: 50,
          replicationFactor: 3,
          underReplicatedPartitions: 1,
          leaderlessPartitions: 0,
        ),
        TopicMetadata(
          name: 'orders',
          partitionCount: 3,
          replicationFactor: 3,
          underReplicatedPartitions: 0,
          leaderlessPartitions: 0,
        ),
        TopicMetadata(
          name: 'healthy',
          partitionCount: 3,
          replicationFactor: 3,
          underReplicatedPartitions: 0,
          leaderlessPartitions: 0,
        ),
      ]);
      expect(fakeTopicCtrl.topics(clusterA).map((t) => t.name).toList(), [
        '__consumer_offsets',
      ]);

      // Clearing restores regular filters.
      fakeTopicCtrl.clearUnhealthyTopicsOnly();
      expect(fakeTopicCtrl.unhealthyTopicsOnly, isFalse);
      expect(fakeTopicCtrl.topics(clusterA).map((t) => t.name).toList(), [
        'healthy',
        'orders',
      ]);

      // Activate again and switch cluster -> reset.
      fakeTopicCtrl.showUnhealthyTopicsOnly();
      expect(fakeTopicCtrl.unhealthyTopicsOnly, isTrue);
      fakeTopicCtrl.setTopics('cluster-b', const [
        TopicMetadata(
          name: 'b-topic',
          partitionCount: 1,
          replicationFactor: 1,
          underReplicatedPartitions: 0,
          leaderlessPartitions: 0,
        ),
      ]);
      await controller.connect(clusterB);
      expect(fakeTopicCtrl.unhealthyTopicsOnly, isFalse);
      expect(fakeTopicCtrl.topics(clusterB).map((t) => t.name).toList(), [
        'b-topic',
      ]);
    },
  );
}
