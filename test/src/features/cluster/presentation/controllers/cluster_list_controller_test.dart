import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:flutter_test/flutter_test.dart';

// Manual Mock
class MockClusterService extends ClusterService {
  List<ClusterProfile> _clusters = [];

  @override
  Future<List<ClusterProfile>> loadClusters() async {
    return List.from(_clusters);
  }

  @override
  Future<void> saveClusters(List<ClusterProfile> clusters) async {
    _clusters = List.from(clusters);
  }

  // Helper to pre-seed data
  void setClusters(List<ClusterProfile> clusters) {
    _clusters = List.from(clusters);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClusterListController controller;
  late MockClusterService mockService;

  setUp(() async {
    await getIt.reset();
    mockService = MockClusterService();
    getIt.registerSingleton<ClusterService>(mockService);

    controller = ClusterListController();
    // Wait for initial load constructor
    await Future.delayed(Duration.zero);
  });

  group('ClusterListController', () {
    test('loads empty list initially', () async {
      expect(controller.clusters, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('adds a cluster', () async {
      final newCluster = ClusterProfile(
        name: 'Test Cluster',
        bootstrapServers: 'localhost:9092',
      );

      await controller.addCluster(newCluster);

      expect(controller.clusters.length, 1);
      expect(controller.clusters.first.name, 'Test Cluster');
    });

    test('updates a cluster', () async {
      final cluster = ClusterProfile(
        name: 'Initial Name',
        bootstrapServers: 'localhost:9092',
      );
      await controller.addCluster(cluster);

      final updatedCluster = cluster.copyWith(name: 'Updated Name');
      await controller.updateCluster(0, updatedCluster);

      expect(controller.clusters.length, 1);
      expect(controller.clusters.first.name, 'Updated Name');
    });

    test('deletes a cluster', () async {
      final cluster = ClusterProfile(
        name: 'To Delete',
        bootstrapServers: 'localhost:9092',
      );
      await controller.addCluster(cluster);
      expect(controller.clusters.length, 1);

      await controller.deleteCluster(0);
      expect(controller.clusters, isEmpty);
    });
  });
}
