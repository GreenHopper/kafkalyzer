import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/cluster_dropdown.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

// Manual Mocks
class MockClusterListController extends ClusterListController {
  final List<ClusterProfile> _testClusters;

  MockClusterListController(this._testClusters);

  @override
  List<ClusterProfile> get clusters => _testClusters;
}

class MockTopicController extends TopicController {
  final Map<String, bool> _cachedStatus;

  MockTopicController(this._cachedStatus);

  @override
  bool hasCachedTopics(ClusterProfile cluster) =>
      _cachedStatus[cluster.name] ?? false;
}

class MockClusterService extends ClusterService {
  @override
  Future<List<ClusterProfile>> loadClusters() async => [];

  @override
  Future<void> saveClusters(List<ClusterProfile> clusters) async {}
}

class MockKafkaMetadataService extends KafkaMetadataService {
  @override
  Future<List<TopicMetadata>> fetchTopics({
    required ClusterProfile profile,
  }) async => [];
}

void main() {
  late MockClusterListController mockClusterListController;
  late MockTopicController mockTopicController;

  final cluster1 = ClusterProfile(
    name: 'CachedCluster',
    bootstrapServers: 'localhost:9092',
  );
  final cluster2 = ClusterProfile(
    name: 'UncachedCluster',
    bootstrapServers: 'localhost:9093',
  );

  setUp(() async {
    await getIt.reset();

    getIt.registerSingleton<ClusterService>(MockClusterService());
    getIt.registerSingleton<KafkaMetadataService>(MockKafkaMetadataService());

    mockClusterListController = MockClusterListController([cluster1, cluster2]);
    getIt.registerSingleton<ClusterListController>(mockClusterListController);

    mockTopicController = MockTopicController({
      'CachedCluster': true,
      'UncachedCluster': false,
    });
    getIt.registerSingleton<TopicController>(mockTopicController);
  });

  testWidgets('ClusterDropdown renders correctly with default label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(body: ClusterDropdown(value: null, onChanged: (_) {})),
      ),
    );

    expect(
      find.byType(DropdownButtonFormField<ClusterProfile>),
      findsOneWidget,
    );
    expect(find.text('Cluster'), findsOneWidget);
  });

  testWidgets('ClusterDropdown shows visual feedback for cached clusters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(body: ClusterDropdown(value: null, onChanged: (_) {})),
      ),
    );

    // Open dropdown
    await tester.tap(find.byType(DropdownButtonFormField<ClusterProfile>));
    await tester.pumpAndSettle();

    // Verify CachedCluster has check icon
    // We find the row containing the text "CachedCluster"
    final cachedRowFinder = find.ancestor(
      of: find.text('CachedCluster'),
      matching: find.byType(Row),
    );
    expect(cachedRowFinder, findsOneWidget);
    expect(
      find.descendant(
        of: cachedRowFinder,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
      reason: 'Cached cluster should have a check circle icon',
    );

    // Verify UncachedCluster does NOT have check icon
    // The implementation wraps text in a Row regardless, but the if check for icon is inside.
    final uncachedRowFinder = find.ancestor(
      of: find.text('UncachedCluster'),
      matching: find.byType(Row),
    );
    expect(uncachedRowFinder, findsOneWidget);
    expect(
      find.descendant(
        of: uncachedRowFinder,
        matching: find.byIcon(Icons.check_circle),
      ),
      findsNothing,
      reason: 'Uncached cluster should NOT have a check circle icon',
    );
  });

  testWidgets('ClusterDropdown notifies selection changes', (
    WidgetTester tester,
  ) async {
    ClusterProfile? selectedValue;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(
          body: ClusterDropdown(
            value: null,
            onChanged: (val) {
              selectedValue = val;
            },
          ),
        ),
      ),
    );

    // Open dropdown
    await tester.tap(find.byType(DropdownButtonFormField<ClusterProfile>));
    await tester.pumpAndSettle();

    // Select 'CachedCluster'
    await tester.tap(find.text('CachedCluster').last);
    await tester.pumpAndSettle();

    expect(selectedValue, equals(cluster1));
  });

  testWidgets('ClusterDropdown updates when value changes externally', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClusterDropdown(value: cluster1, onChanged: (val) {}),
        ),
      ),
    );

    expect(find.text('CachedCluster'), findsOneWidget);

    // Update with new value
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          splashFactory: InkRipple.splashFactory,
        ),
        home: Scaffold(
          body: ClusterDropdown(value: cluster2, onChanged: (val) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('UncachedCluster'), findsOneWidget);
  });
}
