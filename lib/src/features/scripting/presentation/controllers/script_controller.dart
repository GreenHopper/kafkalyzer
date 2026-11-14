import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';

class ScriptController extends ChangeNotifier {
  final ScriptRepository _repository = getIt<ScriptRepository>();

  List<Script> _scripts = [];
  List<Script> get scripts => List.unmodifiable(_scripts);

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  StoreStatus get storeStatus => _repository.storeStatus;

  ScriptController() {
    loadScripts();
  }

  void _requireReadableStore() {
    if (storeStatus.isUnreadable) {
      throw StoredDataUnreadableException(
        'saved_scripts_v1',
        backupPath: storeStatus.backupPath,
      );
    }
  }

  Future<void> loadScripts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _scripts = await _repository.getScripts();
      _scripts.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
    } on StoredDataUnreadableException {
      _scripts = [];
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> discardUnreadable() async {
    await _repository.discardUnreadable();
    await loadScripts();
  }

  Future<void> saveScript(Script script) async {
    _requireReadableStore();
    await _repository.saveScript(script);
    await loadScripts();
  }

  Future<Script> createScript(String name) async {
    _requireReadableStore();
    final newScript = Script(id: const Uuid().v4(), name: name);
    await saveScript(newScript);
    return newScript;
  }

  Future<void> duplicateScript(Script script) async {
    _requireReadableStore();
    final newScript = script.copyWith(
      id: const Uuid().v4(),
      name: "${script.name} (Copy)",
    );
    await saveScript(newScript);
  }

  Future<void> deleteScript(String id) async {
    _requireReadableStore();
    await _repository.deleteScript(id);
    await loadScripts();
  }

  bool validateScript(Script script) {
    // Validate placeholders logic could go here
    return script.name.isNotEmpty && script.steps.isNotEmpty;
  }

  Future<void> importScripts(String jsonString) async {
    _requireReadableStore();
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final importedScripts = jsonList.map((e) => Script.fromJson(e)).toList();

      for (final script in importedScripts) {
        // Optionally check for duplicates or generate new IDs
        // For now, we'll generate new IDs to avoid conflicts
        final newScript = script.copyWith(
          id: const Uuid().v4(),
          name: "${script.name} (Imported)",
          outputDirectory: null,
        );
        await _repository.saveScript(newScript);
      }
      await loadScripts();
    } catch (e) {
      debugPrint("Error importing scripts: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String exportScript(Script script) {
    // Export as a list, even if singular, for consistency
    final jsonList = [script.toJson()];
    return jsonEncode(jsonList);
  }
}
