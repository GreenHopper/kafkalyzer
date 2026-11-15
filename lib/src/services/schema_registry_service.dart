import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;

/// Maps a Schema Registry error (including structured [api.SchemaRegistryErrorDto])
/// to a localized user-facing message.
String describeSchemaRegistryError(AppLocalizations l10n, Object error) {
  if (error is! api.SchemaRegistryErrorDto) {
    return error.toString();
  }
  switch (error.kind) {
    case api.SchemaRegistryErrorKindDto.notConfigured:
      return l10n.schemaRegistryErrorNotConfigured;
    case api.SchemaRegistryErrorKindDto.invalidUrl:
      return l10n.schemaRegistryErrorInvalidUrl(error.detail);
    case api.SchemaRegistryErrorKindDto.unauthorized:
      return l10n.schemaRegistryErrorUnauthorized;
    case api.SchemaRegistryErrorKindDto.forbidden:
      return l10n.schemaRegistryErrorForbidden;
    case api.SchemaRegistryErrorKindDto.notFound:
      return l10n.schemaRegistryErrorNotFound;
    case api.SchemaRegistryErrorKindDto.timeout:
      return l10n.schemaRegistryErrorTimeout;
    case api.SchemaRegistryErrorKindDto.unreachable:
      return l10n.schemaRegistryErrorUnreachable(error.detail);
    case api.SchemaRegistryErrorKindDto.certificateRejected:
      return l10n.schemaRegistryErrorCertificateRejected(error.detail);
    case api.SchemaRegistryErrorKindDto.httpStatus:
      final status = error.status;
      if (status != null) {
        return l10n.schemaRegistryErrorHttpStatus(status, error.detail);
      }
      return l10n.schemaRegistryErrorHttpStatusNoCode(error.detail);
    case api.SchemaRegistryErrorKindDto.invalidResponse:
      return l10n.schemaRegistryErrorInvalidResponse(error.detail);
  }
}

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

  Future<api.SubjectSchemaViewDto> fetchSubjectSchemaView({
    required ClusterProfile profile,
    required String subject,
    int? version,
  }) {
    return api.fetchSubjectSchemaView(
      profile: profile,
      subject: subject,
      version: version,
    );
  }

  Future<String> fetchGlobalCompatibility({required ClusterProfile profile}) {
    return api.fetchGlobalCompatibility(profile: profile);
  }

  Future<String?> fetchSubjectCompatibility({
    required ClusterProfile profile,
    required String subject,
  }) {
    return api.fetchSubjectCompatibility(profile: profile, subject: subject);
  }

  List<api.SubjectAssociationDto> associateSubjects({
    required List<String> subjects,
    required List<String> topics,
  }) {
    return api.associateSubjects(subjects: subjects, topics: topics);
  }
}
