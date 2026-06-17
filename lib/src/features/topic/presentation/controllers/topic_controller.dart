import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';

class TopicController extends ChangeNotifier {
  final KafkaMetadataService _metadataService = getIt<KafkaMetadataService>();
  final Map<String, List<api.TopicMetadata>> _cache = {};
  final Map<String, bool> _isLoading = {};

  List<api.TopicMetadata>? getTopics(ClusterProfile cluster) => _cache[cluster.name];

  bool hasCachedTopics(ClusterProfile cluster) => _cache.containsKey(cluster.name);

  bool isLoading(ClusterProfile cluster) => _isLoading[cluster.name] ?? false;

  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    if (!force && _cache.containsKey(cluster.name)) return;

    _isLoading[cluster.name] = true;
    notifyListeners();

    try {
      final topics = await _metadataService.fetchTopics(profile: cluster);
      _cache[cluster.name] = topics;
    } catch (e) {
      debugPrint("Error fetching topics for ${cluster.name}: $e");
      // Optionally handle error state
    } finally {
      _isLoading[cluster.name] = false;
      notifyListeners();
    }
  }

  void clearCache(ClusterProfile cluster) {
    _cache.remove(cluster.name);
    notifyListeners();
  }
}
