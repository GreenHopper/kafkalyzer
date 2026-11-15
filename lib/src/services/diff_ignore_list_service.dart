import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiffIgnoreLoadResult {
  final List<String> paths;
  final bool unreadable;

  const DiffIgnoreLoadResult({required this.paths, required this.unreadable});
}

enum DiffIgnoreSaveStatus { saved, emptyPath, duplicate, saveFailed }

/// Persists per-topic ignored JSON field paths for [MessagesDiffView].
class DiffIgnoreListService extends ChangeNotifier {
  static const String _keyPrefix = 'diff_ignore_paths_';

  final Future<SharedPreferences> Function() _prefsProvider;
  final Map<String, List<String>> _cache = {};
  final Map<String, bool> _unreadableTopics = {};

  DiffIgnoreListService({
    SharedPreferences? prefs,
    Future<SharedPreferences> Function()? prefsProvider,
  }) : _prefsProvider =
           prefsProvider ??
           (prefs != null ? () async => prefs : SharedPreferences.getInstance);

  static String storageKey(String topic) => '$_keyPrefix$topic';

  List<String> getPathsSync(String topic) => _cache[topic] ?? const [];

  bool hasLoadError(String topic) => _unreadableTopics[topic] ?? false;

  Future<DiffIgnoreLoadResult> load(String topic) async {
    try {
      final prefs = await _prefsProvider();
      final key = storageKey(topic);
      final raw = prefs.get(key);
      if (raw == null) {
        _cache[topic] = const [];
        _unreadableTopics[topic] = false;
        return const DiffIgnoreLoadResult(paths: [], unreadable: false);
      }
      if (raw is List && raw.every((e) => e is String)) {
        final paths = List<String>.unmodifiable(raw.cast<String>());
        _cache[topic] = paths;
        _unreadableTopics[topic] = false;
        return DiffIgnoreLoadResult(paths: paths, unreadable: false);
      }
      _cache[topic] = const [];
      _unreadableTopics[topic] = true;
      return const DiffIgnoreLoadResult(paths: [], unreadable: true);
    } catch (e) {
      debugPrint('DiffIgnoreListService: failed to load "$topic": $e');
      _cache[topic] = const [];
      _unreadableTopics[topic] = true;
      return const DiffIgnoreLoadResult(paths: [], unreadable: true);
    }
  }

  Future<DiffIgnoreSaveStatus> addPath(String topic, String rawPath) async {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return DiffIgnoreSaveStatus.emptyPath;
    }
    if (!_cache.containsKey(topic)) {
      await load(topic);
    }
    final current = _cache[topic] ?? const [];
    if (current.contains(trimmed)) {
      return DiffIgnoreSaveStatus.duplicate;
    }
    final next = List<String>.unmodifiable([...current, trimmed]);
    return _persist(topic, next);
  }

  Future<DiffIgnoreSaveStatus> removePath(String topic, String path) async {
    if (!_cache.containsKey(topic)) {
      await load(topic);
    }
    final current = _cache[topic] ?? const [];
    final next = List<String>.unmodifiable(current.where((p) => p != path));
    return _persist(topic, next);
  }

  Future<DiffIgnoreSaveStatus> _persist(String topic, List<String> next) async {
    try {
      final prefs = await _prefsProvider();
      final ok = await prefs.setStringList(storageKey(topic), next);
      if (!ok) {
        return DiffIgnoreSaveStatus.saveFailed;
      }
      _cache[topic] = next;
      _unreadableTopics[topic] = false;
      notifyListeners();
      return DiffIgnoreSaveStatus.saved;
    } catch (e) {
      debugPrint('DiffIgnoreListService: failed to save "$topic": $e');
      return DiffIgnoreSaveStatus.saveFailed;
    }
  }
}
