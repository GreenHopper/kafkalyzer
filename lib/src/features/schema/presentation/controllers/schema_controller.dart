import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'dart:convert';
import 'package:kafkalyzer/src/services/schema_registry_service.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

class SchemaController extends ChangeNotifier {
  final SchemaRegistryService _registryService;

  SchemaController({SchemaRegistryService? registryService})
    : _registryService = registryService ?? getIt<SchemaRegistryService>();

  final Map<String, List<String>> _cache = {};
  final Map<String, bool> _isLoading = {};

  List<String>? getSchemas(ClusterProfile cluster) => _cache[cluster.name];

  bool isLoading(ClusterProfile cluster) => _isLoading[cluster.name] ?? false;

  Future<void> fetchSchemas(ClusterProfile cluster, {bool force = false}) async {
    if (!force && _cache.containsKey(cluster.name)) return;

    _isLoading[cluster.name] = true;
    notifyListeners();

    try {
      final schemas = await _registryService.fetchSubjects(profile: cluster);
      _cache[cluster.name] = schemas;
    } catch (e) {
      debugPrint("Error fetching schemas for ${cluster.name}: $e");
      // Optionally handle error state
    } finally {
      _isLoading[cluster.name] = false;
      notifyListeners();
    }
  }

  final Map<String, List<String>> _fieldsCache = {};

  void clearCache(ClusterProfile cluster) {
    _cache.remove(cluster.name);
    _fieldsCache.removeWhere((key, _) => key.startsWith("${cluster.name}_"));
    notifyListeners();
  }

  Future<List<String>> fetchSchemaFields(ClusterProfile cluster, String topic) async {
    final cacheKey = "${cluster.name}_${topic}_value";
    if (_fieldsCache.containsKey(cacheKey)) {
      return _fieldsCache[cacheKey]!;
    }

    try {
      // Try to fetch value schema first
      final schemaJson = await _registryService.fetchSchema(profile: cluster, subject: "$topic-value");
      final schema = parseSchemaFields(schemaJson);
      _fieldsCache[cacheKey] = schema;
      return schema;
    } catch (e) {
      debugPrint("Failed to fetch schema fields for $topic: $e");
      return [];
    }
  }

  Future<String> fetchSchemaContent(ClusterProfile cluster, String subject) {
    return _registryService.fetchSchema(profile: cluster, subject: subject);
  }

  List<String> parseSchemaFields(String jsonString) {
    try {
      final map = jsonDecode(jsonString);
      if (map is Map<String, dynamic> && map.containsKey('fields')) {
        final namedRecords = _collectNamedRecords(map, {});
        return _extractFieldPaths(map['fields'] as List, "", namedRecords, {});
      }
    } catch (e) {
      debugPrint("Error parsing schema JSON: $e");
    }
    return [];
  }

  Map<String, List> _collectNamedRecords(dynamic node, Map<String, List> map) {
    if (node is Map<String, dynamic>) {
      if (node['type'] == 'record' && node['name'] != null && node['fields'] != null) {
        final name = node['name'].toString();
        map[name] = node['fields'] as List;

        if (node['namespace'] != null) {
          final fullName = "${node['namespace']}.$name";
          map[fullName] = node['fields'] as List;
        }
      }
      for (var v in node.values) {
        _collectNamedRecords(v, map);
      }
    } else if (node is List) {
      for (var item in node) {
        _collectNamedRecords(item, map);
      }
    }
    return map;
  }

  List<String> _extractFieldPaths(List fields, String prefix, Map<String, List> namedRecords, Set<String> visited) {
    List<String> paths = [];
    for (var f in fields) {
      if (f is! Map<String, dynamic>) continue;
      final name = f['name'] as String?;
      if (name == null) continue;

      final currentPath = prefix.isEmpty ? name : "$prefix.$name";
      paths.add(currentPath);

      if (f.containsKey('type')) {
        paths.addAll(_extractPathsFromType(f['type'], currentPath, namedRecords, visited));
      }
    }
    return paths;
  }

  List<String> _extractPathsFromType(
    dynamic typeObj,
    String currentPath,
    Map<String, List> namedRecords,
    Set<String> visited,
  ) {
    List<String> paths = [];

    if (typeObj is String) {
      if (namedRecords.containsKey(typeObj) && !visited.contains(typeObj)) {
        final newVisited = Set<String>.from(visited)..add(typeObj);
        paths.addAll(_extractFieldPaths(namedRecords[typeObj]!, currentPath, namedRecords, newVisited));
      }
    } else if (typeObj is Map<String, dynamic>) {
      final typeName = typeObj['name'] as String?;

      var currentVisited = visited;
      if (typeName != null) {
        if (currentVisited.contains(typeName)) return paths;
        currentVisited = Set<String>.from(currentVisited)..add(typeName);
      }

      if (typeObj['type'] == 'record' && typeObj.containsKey('fields')) {
        paths.addAll(_extractFieldPaths(typeObj['fields'] as List, currentPath, namedRecords, currentVisited));
      } else if (typeObj['type'] == 'array' && typeObj.containsKey('items')) {
        paths.addAll(_extractPathsFromType(typeObj['items'], currentPath, namedRecords, currentVisited));
      }
    } else if (typeObj is List) {
      for (var t in typeObj) {
        paths.addAll(_extractPathsFromType(t, currentPath, namedRecords, visited));
      }
    }
    return paths;
  }
}
