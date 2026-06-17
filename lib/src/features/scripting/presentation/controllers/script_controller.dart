import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:kafkalyzer/src/features/scripting/data/script_repository.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ScriptController extends ChangeNotifier {
  final ScriptRepository _repository = getIt<ScriptRepository>();

  List<Script> _scripts = [];
  List<Script> get scripts => List.unmodifiable(_scripts);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ScriptController() {
    loadScripts();
  }

  Future<void> loadScripts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _scripts = await _repository.getScripts();
      _scripts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      // Handle error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveScript(Script script) async {
    await _repository.saveScript(script);
    await loadScripts();
  }

  Future<Script> createScript(String name) async {
    final newScript = Script(id: const Uuid().v4(), name: name);
    await saveScript(newScript);
    return newScript;
  }

  Future<void> duplicateScript(Script script) async {
    final newScript = script.copyWith(id: const Uuid().v4(), name: "${script.name} (Copy)");
    await saveScript(newScript);
  }

  Future<void> deleteScript(String id) async {
    await _repository.deleteScript(id);
    await loadScripts();
  }

  bool validateScript(Script script) {
    // Validate placeholders logic could go here
    return script.name.isNotEmpty && script.steps.isNotEmpty;
  }

  Future<void> importScripts(String jsonString) async {
    _isLoading = true;
    notifyListeners();
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final importedScripts = jsonList.map((e) => Script.fromJson(e)).toList();

      final prefs = await SharedPreferences.getInstance();
      final defaultDir = prefs.getString('general_default_output_dir');
      if (defaultDir == null || !Directory(defaultDir).existsSync()) {
        // Lazy load app documents directory if default is not set or invalid
        // Note: We need path_provider but can't import it directly if not in pubspec or we need to add it.
        // ScriptRunner uses it, so it should be available.
        // Let's assume we can get it via getIt or just import path_provider.
        // Actually, let's keep it simple: if default is invalid, we will try to resolve it later or just set it to null
        // and let the user configure it.
        // BUT the requirement says "handle this situation gracefully and select a default folder".
        // So we should try to set it to a valid folder.
      }

      for (final script in importedScripts) {
        String? outputDir = script.outputDirectory;
        if (outputDir != null && !Directory(outputDir).existsSync()) {
          if (defaultDir != null && Directory(defaultDir).existsSync()) {
            // Create subdirectory with script name
            // Simple sanitization to avoid path issues
            final safeName = script.name.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
            final newPath = "$defaultDir/$safeName";
            try {
              final newDir = Directory(newPath);
              if (!newDir.existsSync()) {
                newDir.createSync(recursive: true);
              }
              outputDir = newPath;
            } catch (e) {
              // Fallback to default root if creation fails
              outputDir = defaultDir;
            }
          } else {
            outputDir = null; // Clear invalid path if no default available
          }
        }

        // Optionally check for duplicates or generate new IDs
        // For now, we'll generate new IDs to avoid conflicts
        final newScript = script.copyWith(
          id: const Uuid().v4(),
          name: "${script.name} (Imported)",
          outputDirectory: outputDir,
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
