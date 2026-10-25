import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents the persisted tab session state for a Kafka cluster.
@immutable
class ClusterTabSession {
  final String clusterName;
  final List<String> openTopicNames;
  final String? activeTopicName;

  const ClusterTabSession({
    required this.clusterName,
    required this.openTopicNames,
    this.activeTopicName,
  });

  Map<String, dynamic> toJson() => {
    'clusterName': clusterName,
    'openTopicNames': openTopicNames,
    'activeTopicName': activeTopicName,
  };

  factory ClusterTabSession.fromJson(Map<String, dynamic> json) {
    final rawTopics = json['openTopicNames'] as List? ?? [];
    return ClusterTabSession(
      clusterName: json['clusterName'] as String? ?? '',
      openTopicNames: rawTopics.whereType<String>().toList(),
      activeTopicName: json['activeTopicName'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClusterTabSession &&
          runtimeType == other.runtimeType &&
          clusterName == other.clusterName &&
          listEquals(openTopicNames, other.openTopicNames) &&
          activeTopicName == other.activeTopicName;

  @override
  int get hashCode =>
      Object.hash(clusterName, Object.hashAll(openTopicNames), activeTopicName);
}

/// Service that persists and restores open topic tabs per cluster.
class SessionRestoreService extends ChangeNotifier {
  static const String _keyPrefix = 'cluster_session_tabs_';
  static const String prefRestoreEnabled = 'restore_open_tabs_on_startup';

  final SharedPreferences? _prefsInstance;

  SessionRestoreService({SharedPreferences? prefs}) : _prefsInstance = prefs;

  Future<SharedPreferences> _getPrefs() async {
    return _prefsInstance ?? await SharedPreferences.getInstance();
  }

  static String storageKey(String clusterName) => '$_keyPrefix$clusterName';

  /// Whether automatic tab restoration on startup is enabled. Defaults to true.
  Future<bool> isRestorationEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(prefRestoreEnabled) ?? true;
  }

  /// Sets whether automatic tab restoration on startup is enabled.
  Future<void> setRestorationEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(prefRestoreEnabled, enabled);
    notifyListeners();
  }

  /// Retrieves the saved tab session for a specific cluster.
  Future<ClusterTabSession?> getSession(String clusterName) async {
    final prefs = await _getPrefs();
    final rawJson = prefs.getString(storageKey(clusterName));
    if (rawJson == null) return null;

    try {
      return ClusterTabSession.fromJson(
        jsonDecode(rawJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Persists the list of open topic names and active topic name for a cluster.
  Future<void> saveSession(
    String clusterName, {
    required List<String> openTopicNames,
    String? activeTopicName,
  }) async {
    final prefs = await _getPrefs();
    final session = ClusterTabSession(
      clusterName: clusterName,
      openTopicNames: openTopicNames,
      activeTopicName: activeTopicName,
    );
    await prefs.setString(
      storageKey(clusterName),
      jsonEncode(session.toJson()),
    );
    notifyListeners();
  }

  /// Clears the saved tab session for a cluster.
  Future<void> clearSession(String clusterName) async {
    final prefs = await _getPrefs();
    await prefs.remove(storageKey(clusterName));
    notifyListeners();
  }
}
