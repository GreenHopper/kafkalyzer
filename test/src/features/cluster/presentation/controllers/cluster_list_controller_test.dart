import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:flutter_test/flutter_test.dart';

// Manual Mock
class MockClusterService extends ClusterService {
  List<ClusterProfile> _clusters = [];
  StoreStatus _status = const StoreStatus.ok();
  bool throwUnreadable = false;
  int saveCallCount = 0;
  List<ClusterProfile>? lastSaved;

  @override
  StoreStatus get storeStatus => _status;

  @override
  Future<void> discardUnreadable() async {
    throwUnreadable = false;
    _status = const StoreStatus.ok();
  }

  @override
  Future<List<ClusterProfile>> loadClusters() async {
    if (throwUnreadable) {
      _status = const StoreStatus.unreadable('/tmp/backup.json');
      throw StoredDataUnreadableException(
        'cluster_profiles',
        backupPath: '/tmp/backup.json',
      );
    }
    return List.from(_clusters);
  }

  @override
  Future<bool> saveClusters(List<ClusterProfile> clusters) async {
    saveCallCount++;
    lastSaved = List.from(clusters);
    _clusters = List.from(clusters);
    return true;
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
        tlsVerification: TlsVerification.enabled,
      );

      await controller.addCluster(newCluster);

      expect(controller.clusters.length, 1);
      expect(controller.clusters.first.name, 'Test Cluster');
    });

    test('updates a cluster', () async {
      final cluster = ClusterProfile(
        name: 'Initial Name',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.enabled,
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
        tlsVerification: TlsVerification.enabled,
      );
      await controller.addCluster(cluster);
      expect(controller.clusters.length, 1);

      await controller.deleteCluster(0);
      expect(controller.clusters, isEmpty);
    });

    test(
      'refuses mutations while store is unreadable and allows discard',
      () async {
        mockService.throwUnreadable = true;
        await controller.loadClusters();

        expect(controller.storeStatus.isUnreadable, isTrue);
        expect(controller.clusters, isEmpty);

        const cluster = ClusterProfile(
          name: 'Test',
          bootstrapServers: 'localhost:9092',
          tlsVerification: TlsVerification.enabled,
        );
        await expectLater(
          controller.addCluster(cluster),
          throwsA(isA<StoredDataUnreadableException>()),
        );
        await expectLater(
          controller.updateCluster(0, cluster),
          throwsA(isA<StoredDataUnreadableException>()),
        );
        await expectLater(
          controller.deleteCluster(0),
          throwsA(isA<StoredDataUnreadableException>()),
        );
        await expectLater(
          controller.importClusters('[]'),
          throwsA(isA<StoredDataUnreadableException>()),
        );
        await expectLater(
          controller.importClustersZip([]),
          throwsA(isA<StoredDataUnreadableException>()),
        );

        await controller.discardUnreadable();
        expect(controller.storeStatus.isOk, isTrue);
        await controller.addCluster(cluster);
        expect(controller.clusters.map((c) => c.name), ['Test']);
      },
    );

    test('retrySharedProfilesSync saves the current list again', () async {
      final cluster = ClusterProfile(
        name: 'Shared',
        bootstrapServers: 'localhost:9092',
        tlsVerification: TlsVerification.enabled,
        headlessShared: true,
      );
      await controller.addCluster(cluster);
      final savesAfterAdd = mockService.saveCallCount;

      await controller.retrySharedProfilesSync();

      expect(mockService.saveCallCount, savesAfterAdd + 1);
      expect(mockService.lastSaved!.single.name, 'Shared');
      expect(mockService.lastSaved!.single.headlessShared, isTrue);
      expect(
        identical(
          controller.sharedProfilesStatus,
          mockService.sharedProfilesStatus,
        ),
        isTrue,
      );
    });
  });
}
