import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';

class ScriptRepository {
  static const _storageKey = 'saved_scripts_v1';

  Future<List<Script>> getScripts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => Script.fromJson(e)).toList();
    } catch (e) {
      // Handle corruption or version mismatch by returning empty or logging
      return [];
    }
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
    final jsonList = scripts.map((s) => s.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(jsonList));
  }
}
