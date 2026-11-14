import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';

class ScriptRepository {
  static const _storageKey = 'saved_scripts_v1';

  StoreStatus _storeStatus = const StoreStatus.ok();
  List<dynamic> _rawUnreadable = const [];
  String? _backupWrittenForRaw;
  String? _lastBackupPath;

  StoreStatus get storeStatus => _storeStatus;

  Future<String?> _ensureBackup(String rawJson) async {
    if (_backupWrittenForRaw != rawJson) {
      _lastBackupPath = await writeStoreBackup(_storageKey, rawJson);
      _backupWrittenForRaw = rawJson;
    }
    return _lastBackupPath;
  }

  Future<void> discardUnreadable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    _rawUnreadable = const [];
    _backupWrittenForRaw = null;
    _lastBackupPath = null;
    _storeStatus = const StoreStatus.ok();
  }

  Future<List<Script>> getScripts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) {
      _rawUnreadable = const [];
      _backupWrittenForRaw = null;
      _lastBackupPath = null;
      _storeStatus = const StoreStatus.ok();
      return [];
    }

    final parsed = await parseStoredList<Script>(
      jsonString,
      (e) async => Script.fromJson(Map<String, dynamic>.from(e as Map)),
    );

    if (parsed.storeUnreadable) {
      final backupPath = await _ensureBackup(jsonString);
      _storeStatus = StoreStatus.unreadable(backupPath);
      throw StoredDataUnreadableException(_storageKey, backupPath: backupPath);
    }

    _backupWrittenForRaw = null;
    _lastBackupPath = null;
    _rawUnreadable = List<dynamic>.from(parsed.rawUnreadable);
    _storeStatus = _rawUnreadable.isNotEmpty
        ? StoreStatus.partiallyUnreadable(_rawUnreadable.length)
        : const StoreStatus.ok();

    return parsed.items;
  }

  Future<void> saveScript(Script script) async {
    final scripts = await getScripts();
    final index = scripts.indexWhere((s) => s.id == script.id);

    List<Script> updatedScripts;
    if (index >= 0) {
      updatedScripts = List.from(scripts)..[index] = script;
    } else {
      updatedScripts = [...scripts, script];
    }

    await _saveList(updatedScripts);
  }

  Future<void> deleteScript(String id) async {
    final scripts = await getScripts();
    final updatedScripts = scripts.where((s) => s.id != id).toList();
    await _saveList(updatedScripts);
  }

  Future<void> _saveList(List<Script> scripts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = <dynamic>[
      ...scripts.map((s) => s.toJson()),
      ..._rawUnreadable,
    ];
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}
