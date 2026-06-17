import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

bool hasSchema(SchemaController controller, ClusterProfile cluster, String topicName) {
  final schemas = controller.getSchemas(cluster);
  if (schemas == null) return false;
  return schemas.contains("$topicName-key") || schemas.contains("$topicName-value");
}

String splitPolicy(String policy) {
  if (policy.length > 15) return "Policy: ...";
  return policy;
}

String formatRetention(String ms) {
  try {
    final val = int.parse(ms);
    if (val == -1) return "Infinite";
    final hours = val / 3600000;
    if (hours >= 24) {
      return "${(hours / 24).toStringAsFixed(1)} days";
    }
    return "${hours.toStringAsFixed(1)} hrs";
  } catch (_) {
    return ms;
  }
}
