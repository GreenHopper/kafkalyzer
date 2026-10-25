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

  /// Loads all saved presets for a given cluster and topic.
  Future<List<TopicSearchPreset>> getPresets({
    required String clusterName,
    required String topicName,
  }) async {
    final prefs = await _getPrefs();
    final rawList =
        prefs.getStringList(storageKey(clusterName, topicName)) ?? [];

    final list = rawList
        .map((str) {
          try {
            return TopicSearchPreset.fromJson(
              jsonDecode(str) as Map<String, dynamic>,
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<TopicSearchPreset>()
        .toList();

    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Saves or updates a preset.
  /// If a preset with the same id or name already exists, it is overwritten.
  Future<void> savePreset(TopicSearchPreset preset) async {
    final prefs = await _getPrefs();
    final key = storageKey(preset.clusterName, preset.topicName);
    final existing = await getPresets(
      clusterName: preset.clusterName,
      topicName: preset.topicName,
    );

    final index = existing.indexWhere(
      (p) => p.id == preset.id || p.name == preset.name,
    );
    if (index >= 0) {
      existing[index] = preset;
    } else {
      existing.add(preset);
    }

    await prefs.setStringList(
      key,
      existing.map((p) => jsonEncode(p.toJson())).toList(),
    );
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
    final existing = await getPresets(
      clusterName: clusterName,
      topicName: topicName,
    );

    existing.removeWhere((p) => p.id == presetId);
    await prefs.setStringList(
      key,
      existing.map((p) => jsonEncode(p.toJson())).toList(),
    );
    notifyListeners();
  }
}
