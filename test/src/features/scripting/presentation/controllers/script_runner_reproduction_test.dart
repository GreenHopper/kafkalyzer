import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Manual Mocks
class MockLogger extends Logger {
  @override
  void i(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}
  @override
  void e(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}
  @override
  void w(
    dynamic message, {
    DateTime? time,
    Object? error,
    StackTrace? stackTrace,
  }) {}
}

class MockKafkaMetadataService extends KafkaMetadataService {
  @override
  Future<bool> validateConnection({required ClusterProfile profile}) async =>
      true;

  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async => [];
}

class MockClusterService extends ClusterService {
  @override
  Future<List<ClusterProfile>> loadClusters() async => [];
  @override
  Future<void> saveClusters(List<ClusterProfile> clusters) async {}
}

class MockClusterListController extends ClusterListController {
  @override
  List<ClusterProfile> get clusters => [
    const ClusterProfile(
      name: "TestCluster",
      bootstrapServers: "localhost:9092",
    ),
  ];
}

class MockTopicController extends TopicController {
  @override
  List<TopicMetadata>? getTopics(ClusterProfile cluster) {
    return [
      const TopicMetadata(
        name: "test-topic",
        partitionCount: 1,
        replicationFactor: 1,
      ),
    ];
  }
}

class MockMultiSearchController extends MultiSearchController {
  final List<SearchTarget> addedTargets = [];

  @override
  final Map<SearchTarget, SearchStatus> status = {};

  @override
  void addTarget(SearchTarget target) {
    addedTargets.add(target);
    status[target] = SearchStatus.running;
  }

  @override
  void stopTarget(SearchTarget target) {
    status[target] = SearchStatus.stopped;
    _notifyListeners();
  }

  final List<void Function()> _listeners = [];
  @override
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    for (var l in _listeners) {
      l();
    }
  }

  @override
  List<KafkaMessage> getMessagesFor(SearchTarget? target) => [];

  @override
  final Map<SearchTarget, SearchProgress> progress = {};
}

void main() {
  late ScriptRunner scriptRunner;
  late MockMultiSearchController mockMultiSearchController;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});

    getIt.reset();
    getIt.registerSingleton<Logger>(MockLogger());
    getIt.registerSingleton<KafkaMetadataService>(MockKafkaMetadataService());
    getIt.registerSingleton<ClusterService>(MockClusterService());
    getIt.registerSingleton<ClusterListController>(MockClusterListController());
    getIt.registerSingleton<TopicController>(MockTopicController());

    mockMultiSearchController = MockMultiSearchController();
    getIt.registerSingleton<MultiSearchController>(mockMultiSearchController);

    scriptRunner = ScriptRunner(
      multiSearchController: mockMultiSearchController,
    );
  });

  test(
    'Cancellation should not throw StateError if status listener triggers multiple times',
    () async {
      final script = Script(
        id: "1",
        name: "Test Script",
        steps: [
          ScriptStep(
            id: "step1",
            name: "Step 1",
            clusterName: "TestCluster",
            topicNames: ["test-topic"],
          ),
        ],
      );

      // This future will complete when the script starts running and hits the await point
      final runFuture = scriptRunner.runScript(script, {});

      // Give it a chance to start and add the target
      await Future.delayed(Duration(milliseconds: 10));

      expect(mockMultiSearchController.addedTargets.length, 1);
      final target = mockMultiSearchController.addedTargets.first;

      // Simulate cancellation
      final cancelFuture = scriptRunner.cancelScript();

      // Manually trigger listeners multiple times to simulate the race condition
      // In search_runner.dart, checkStatus() should now be guarded.
      mockMultiSearchController.stopTarget(target);
      mockMultiSearchController._notifyListeners();
      mockMultiSearchController._notifyListeners();

      await cancelFuture;
      await runFuture;

      // If we reached here without StateError, the fix worked.
      expect(
        scriptRunner.topicStatuses["step1_test-topic"],
        equals(StepStatus.completed),
      );
    },
  );
}
