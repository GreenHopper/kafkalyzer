import 'dart:convert';

import 'package:kafkalyzer/src/features/topic/domain/topic_list_query.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TopicListPreferences {
  final bool showInternal;
  final bool showStream;
  final TopicFilterMode filterMode;
  final TopicSortOrder sort;
  final bool groupByPrefix;
  final Set<String> favourites;

  const TopicListPreferences({
    this.showInternal = false,
    this.showStream = false,
    this.filterMode = TopicFilterMode.substring,
    this.sort = TopicSortOrder.name,
    this.groupByPrefix = false,
    this.favourites = const {},
  });

  TopicListQuery toQuery({
    String text = '',
    Set<String> collapsedGroups = const {},
  }) {
    return TopicListQuery(
      text: text,
      mode: filterMode,
      showInternal: showInternal,
      showStream: showStream,
      sort: sort,
      groupByPrefix: groupByPrefix,
      favourites: favourites,
      collapsedGroups: collapsedGroups,
    );
  }

  factory TopicListPreferences.fromQuery(TopicListQuery q) {
    return TopicListPreferences(
      showInternal: q.showInternal,
      showStream: q.showStream,
      filterMode: q.mode,
      sort: q.sort,
      groupByPrefix: q.groupByPrefix,
      favourites: Set<String>.from(q.favourites),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': 1,
    'showInternal': showInternal,
    'showStream': showStream,
    'filterMode': filterMode.name,
    'sort': sort.name,
    'groupByPrefix': groupByPrefix,
    'favourites': favourites.toList()..sort(),
  };

  factory TopicListPreferences.fromJson(Map<String, dynamic> json) {
    final filterModeRaw = json['filterMode'];
    final filterMode = TopicFilterMode.values.firstWhere(
      (e) => e.name == filterModeRaw,
      orElse: () => TopicFilterMode.substring,
    );
    final sortRaw = json['sort'];
    final sort = TopicSortOrder.values.firstWhere(
      (e) => e.name == sortRaw,
      orElse: () => TopicSortOrder.name,
    );
    final favsRaw = json['favourites'];
    final favs = <String>{};
    if (favsRaw is List) {
      for (final item in favsRaw) {
        if (item is String && item.isNotEmpty) {
          favs.add(item);
        }
      }
    }
    return TopicListPreferences(
      showInternal: json['showInternal'] is bool
          ? json['showInternal'] as bool
          : false,
      showStream: json['showStream'] is bool
          ? json['showStream'] as bool
          : false,
      filterMode: filterMode,
      sort: sort,
      groupByPrefix: json['groupByPrefix'] is bool
          ? json['groupByPrefix'] as bool
          : false,
      favourites: favs,
    );
  }
}

class TopicListPreferencesLoadResult {
  final TopicListPreferences preferences;
  final bool unreadable;

  const TopicListPreferencesLoadResult({
    required this.preferences,
    this.unreadable = false,
  });
}

typedef StoreBackupWriter =
    Future<String?> Function(String key, String rawContent);

class TopicListPreferencesService {
  final StoreBackupWriter _backupWriter;
  final Map<String, String> _pendingBackups = {};
  final Set<String> _writeBlocked = {};

  TopicListPreferencesService({StoreBackupWriter? backupWriter})
    : _backupWriter = backupWriter ?? writeStoreBackup;

  static String keyForCluster(String clusterName) =>
      'topic_list_prefs_$clusterName';

  bool isWriteBlocked(String clusterName) =>
      _writeBlocked.contains(clusterName);

  Future<TopicListPreferencesLoadResult> load(String clusterName) async {
    _pendingBackups.remove(clusterName);
    _writeBlocked.remove(clusterName);

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyForCluster(clusterName));
    if (raw == null) {
      return const TopicListPreferencesLoadResult(
        preferences: TopicListPreferences(),
      );
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _pendingBackups[clusterName] = raw;
        return const TopicListPreferencesLoadResult(
          preferences: TopicListPreferences(),
          unreadable: true,
        );
      }
      return TopicListPreferencesLoadResult(
        preferences: TopicListPreferences.fromJson(decoded),
      );
    } catch (_) {
      _pendingBackups[clusterName] = raw;
      return const TopicListPreferencesLoadResult(
        preferences: TopicListPreferences(),
        unreadable: true,
      );
    }
  }

  Future<bool> save(String clusterName, TopicListPreferences value) async {
    if (_writeBlocked.contains(clusterName)) {
      return false;
    }

    final key = keyForCluster(clusterName);
    final pendingRaw = _pendingBackups[clusterName];
    if (pendingRaw != null) {
      final backupPath = await _backupWriter(key, pendingRaw);
      if (backupPath == null) {
        _writeBlocked.add(clusterName);
        return false;
      }
      _pendingBackups.remove(clusterName);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(value.toJson()));
    return true;
  }
}
