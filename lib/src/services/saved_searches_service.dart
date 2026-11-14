import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:kafkalyzer/src/features/search/models/topic_search_preset.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages persistence, retrieval, updating, and deletion of per-topic search presets.
class SavedSearchesService extends ChangeNotifier {
  static const String _keyPrefix = 'search_presets_';
  final SharedPreferences? _prefsInstance;

  SavedSearchesService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  /// Derives storage key namespaced by cluster name and topic name.
  static String storageKey(String clusterName, String topicName) =>
      '$_keyPrefix${clusterName}_$topicName';

  ({List<TopicSearchPreset> valid, List<String> rawUnreadable})
  _partitionPresets(List<String> rawList, String key) {
    final valid = <TopicSearchPreset>[];
    final rawUnreadable = <String>[];
    for (final str in rawList) {
      try {
        valid.add(
          TopicSearchPreset.fromJson(jsonDecode(str) as Map<String, dynamic>),
        );
      } catch (e) {
        debugPrint('SavedSearchesService: unreadable preset in "$key": $e');
        rawUnreadable.add(str);
      }
    }
    valid.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return (valid: valid, rawUnreadable: rawUnreadable);
  }

  /// Loads all saved presets for a given cluster and topic.
  Future<List<TopicSearchPreset>> getPresets({
    required String clusterName,
    required String topicName,
  }) async {
    final prefs = await _getPrefs();
    final key = storageKey(clusterName, topicName);
    final rawList = prefs.getStringList(key) ?? [];
    return _partitionPresets(rawList, key).valid;
  }

  /// Saves or updates a preset.
  /// If a preset with the same id or name already exists, it is overwritten.
  Future<void> savePreset(TopicSearchPreset preset) async {
    final prefs = await _getPrefs();
    final key = storageKey(preset.clusterName, preset.topicName);
    final rawList = prefs.getStringList(key) ?? [];
    final partitioned = _partitionPresets(rawList, key);
    final existing = partitioned.valid;

    final index = existing.indexWhere(
      (p) => p.id == preset.id || p.name == preset.name,
    );
    if (index >= 0) {
      existing[index] = preset;
    } else {
      existing.add(preset);
    }

    await prefs.setStringList(key, [
      ...existing.map((p) => jsonEncode(p.toJson())),
      ...partitioned.rawUnreadable,
    ]);
    notifyListeners();
  }

  /// Deletes a preset by its id.
  Future<void> deletePreset({
    required String clusterName,
    required String topicName,
    required String presetId,
  }) async {
    final prefs = await _getPrefs();
    final key = storageKey(clusterName, topicName);
    final rawList = prefs.getStringList(key) ?? [];
    final partitioned = _partitionPresets(rawList, key);
    final existing = partitioned.valid;

    existing.removeWhere((p) => p.id == presetId);
    await prefs.setStringList(key, [
      ...existing.map((p) => jsonEncode(p.toJson())),
      ...partitioned.rawUnreadable,
    ]);
    notifyListeners();
  }
}
