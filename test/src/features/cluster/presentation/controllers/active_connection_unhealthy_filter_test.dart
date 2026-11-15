import 'package:flutter/foundation.dart';
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
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
import 'package:kafkalyzer/src/services/session_restore_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/topic_list_preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMetadataService implements KafkaMetadataService {
  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async =>
      true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTopicController extends ChangeNotifier implements TopicController {
  final Map<String, List<TopicMetadata>> _byCluster = {};

  void setTopics(String clusterName, List<TopicMetadata> topics) {
    _byCluster[clusterName] = topics;
    notifyListeners();
  }

  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) =>
      _byCluster[cluster.name];

  @override
  Future<void> fetchTopics(
    ClusterProfile cluster, {
    bool force = false,
  }) async {}

  @override
  void clearCache(ClusterProfile cluster) {
    _byCluster.remove(cluster.name);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
    fakeTopicCtrl = _FakeTopicController();
    GetIt.instance.registerSingleton<KafkaMetadataService>(
      _FakeMetadataService(),
    );
    GetIt.instance.registerSingleton<TopicController>(fakeTopicCtrl);
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
      expect(controller.topics.map((t) => t.name).toList(), [
        'healthy',
        'orders',
      ]);

      controller.showUnhealthyTopicsOnly();
      expect(controller.unhealthyTopicsOnly, isTrue);
      expect(controller.topics.map((t) => t.name).toList(), [
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
      expect(controller.topics.map((t) => t.name).toList(), [
        '__consumer_offsets',
      ]);

      // Clearing restores regular filters.
      controller.clearUnhealthyTopicsOnly();
      expect(controller.unhealthyTopicsOnly, isFalse);
      expect(controller.topics.map((t) => t.name).toList(), [
        'healthy',
        'orders',
      ]);

      // Activate again and switch cluster -> reset.
      controller.showUnhealthyTopicsOnly();
      expect(controller.unhealthyTopicsOnly, isTrue);
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
      expect(controller.unhealthyTopicsOnly, isFalse);
      expect(controller.topics.map((t) => t.name).toList(), ['b-topic']);
    },
  );
}
