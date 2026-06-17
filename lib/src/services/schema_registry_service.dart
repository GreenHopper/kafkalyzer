import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;

class SchemaRegistryService {
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) {
    return api.fetchSubjects(profile: profile);
  }

  Future<String> fetchSchema({
    required ClusterProfile profile,
    required String subject,
  }) {
    return api.fetchSchema(profile: profile, subject: subject);
  }
}
