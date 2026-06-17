import 'dart:async';
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
class MockLogger extends Logger {}

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
  final Map<SearchTarget, List<KafkaMessage>> _messages = {};

  // Callback to allow tests to control when a target finishes
  Future<void> Function(SearchTarget)? onTargetAdded;

  @override
  final Map<SearchTarget, SearchStatus> status = {};

  @override
  final Map<SearchTarget, SearchProgress> progress = {};

  @override
  void addTarget(SearchTarget target) {
    addedTargets.add(target);
    status[target] = SearchStatus.running;

    if (onTargetAdded != null) {
      onTargetAdded!(target).then((_) {
        // Automatically stop if callback returns (simulate completion)
        // Unless the test explicitly manages status
        if (status[target] == SearchStatus.running) {
          status[target] = SearchStatus.stopped;
          _notifyListeners();
        }
      });
    } else {
      // Default behavior: stop immediately
      status[target] = SearchStatus.stopped;
    }
  }

  @override
  void stopTarget(SearchTarget target) {
    status[target] = SearchStatus.stopped;
    _notifyListeners();
  }

  void setMessagesForTarget(SearchTarget target, List<KafkaMessage> messages) {
    _messages[target] = messages;
  }

  // Helper to inject messages for next target matching criteria
  void queueMessages(String topic, List<KafkaMessage> messages) {
    // Logic handled in getMessagesFor if we can identify target or just use a simpler map
    // For now, let's use a simpler approach: tests set messages directly on Mock after target is added?
    // No, ScriptRunner calls getMessagesFor immediately after SearchStatus.stopped.
    // So we need to ensure messages are available when getMessagesFor is called.
  }

  // Hack: Map by topic name for simpler mocking in tests, assuming 1 target per topic per step
  final Map<String, List<KafkaMessage>> _mockMessagesByTopic = {};
  void setMockMessages(String topic, List<KafkaMessage> msgs) {
    _mockMessagesByTopic[topic] = msgs;
  }

  @override
  List<KafkaMessage> getMessagesFor(SearchTarget? target) {
    if (target == null) return [];
    if (_messages.containsKey(target)) return _messages[target]!;
    if (_mockMessagesByTopic.containsKey(target.topic.name)) {
      return _mockMessagesByTopic[target.topic.name]!;
    }
    return [];
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
    'Timestamp variable with custom format is correctly parsed and used',
    () async {
      // Arrange
      const timestampStr = "22.1.2026 09:07"; // Format without seconds
      // Calculate expected epoch using DateTime(y,m,d,h,m) which uses local time
      final expectedDate = DateTime(2026, 1, 22, 9, 7);
      final expectedEpoch = expectedDate.millisecondsSinceEpoch;

      final script = Script(
        id: "1",
        name: "Test Script",
        variables: [
          ScriptVariable(name: "startTime", type: ScriptVariableType.string),
        ],
        steps: [
          ScriptStep(
            id: "step1",
            name: "Step 1",
            clusterName: "TestCluster",
            topicNames: ["test-topic"],
            startStrategy: MultiSearchStartStrategy.customTimestamp,
            startTimestamp: "{{startTime}}",
          ),
        ],
      );

      // Act
      await scriptRunner.runScript(script, {"startTime": timestampStr});

      // Assert
      expect(mockMultiSearchController.addedTargets.length, 1);
      final target = mockMultiSearchController.addedTargets.first;

      expect(target.profile.name, "TestCluster");
      expect(target.topic.name, "test-topic");
      expect(target.startTimestamp, isNotNull);
      expect(target.startTimestamp, equals(expectedEpoch));
      expect(target.startOffset, isNull);
    },
  );

  test(
    'Fallback to earliest/latest when timestamp variables are missing or unparseable',
    () async {
      // Arrange
      final script = Script(
        id: "1",
        name: "Test Script Fallback",
        variables: [
          ScriptVariable(name: "startTime", type: ScriptVariableType.string),
          ScriptVariable(name: "stopTime", type: ScriptVariableType.string),
        ],
        steps: [
          ScriptStep(
            id: "step1",
            name: "Step 1",
            clusterName: "TestCluster",
            topicNames: ["test-topic"],
            startStrategy: MultiSearchStartStrategy.customTimestamp,
            startTimestamp: "{{startTime}}",
            endStrategy: MultiSearchEndStrategy.customTimestamp,
            endTimestamp: "{{stopTime}}",
          ),
        ],
      );

      // Act
      await scriptRunner.runScript(script, {
        "startTime": "invalid-date",
        "stopTime": "",
      });

      // Assert
      expect(mockMultiSearchController.addedTargets.length, 1);
      final target = mockMultiSearchController.addedTargets.first;

      expect(target.startTimestamp, isNull);
      expect(target.startOffset, equals(0)); // Fallback to earliest
      expect(
        target.endStrategy,
        equals(MultiSearchEndStrategy.latest),
      ); // Fallback to latest
      expect(target.endTimestamp, isNull);
    },
  );

  test(
    'Variable extraction works and value is available in subsequent steps',
    () async {
      // Arrange
      // Step 1: Extract 'orderId' from 'test-topic'
      // Step 2: Use '{{orderId}}' in filter

      final script = Script(
        id: "script-extract",
        name: "Extraction Test",
        variables: [
          ScriptVariable(name: "orderId", type: ScriptVariableType.string),
        ],
        steps: [
          ScriptStep(
            id: "step1",
            name: "Step 1",
            clusterName: "TestCluster",
            topicNames: ["test-topic"],
            extractions: [
              ScriptExtraction(jsonPath: "id", variableName: "orderId"),
            ],
          ),
          ScriptStep(
            id: "step2",
            name: "Step 2",
            clusterName: "TestCluster",
            topicNames: ["test-topic"],
            filterTemplate: "{{orderId}}",
            filterType: FilterType.contains,
          ),
        ],
      );

      // Mock result for Step 1
      mockMultiSearchController.setMockMessages("test-topic", [
        KafkaMessage(
          topic: "test-topic",
          partition: 0,
          offset: 0,
          timestamp: 0,
          payload: '{"id": "ORDER-123"}',
          key: null,
        ),
      ]);

      // Act
      await scriptRunner.runScript(script, {});

      // Assert
      // We expect 2 targets.
      // Target 1: No filter (or default), extracts ORDER-123
      // Target 2: Filter 'ORDER-123'

      expect(mockMultiSearchController.addedTargets.length, 2);
      final target2 = mockMultiSearchController.addedTargets[1];
      expect(target2.stepId, "step2");
      expect(target2.filterTerm, "ORDER-123");
    },
  );

  test('Step dependency: Step 2 waits for variable from Step 1', () async {
    // This test is tricky because runScript is async and handles the loop.
    // We can simulate delay in Step 1 and verify Step 2 hasn't started.

    final script = Script(
      id: "script-dep",
      name: "Dependency Test",
      variables: [],
      steps: [
        ScriptStep(
          id: "step1",
          name: "Step 1",
          clusterName: "TestCluster",
          topicNames: ["topic1"],
          extractions: [ScriptExtraction(jsonPath: "id", variableName: "var1")],
        ),
        ScriptStep(
          id: "step2",
          name: "Step 2",
          clusterName: "TestCluster",
          topicNames: ["topic2"],
          filterTemplate: "{{var1}}", // This creates dependency
        ),
      ],
    );

    final step1Completer = Completer<void>();
    bool step2Started = false;

    mockMultiSearchController.onTargetAdded = (target) async {
      if (target.topic.name == "topic1") {
        await step1Completer.future;
        // Provide message so extraction happens
        mockMultiSearchController.setMessagesForTarget(target, [
          KafkaMessage(
            topic: "topic1",
            partition: 0,
            offset: 0,
            timestamp: 0,
            payload: '{"id": "VAL"}',
          ),
        ]);
      } else if (target.topic.name == "topic2") {
        step2Started = true;
      }
    };

    // Act
    final runFuture = scriptRunner.runScript(script, {});

    // Allow valid microtasks to propagate
    await Future.delayed(Duration(milliseconds: 10));

    // Assert: Step 1 should be running (added), Step 2 should NOT be running yet
    expect(
      mockMultiSearchController.addedTargets.any(
        (t) => t.topic.name == "topic1",
      ),
      isTrue,
    );
    expect(step2Started, isFalse);

    // Complete Step 1
    step1Completer.complete();

    // Wait for run to finish
    await runFuture;

    // Now Step 2 should have run
    expect(step2Started, isTrue);
    // And filter should be correct
    final target2 = mockMultiSearchController.addedTargets.firstWhere(
      (t) => t.topic.name == "topic2",
    );
    expect(target2.filterTerm, "VAL");
  });

  test('Multi-value variable expansion in filter', () async {
    // Test expansion of "A,B" into multiple filter terms
    final script = Script(
      id: "script-multi",
      name: "Multi Value Test",
      variables: [],
      steps: [
        ScriptStep(
          id: "step1",
          name: "Step 1",
          clusterName: "TestCluster",
          topicNames: ["topic1"],
          filterTemplate: "ID: {{ids}}",
          filterType: FilterType.contains,
        ),
      ],
    );

    // Act
    await scriptRunner.runScript(script, {"ids": "123, 456"});

    // Assert
    expect(mockMultiSearchController.addedTargets.length, 1);
    final target = mockMultiSearchController.addedTargets.first;

    expect(target.filterTerms, isNotNull);
    expect(target.filterTerms!.length, 2);
    expect(target.filterTerms, containsAll(["ID: 123", "ID: 456"]));
    expect(target.filterTerm, isNull); // Should be null if expanded
  });
}
