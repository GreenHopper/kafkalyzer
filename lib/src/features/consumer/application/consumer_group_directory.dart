/// Session-only in-memory record of the consumer group IDs last loaded for
/// each cluster by [ConsumerLagView].
///
/// Never persisted across app restarts. `idsFor(clusterName)` returns `null`
/// when Consumer Lag has not yet succeeded for that cluster in this session.
class ConsumerGroupDirectory {
  final Map<String, List<String>> _byCluster = {};

  void record(String clusterName, Iterable<String> groupIds) {
    _byCluster[clusterName] = List.unmodifiable(groupIds);
  }

  List<String>? idsFor(String clusterName) => _byCluster[clusterName];
}
