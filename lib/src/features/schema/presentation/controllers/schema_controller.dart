import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/local_schema.dart';
import 'package:kafkalyzer/src/rust/api/schema_registry.dart' as api;
import 'package:kafkalyzer/src/features/schema/data/local_schema_assignment_service.dart';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:logger/logger.dart';

sealed class SchemaTypeState {
  const SchemaTypeState();
}

class SchemaTypeKnown extends SchemaTypeState {
  final api.SchemaKindDto kind;
  final String? otherName;

  const SchemaTypeKnown(this.kind, [this.otherName]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchemaTypeKnown &&
          kind == other.kind &&
          otherName == other.otherName;

  @override
  int get hashCode => Object.hash(kind, otherName);
}

class SchemaTypeNotLoaded extends SchemaTypeState {
  const SchemaTypeNotLoaded();

  @override
  bool operator ==(Object other) => other is SchemaTypeNotLoaded;

  @override
  int get hashCode => runtimeType.hashCode;
}

class SchemaTypeFailed extends SchemaTypeState {
  const SchemaTypeFailed();

  @override
  bool operator ==(Object other) => other is SchemaTypeFailed;

  @override
  int get hashCode => runtimeType.hashCode;
}

class _AssociationCacheEntry {
  final List<String> subjects;
  final List<String> topics;
  final List<api.SubjectAssociationDto> associations;

  _AssociationCacheEntry({
    required this.subjects,
    required this.topics,
    required this.associations,
  });
}

class SchemaController extends ChangeNotifier {
  final SchemaRegistryService _registryService;
  final LocalSchemaAssignmentService? _localSchemaService;
  final Logger _logger = getIt.isRegistered<Logger>()
      ? getIt<Logger>()
      : Logger();

  SchemaController({
    SchemaRegistryService? registryService,
    LocalSchemaAssignmentService? localSchemaService,
  }) : _registryService = registryService ?? getIt<SchemaRegistryService>(),
       _localSchemaService =
           localSchemaService ??
           (getIt.isRegistered<LocalSchemaAssignmentService>()
               ? getIt<LocalSchemaAssignmentService>()
               : null) {
    _localSchemaService?.addListener(_onLocalSchemaChanged);
  }

  void _onLocalSchemaChanged() {
    _fieldsCache.clear();
  }

  @override
  void dispose() {
    _localSchemaService?.removeListener(_onLocalSchemaChanged);
    super.dispose();
  }

  final Map<String, List<String>> _cache = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, String> _errors = {};
  final Map<String, Object> _errorObjects = {};

  List<String>? getSchemas(ClusterProfile cluster) => _cache[cluster.name];

  bool isLoading(ClusterProfile cluster) => _isLoading[cluster.name] ?? false;

  String? errorFor(ClusterProfile cluster) => _errors[cluster.name];

  Object? errorObjectFor(ClusterProfile cluster) => _errorObjects[cluster.name];

  Future<void> fetchSchemas(
    ClusterProfile cluster, {
    bool force = false,
  }) async {
    if (cluster.schemaRegistryUrl?.trim().isEmpty ?? true) {
      _errors.remove(cluster.name);
      _errorObjects.remove(cluster.name);
      _cache[cluster.name] = const [];
      notifyListeners();
      return;
    }

    if (!force && _cache.containsKey(cluster.name)) return;

    _errors.remove(cluster.name);
    _errorObjects.remove(cluster.name);
    _isLoading[cluster.name] = true;
    notifyListeners();

    try {
      final schemas = await _registryService.fetchSubjects(profile: cluster);
      _cache[cluster.name] = schemas;
    } catch (e, st) {
      _logger.e(
        "Error fetching schemas for ${cluster.name}",
        error: e,
        stackTrace: st,
      );
      _errors[cluster.name] = e.toString();
      _errorObjects[cluster.name] = e;
    } finally {
      _isLoading[cluster.name] = false;
      notifyListeners();
    }
  }

  final Map<String, List<String>> _fieldsCache = {};
  final Map<(String, String, int?), api.SubjectSchemaViewDto> _viewCache = {};
  final Set<(String, String, int?)> _failedViews = {};
  final Map<String, String> _globalCompatibilityCache = {};
  final Map<(String, String), String?> _subjectCompatibilityCache = {};
  final Map<String, _AssociationCacheEntry> _associationCache = {};

  void clearCache(ClusterProfile cluster) {
    _cache.remove(cluster.name);
    _fieldsCache.removeWhere((key, _) => key.startsWith("${cluster.name}_"));
    _viewCache.removeWhere((key, _) => key.$1 == cluster.name);
    _failedViews.removeWhere((key) => key.$1 == cluster.name);
    _globalCompatibilityCache.remove(cluster.name);
    _subjectCompatibilityCache.removeWhere((key, _) => key.$1 == cluster.name);
    _associationCache.remove(cluster.name);
    notifyListeners();
  }

  SchemaTypeState schemaTypeFor(
    ClusterProfile cluster,
    String subject, {
    int? version,
  }) {
    final key = (cluster.name, subject, version);
    final view = _viewCache[key];
    if (view != null) {
      return SchemaTypeKnown(
        view.schema.schemaType,
        view.schema.otherSchemaType,
      );
    }
    if (_failedViews.contains(key)) {
      return const SchemaTypeFailed();
    }
    return const SchemaTypeNotLoaded();
  }

