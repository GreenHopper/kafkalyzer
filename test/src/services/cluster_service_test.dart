import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ClusterService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ClusterService();
  });

  group('ClusterService', () {
    test('loadClusters returns empty list when no data stored', () async {
      SharedPreferences.setMockInitialValues({});
      final clusters = await service.loadClusters();
      expect(clusters, isEmpty);
    });

    test('loadClusters returns parsed clusters when data exists', () async {
      final jsonString =
          '[{"name":"Test Cluster","bootstrapServers":"localhost:9092","securityProtocol":"PLAINTEXT"}]';
      SharedPreferences.setMockInitialValues({'cluster_profiles': jsonString});

      final clusters = await service.loadClusters();
      expect(clusters.length, 1);
      expect(clusters.first.name, 'Test Cluster');
      expect(clusters.first.bootstrapServers, 'localhost:9092');
      expect(clusters.first.securityProtocol, 'PLAINTEXT');
    });

    test('loadClusters returns empty list on json parse error', () async {
      SharedPreferences.setMockInitialValues({
        'cluster_profiles': 'INVALID_JSON',
      });

      final clusters = await service.loadClusters();
      expect(clusters, isEmpty);
    });

    test('saveClusters stores clusters as json string', () async {
      SharedPreferences.setMockInitialValues({});
      final clusters = [
        ClusterProfile(
          name: 'Saved Cluster',
          bootstrapServers: 'localhost:9094',
          securityProtocol: 'SSL',
        ),
      ];

      await service.saveClusters(clusters);

      final prefs = await SharedPreferences.getInstance();
      final storedString = prefs.getString('cluster_profiles');
      expect(storedString, isNotNull);
      expect(storedString, contains('Saved Cluster'));
      expect(storedString, contains('localhost:9094'));
    });
  });
}
