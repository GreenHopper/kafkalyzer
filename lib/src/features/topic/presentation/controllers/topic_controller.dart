import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart' as api;
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/kafka_metadata_service.dart';
import 'package:logger/logger.dart';

class TopicController extends ChangeNotifier {
  final KafkaMetadataService _metadataService = getIt<KafkaMetadataService>();
  final Logger _logger = getIt.isRegistered<Logger>()
      ? getIt<Logger>()
      : Logger();
  final Map<String, List<api.TopicMetadata>> _cache = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, String> _errors = {};

  List<api.TopicMetadata>? getTopics(ClusterProfile cluster) =>
      _cache[cluster.name];

  bool hasCachedTopics(ClusterProfile cluster) =>
      _cache.containsKey(cluster.name);

  bool isLoading(ClusterProfile cluster) => _isLoading[cluster.name] ?? false;

  String? errorFor(ClusterProfile cluster) => _errors[cluster.name];

  Future<void> fetchTopics(ClusterProfile cluster, {bool force = false}) async {
    if (!force && _cache.containsKey(cluster.name)) return;

    _errors.remove(cluster.name);
    _isLoading[cluster.name] = true;
    notifyListeners();

    try {
      final topics = await _metadataService.fetchTopics(profile: cluster);
      _cache[cluster.name] = topics;
    } catch (e, st) {
      _logger.e(
        "Error fetching topics for ${cluster.name}",
        error: e,
        stackTrace: st,
      );
      _errors[cluster.name] = e.toString();
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
