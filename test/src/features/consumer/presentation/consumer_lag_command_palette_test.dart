import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/consumer/application/consumer_group_directory.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/consumer_lag_view.dart';
import 'package:kafkalyzer/src/features/consumer/presentation/group_details_view.dart';
import 'package:kafkalyzer/src/features/navigation/main_navigation_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:logger/logger.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeMetadataService implements KafkaMetadataService {
  List<ConsumerGroupLag> groups = [];
  bool shouldFail = false;
  Completer<void>? groupsCompleter;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<api.TopicMetadata> fetchTopicMetadata({
    required ClusterProfile profile,
    required String topic,
  }) async =>
      api.TopicMetadata(name: topic, partitionCount: 0, replicationFactor: 0);

  @override
  Future<List<api.TopicConfigResult>> describeTopicConfigs({
    required ClusterProfile profile,
    required List<String> topics,
  }) async => const [];

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroups({
    required ClusterProfile profile,
  }) async {
    if (groupsCompleter != null) {
      await groupsCompleter!.future;
    }
    if (shouldFail) {
      throw Exception('fetch failed');
    }
    return groups;
  }

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerGroupLags({
    required ClusterProfile profile,
    required List<String> groupIds,
  }) async {
    return [
      for (final id in groupIds) groups.firstWhere((g) => g.groupId == id),
    ];
  }

  @override
  Future<ConsumerGroupLag> fetchConsumerGroupLag({
    required ClusterProfile profile,
    required String groupId,
  }) async => groups.firstWhere((g) => g.groupId == groupId);

  @override
  Future<List<ConsumerGroupLag>> fetchConsumerLags({
    required ClusterProfile profile,
  }) async => groups;

  @override
  Future<api.TopicPartitionDetails> fetchTopicPartitions({
    required ClusterProfile profile,
    required String topic,
  }) async => api.TopicPartitionDetails(
    topic: topic,
    partitions: const [],
    brokers: const [],
  );

  @override
  Future<List<api.TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async => const [];

  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async =>
      true;
}

class _FakeActiveConnection extends ChangeNotifier
    implements ActiveConnectionController {
  _FakeActiveConnection(this._profile);
  final ClusterProfile _profile;

  @override
  ClusterProfile? get activeProfile => _profile;

  @override
  bool get isConnecting => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeClusterList extends ChangeNotifier implements ClusterListController {
  @override
  List<ClusterProfile> get clusters => const [];

  @override
  bool get isLoading => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeTopicController extends ChangeNotifier implements TopicController {
  @override
  bool isLoading(ClusterProfile cluster) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsService implements SettingsService {
  @override
  Future<int> lagWarnThreshold() async => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConsumerGroupLag _makeGroup(String id) => ConsumerGroupLag(
  groupId: id,
  state: 'Stable',
  protocolType: 'consumer',
  partitionLags: [
    TopicPartitionLag(
      topic: 'orders',
      partition: 0,
      logEndOffset: 10,
      currentOffset: 8,
      lag: 2,
      status: PartitionLagStatus.known,
    ),
  ],
  membersCount: 1,
  topicsCount: 1,
  members: const [],
  unassignedPartitions: const [],
  ownershipKnown: true,
);

void main() {
  final getIt = GetIt.instance;
  const prod = ClusterProfile(
    name: 'prod',
    bootstrapServers: 'b:9092',
    tlsVerification: TlsVerification.enabled,
  );

  late _FakeMetadataService metadata;
  late ConsumerGroupDirectory directory;
  late MainNavigationController nav;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    metadata = _FakeMetadataService()
      ..groups = [_makeGroup('group-a'), _makeGroup('group-b')];
    directory = ConsumerGroupDirectory();
    nav = MainNavigationController();

    getIt.registerSingleton<Logger>(Logger());
    getIt.registerSingleton<KafkaMetadataService>(metadata);
    getIt.registerSingleton<ActiveConnectionController>(
      _FakeActiveConnection(prod),
    );
    getIt.registerSingleton<ClusterListController>(_FakeClusterList());
    getIt.registerSingleton<TopicController>(_FakeTopicController());
    getIt.registerSingleton<SettingsService>(_FakeSettingsService());
    getIt.registerSingleton<ConsumerGroupDirectory>(directory);
    getIt.registerSingleton<MainNavigationController>(nav);
  });

  tearDown(() async {});

  Widget buildApp() {
    return const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ConsumerLagView()),
    );
  }

  testWidgets(
    'records group ids on success and preserves previous list on failure',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      expect(directory.idsFor('prod'), ['group-a', 'group-b']);

      metadata.shouldFail = true;
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pumpAndSettle();

      expect(directory.idsFor('prod'), ['group-a', 'group-b']);
    },
  );

  testWidgets(
    'reveals requested group on fresh mount, while visible, and shows SnackBar if missing',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      metadata.groupsCompleter = Completer<void>();
      nav.openConsumerGroup('group-b');

      await tester.pumpWidget(buildApp());
      await tester.pump();

      // Complete initial fetch after mount
      metadata.groupsCompleter!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(GroupDetailsView), findsOneWidget);

      // Reveal another group while already visible
      nav.openConsumerGroup('group-a');
      await tester.pumpAndSettle();
      expect(find.byType(GroupDetailsView), findsOneWidget);

      // Missing group shows SnackBar
      nav.openConsumerGroup('missing-group');
      await tester.pumpAndSettle();
      expect(
        find.text('Consumer group missing-group not found'),
        findsOneWidget,
      );
    },
  );
}
