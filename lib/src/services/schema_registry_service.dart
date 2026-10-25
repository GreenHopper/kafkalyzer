import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;

class SchemaRegistryService {
  Future<List<String>> fetchSubjects({required ClusterProfile profile}) {
    return api.fetchSubjects(profile: profile);
  }

  Future<String> fetchSchema({
    required ClusterProfile profile,
    required String subject,
    int? version,
  }) {
    return api.fetchSchema(
      profile: profile,
      subject: subject,
      version: version,
    );
  }

  Future<List<int>> fetchSchemaVersions({
    required ClusterProfile profile,
    required String subject,
  }) {
    return api.fetchSchemaVersions(profile: profile, subject: subject);
  }

  Future<api.SchemaCompatibilityResult> checkSchemaCompatibility({
    required ClusterProfile profile,
    required String subject,
    int? version,
    required String schema,
  }) {
    return api.checkSchemaCompatibility(
      profile: profile,
      subject: subject,
      version: version,
      schema: schema,
    );
  }

  Future<List<String>> resolveAssociatedTopics({
    required String subject,
    required List<String> availableTopics,
  }) {
    return api.resolveAssociatedTopicsForSubject(
      subject: subject,
      availableTopics: availableTopics,
    );
  }
}