  Future<api.SubjectSchemaViewDto> fetchSubjectSchemaView(
    ClusterProfile cluster,
    String subject, {
    int? version,
    bool force = false,
  }) async {
    final key = (cluster.name, subject, version);
    if (!force && _viewCache.containsKey(key)) {
      return _viewCache[key]!;
    }

    try {
      final view = await _registryService.fetchSubjectSchemaView(
        profile: cluster,
        subject: subject,
        version: version,
      );
      _failedViews.remove(key);
      _viewCache[key] = view;
      notifyListeners();
      return view;
    } catch (e) {
      _failedViews.add(key);
      notifyListeners();
      rethrow;
    }
  }

  String? globalCompatibilityFor(ClusterProfile cluster) =>
      _globalCompatibilityCache[cluster.name];

  String? subjectCompatibilityFor(ClusterProfile cluster, String subject) =>
      _subjectCompatibilityCache[(cluster.name, subject)];

  bool hasSubjectCompatibility(ClusterProfile cluster, String subject) =>
      _subjectCompatibilityCache.containsKey((cluster.name, subject));

  Future<String> fetchGlobalCompatibility(
    ClusterProfile cluster, {
    bool force = false,
  }) async {
    if (!force && _globalCompatibilityCache.containsKey(cluster.name)) {
      return _globalCompatibilityCache[cluster.name]!;
    }
    final level = await _registryService.fetchGlobalCompatibility(
      profile: cluster,
    );
    _globalCompatibilityCache[cluster.name] = level;
    notifyListeners();
    return level;
  }

  Future<String?> fetchSubjectCompatibility(
    ClusterProfile cluster,
    String subject, {
    bool force = false,
  }) async {
    final key = (cluster.name, subject);
    if (!force && _subjectCompatibilityCache.containsKey(key)) {
      return _subjectCompatibilityCache[key];
    }
    final level = await _registryService.fetchSubjectCompatibility(
      profile: cluster,
      subject: subject,
    );
    _subjectCompatibilityCache[key] = level;
    notifyListeners();
    return level;
  }

  List<api.SubjectAssociationDto> associatedTopics(
    ClusterProfile cluster,
    List<String> topics,
  ) {
    final subjects = _cache[cluster.name] ?? const <String>[];
    final cached = _associationCache[cluster.name];
    if (cached != null &&
        listEquals(cached.subjects, subjects) &&
        listEquals(cached.topics, topics)) {
      return cached.associations;
    }
    final associations = _registryService.associateSubjects(
      subjects: subjects,
      topics: topics,
    );
    _associationCache[cluster.name] = _AssociationCacheEntry(
      subjects: List<String>.of(subjects),
      topics: List<String>.of(topics),
      associations: associations,
    );
    return associations;
  }

  Future<List<String>> fetchSchemaFields(
    ClusterProfile cluster,
    String topic,
  ) async {
    final cacheKey = "${cluster.name}_${topic}_value";
    if (_fieldsCache.containsKey(cacheKey)) {
      return _fieldsCache[cacheKey]!;
    }

    final localService = _localSchemaService;
    final stored = localService != null
        ? await localService.getForTopic(cluster.name, topic)
        : null;
    final valueAssignment = stored?.value;

    if (valueAssignment?.mode == LocalSchemaModeDto.always &&
        localService != null) {
      final paths = await _fetchLocalSchemaFieldPaths(
        localService,
        cluster.name,
        topic,
      );
      _fieldsCache[cacheKey] = paths;
      return paths;
    }

    try {
      if (cluster.schemaRegistryUrl?.trim().isNotEmpty ?? false) {
        final view = await fetchSubjectSchemaView(cluster, "$topic-value");
        final paths = view.fields.fields.map((f) => f.path).toList();
        if (paths.isNotEmpty || valueAssignment == null) {
          _fieldsCache[cacheKey] = paths;
          return paths;
        }
      }
    } catch (e, st) {
      _logger.w(
        "Failed to fetch schema fields for $topic",
        error: e,
        stackTrace: st,
      );
    }

    if (valueAssignment != null && localService != null) {
      final paths = await _fetchLocalSchemaFieldPaths(
        localService,
        cluster.name,
        topic,
      );
      if (paths.isNotEmpty) {
        _fieldsCache[cacheKey] = paths;
      }
      return paths;
    }

    return [];
  }

  Future<List<String>> _fetchLocalSchemaFieldPaths(
    LocalSchemaAssignmentService localService,
    String clusterId,
    String topic,
  ) async {
    try {
      final state = await localService.stateFor(
        clusterId,
        topic,
        LocalSchemaSide.value,
      );
      final fields = state.info?.fields?.fields;
      if (fields == null) {
        return [];
      }
      return fields.map((f) => f.path).toList();
    } catch (e, st) {
      _logger.w(
        "Failed to inspect local schema fields for $topic",
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  Future<String> fetchSchemaContent(
    ClusterProfile cluster,
    String subject, {
    int? version,
  }) {
    return _registryService.fetchSchema(
      profile: cluster,
      subject: subject,
      version: version,
    );
  }

  /// Version numbers of a subject, so a schema recorded by a message can be shown
  /// at exactly that version and switched from there.
  Future<List<int>> fetchSchemaVersions(
    ClusterProfile cluster,
    String subject,
  ) {
    return _registryService.fetchSchemaVersions(
      profile: cluster,
      subject: subject,
    );
  }

  Future<api.SchemaCompatibilityResult> checkCompatibility(
    ClusterProfile cluster,
    String subject, {
    int? version,
    required String schema,
  }) {
    return _registryService.checkSchemaCompatibility(
      profile: cluster,
      subject: subject,
      version: version,
      schema: schema,
    );
  }

  Future<List<String>> getAssociatedTopics(
    String subject,
    List<String> availableTopics,
  ) {
    return _registryService.resolveAssociatedTopics(
      subject: subject,
      availableTopics: availableTopics,
    );
  }
}
