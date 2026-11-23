import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RecentTopicEntry {
  final String topicName;
  final String clusterName;
  final DateTime lastVisited;

  const RecentTopicEntry({
    required this.topicName,
    required this.clusterName,
    required this.lastVisited,
  });

  Map<String, dynamic> toJson() => {
    'topicName': topicName,
    'clusterName': clusterName,
    'lastVisited': lastVisited.toIso8601String(),
  };

  factory RecentTopicEntry.fromJson(Map<String, dynamic> json) {
    return RecentTopicEntry(
      topicName: json['topicName'] as String,
      clusterName: json['clusterName'] as String,
      lastVisited:
          DateTime.tryParse(json['lastVisited'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecentTopicEntry &&
          runtimeType == other.runtimeType &&
          topicName == other.topicName &&
          clusterName == other.clusterName;

  @override
  int get hashCode => Object.hash(topicName, clusterName);
}

class RecentTopicsService extends ChangeNotifier {
  static const String prefKey = 'recent_topics_history';
  static const int maxRecentTopics = 10;

  final SharedPreferences? _prefsInstance;
  List<RecentTopicEntry> _recentTopics = [];
  late final Future<void> _initFuture;

  RecentTopicsService({SharedPreferences? prefs}) : _prefsInstance = prefs {
    _initFuture = _load();
  }

  List<RecentTopicEntry> get recentTopics => List.unmodifiable(_recentTopics);

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  Future<void> _load() async {
    try {
      final prefs = await _getPrefs();
      final rawList = prefs.getStringList(prefKey);
      if (rawList != null) {
        _recentTopics =
            rawList
                .map((raw) {
                  try {
                    return RecentTopicEntry.fromJson(
                      jsonDecode(raw) as Map<String, dynamic>,
                    );
                  } catch (_) {
                    return null;
                  }
                })
                .whereType<RecentTopicEntry>()
                .toList()
              ..sort((a, b) => b.lastVisited.compareTo(a.lastVisited));

        if (_recentTopics.length > maxRecentTopics) {
          _recentTopics = _recentTopics.sublist(0, maxRecentTopics);
        }
      } else {
        _recentTopics = [];
      }
    } catch (e) {
      debugPrint('Error loading recent topics: $e');
      _recentTopics = [];
    }
    notifyListeners();
  }

  Future<List<RecentTopicEntry>> loadRecentTopics() async {
    await _initFuture;
    await _load();
    return recentTopics;
  }

  List<RecentTopicEntry> getRecentTopics({String? clusterName}) {
    if (clusterName == null || clusterName.isEmpty) {
      return recentTopics;
    }
    return _recentTopics
        .where((entry) => entry.clusterName == clusterName)
        .toList();
  }

  Future<void> recordVisit({
    required String clusterName,
    required String topicName,
    DateTime? timestamp,
  }) async {
    await _initFuture;
    if (clusterName.isEmpty || topicName.isEmpty) return;

    final entry = RecentTopicEntry(
      clusterName: clusterName,
      topicName: topicName,
      lastVisited: timestamp ?? DateTime.now(),
    );

    // Remove existing match
    _recentTopics.removeWhere(
      (e) => e.clusterName == clusterName && e.topicName == topicName,
    );

    // Insert at front
    _recentTopics.insert(0, entry);

    // Cap to max length
    if (_recentTopics.length > maxRecentTopics) {
      _recentTopics = _recentTopics.sublist(0, maxRecentTopics);
    }

    notifyListeners();
    await _save();
  }

  Future<void> removeEntry(String clusterName, String topicName) async {
    await _initFuture;
    final originalLength = _recentTopics.length;
    _recentTopics.removeWhere(
      (e) => e.clusterName == clusterName && e.topicName == topicName,
    );
    if (_recentTopics.length != originalLength) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> clearHistory() async {
    await _initFuture;
    _recentTopics.clear();
    notifyListeners();
    await _save();
  }

  Future<void> _save() async {
    try {
      final prefs = await _getPrefs();
      final stringList = _recentTopics
          .map((e) => jsonEncode(e.toJson()))
          .toList();
      await prefs.setStringList(prefKey, stringList);
    } catch (e) {
      debugPrint('Error saving recent topics: $e');
    }
  }
}
