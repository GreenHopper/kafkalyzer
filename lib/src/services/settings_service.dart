import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path/path.dart' as p;

class SettingsService {
  static const _gcsKeyFileName = 'wgs-kaenup-data-test-6d6c17c275e1.json';

  Future<void> initializeSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaultDir = prefs.getString('general_default_output_dir');
    if (defaultDir == null ||
        defaultDir.isEmpty ||
        !await Directory(defaultDir).exists()) {
      debugPrint('⚠️ Invalid or missing default output dir: $defaultDir');
      String? newDefaultDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final docsDir = await getApplicationDocumentsDirectory();
        newDefaultDir = p.join(docsDir.path, 'Kafkalyzer', 'Output');
      }

      if (newDefaultDir != null) {
        debugPrint('✅ Setting new default output dir: $newDefaultDir');
        await prefs.setString('general_default_output_dir', newDefaultDir);
        // Ensure it exists
        try {
          await Directory(newDefaultDir).create(recursive: true);
        } catch (e) {
          debugPrint('❌ Failed to create default dir: $e');
        }
      }
    }
  }

  Future<void> exportConfiguration() async {
    debugPrint('DEBUG: Starting Configuration Export...');
    try {
      final prefs = await SharedPreferences.getInstance();
      debugPrint(
        'DEBUG: SharedPreferences loaded. Keys: ${prefs.getKeys().length}',
      );
      final allPrefs = <String, dynamic>{};
      final keys = prefs.getKeys();

      // Collect all preferences
      for (final key in keys) {
        allPrefs[key] = prefs.get(key);
      }

      final archive = Archive();

      // 1. Handle Clusters (extract files and make paths relative)
      // Correcting storage key to match ClusterService
      if (allPrefs.containsKey('cluster_profiles')) {
        debugPrint('DEBUG: Found cluster_profiles key');
        final clustersJsonString = allPrefs['cluster_profiles'] as String;
        final List<dynamic> clustersList = jsonDecode(clustersJsonString);
        debugPrint('DEBUG: Parsed ${clustersList.length} clusters');

        final List<dynamic> exportedClustersList = [];

        for (final clusterJson in clustersList) {
          final Map<String, dynamic> exportedCluster = Map.from(clusterJson);
          debugPrint('DEBUG: Processing cluster: ${exportedCluster['name']}');

          // Process Keystore
          if (exportedCluster['sslKeystoreLocation'] != null) {
            String path = (exportedCluster['sslKeystoreLocation'] as String)
                .trim();
            debugPrint('DEBUG: Found keystore at $path');
            final filename = _addFileToArchive(archive, path);
            if (filename != null) {
              exportedCluster['sslKeystoreLocation'] = 'files/$filename';
            } else {
              debugPrint(
                'DEBUG: ⚠️ Keystore file failed to archive, keeping original path: $path',
              );
            }
          } else {
            debugPrint('DEBUG: No keystore configured for this cluster');
          }

          // Process Truststore
          if (exportedCluster['sslTruststoreLocation'] != null) {
            String path = (exportedCluster['sslTruststoreLocation'] as String)
                .trim();
            debugPrint('DEBUG: Found truststore at $path');
            final filename = _addFileToArchive(archive, path);
            if (filename != null) {
              exportedCluster['sslTruststoreLocation'] = 'files/$filename';
            } else {
              debugPrint(
                'DEBUG: ⚠️ Truststore file failed to archive, keeping original path: $path',
              );
            }
          }

          exportedClustersList.add(exportedCluster);
        }
        allPrefs['cluster_profiles'] = jsonEncode(exportedClustersList);
      } else {
        debugPrint('DEBUG: cluster_profiles key NOT found');
      }

      // 2. Handle GCS Key File
      final gcsKeyFile = await _findGcsKeyFile();
      if (gcsKeyFile != null) {
        final bytes = await gcsKeyFile.readAsBytes();
        archive.addFile(
          ArchiveFile('files/$_gcsKeyFileName', bytes.length, bytes),
        );
      }

      // 3. Add Preferences JSON
      final prefsJson = jsonEncode(allPrefs);
      final prefsBytes = utf8.encode(prefsJson);
      archive.addFile(
        ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
      );

      // 4. Save Zip
      final zipBytes = ZipEncoder().encode(archive);

      String? outputFile;
      if (!kIsWeb) {
        outputFile = await FilePicker.saveFile(
          dialogTitle: 'Export Configuration',
          fileName: 'kafkalyzer_config.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );
      }

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(zipBytes);
        debugPrint('DEBUG: Export success to $outputFile');
      }
    } catch (e) {
      debugPrint('DEBUG: ❌ Error exporting configuration: $e');
      rethrow;
    }
  }

  Future<void> importConfiguration() async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: 'Import Configuration',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true, // Needed for web/some platforms, but safer for IO
      );

      if (result == null || result.files.isEmpty) return;

      final fileBytes =
          result.files.single.bytes ??
          (result.files.single.path != null
              ? File(result.files.single.path!).readAsBytesSync()
              : null);

      if (fileBytes == null) throw Exception('Could not read imported file');

      final archive = ZipDecoder().decodeBytes(fileBytes);
      // Changed to getApplicationSupportDirectory to match documentation (AppData on Windows)
      final appSupportDir = await getApplicationSupportDirectory();
      // Use platform-aware path construction
      final sharedPrefsDir = Directory(
        p.join(appSupportDir.path, 'shared_preferences'),
      );

      debugPrint('📂 Import Target Directory: ${sharedPrefsDir.path}');

      if (!await sharedPrefsDir.exists()) {
        debugPrint(
          '⚠️ Directory does not exist, creating: ${sharedPrefsDir.path}',
        );
        await sharedPrefsDir.create(recursive: true);
      } else {
        debugPrint('✅ Directory exists: ${sharedPrefsDir.path}');
      }

      String? prefsJsonString;

      // 1. Extract Files
      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'preferences.json') {
            prefsJsonString = utf8.decode(file.content as List<int>);
          } else if (file.name.startsWith('files/')) {
            final filename = file.name.substring('files/'.length);
            if (filename.isNotEmpty) {
              final data = file.content as List<int>;
              // Use platform-aware path construction
              final targetPath = p.join(sharedPrefsDir.path, filename);
              debugPrint('📄 Extracting file to: $targetPath');
              final targetFile = File(targetPath);

              // Ensure directory exists if filename contains paths (though currently flat)
              await targetFile.parent.create(recursive: true);

              await targetFile.writeAsBytes(data);
            }
          }
        }
      }

      // 2. Restore Preferences
      if (prefsJsonString != null) {
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> allPrefs = jsonDecode(prefsJsonString);

        // Special handling for clusters to fix paths
        if (allPrefs.containsKey('cluster_profiles')) {
          try {
            final clustersJsonString = allPrefs['cluster_profiles'] as String;
            final dynamic decodedClusters = jsonDecode(clustersJsonString);

            if (decodedClusters is List) {
              final List<dynamic> clustersList = decodedClusters;
              final List<dynamic> importedClustersList = [];

              for (final clusterJson in clustersList) {
                final Map<String, dynamic> importedCluster = Map.from(
                  clusterJson,
                );

                String? fixPath(String? path) {
                  if (path != null && path.startsWith('files/')) {
                    final filename = path.substring('files/'.length);
                    // Use platform-aware path construction
                    return p.join(sharedPrefsDir.path, filename);
                  }
                  return path;
                }

                importedCluster['sslKeystoreLocation'] = fixPath(
                  importedCluster['sslKeystoreLocation'],
                );
                importedCluster['sslTruststoreLocation'] = fixPath(
                  importedCluster['sslTruststoreLocation'],
                );

                importedClustersList.add(importedCluster);
              }
              allPrefs['cluster_profiles'] = jsonEncode(importedClustersList);
            } else {
              debugPrint(
                '❌ Import Error: cluster_profiles is not a List (got ${decodedClusters.runtimeType}). Skipping import for this key.',
              );
              allPrefs.remove('cluster_profiles');
            }
          } catch (e) {
            debugPrint('❌ Error processing cluster_profiles during import: $e');
            allPrefs.remove('cluster_profiles');
          }
        }

        // 3. Fix Paths
        await _fixImportedPaths(allPrefs);

        // Apply all prefs
        for (final entry in allPrefs.entries) {
          final key = entry.key;
          final value = entry.value;

          if (value is String) {
            await prefs.setString(key, value);
          } else if (value is int) {
            await prefs.setInt(key, value);
          } else if (value is bool) {
            await prefs.setBool(key, value);
          } else if (value is double) {
            await prefs.setDouble(key, value);
          } else if (value is List) {
            // Assume List<String>
            await prefs.setStringList(key, List<String>.from(value));
          }
        }

        // 3. Reload Controllers
        await getIt<ClusterListController>().loadClusters();
        await getIt<ScriptController>().loadScripts();

        // Notify user? Rely on caller to show snackbar?
      }
    } catch (e) {
      debugPrint('Error importing configuration: $e');
      rethrow;
    }
  }

  String? _addFileToArchive(Archive archive, String path) {
    try {
      final normalizedPath = p.normalize(path);
      final file = File(normalizedPath);
      debugPrint(
        'DEBUG: 📦 Attempting to add file to archive: $normalizedPath (Original: $path)',
      );

      if (file.existsSync()) {
        final filename = p.basename(normalizedPath);
        final bytes = file.readAsBytesSync();
        archive.addFile(ArchiveFile('files/$filename', bytes.length, bytes));
        debugPrint('DEBUG: ✅ Added file: $filename (${bytes.length} bytes)');
        return filename;
      } else {
        debugPrint('DEBUG: ⚠️ File NOT found at: ${file.absolute.path}');
      }
    } catch (e) {
      debugPrint('DEBUG: ❌ Error adding file: $e');
    }
    return null;
  }

  // Simplified version of GcsService._findKeyFile
  Future<File?> _findGcsKeyFile() async {
    final List<String> candidates = [];
    try {
      // Changed to getApplicationSupportDirectory to search in AppData (Windows) or .local/share (Linux)
      final appSupportDir = await getApplicationSupportDirectory();
      candidates.add(
        p.join(appSupportDir.path, 'shared_preferences', _gcsKeyFileName),
      );

      // Keep checking Documents for backward compatibility
      final appDocDir = await getApplicationDocumentsDirectory();
      candidates.add(
        p.join(appDocDir.path, 'shared_preferences', _gcsKeyFileName),
      );
    } catch (_) {}

    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        candidates.add(
          p.join(
            home,
            '.local/share/at.greenhopper.kafkalyzer',
            _gcsKeyFileName,
          ),
        );
        candidates.add(
          p.join(home, '.local/share/kafkalyzer', _gcsKeyFileName),
        );
      }
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA'];
      if (appData != null) {
        candidates.add(
          p.join(appData, 'at.greenhopper', 'kafkalyzer', _gcsKeyFileName),
        );
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        candidates.add('$home/Library/Preferences/$_gcsKeyFileName');
      }
    }

    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Future<void> _fixImportedPaths(Map<String, dynamic> allPrefs) async {
    // 1. Fix General Default Output Directory
    String? defaultDir = allPrefs['general_default_output_dir'] as String?;

    // Always validate the path. If it doesn't exist or is null, reset it.
    if (defaultDir == null || !await Directory(defaultDir).exists()) {
      debugPrint('⚠️ Invalid or missing default output dir: $defaultDir');

      // Determine a valid default
      String? newDefaultDir;
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final docsDir = await getApplicationDocumentsDirectory();
        newDefaultDir = p.join(docsDir.path, 'Kafkalyzer', 'Output');
      }

      if (newDefaultDir != null) {
        debugPrint('✅ Setting new default output dir: $newDefaultDir');
        allPrefs['general_default_output_dir'] = newDefaultDir;
        defaultDir = newDefaultDir;

        // Ensure it exists
        try {
          await Directory(newDefaultDir).create(recursive: true);
        } catch (e) {
          debugPrint('❌ Failed to create default dir: $e');
        }
      }
    }

    // 2. Fix Script Output Directories
    if (allPrefs.containsKey('saved_scripts_v1')) {
      try {
        final scriptsJson = allPrefs['saved_scripts_v1'] as String;
        final dynamic decodedScripts = jsonDecode(scriptsJson);

        if (decodedScripts is List) {
          final List<dynamic> scriptsList = decodedScripts;
          final List<dynamic> updatedScriptsList = [];
          bool scriptsUpdated = false;

          for (final scriptJson in scriptsList) {
            final Map<String, dynamic> scriptCode = Map.from(scriptJson);
            if (scriptCode.containsKey('outputDirectory')) {
              scriptCode['outputDirectory'] = null;
              scriptsUpdated = true;
            }
            updatedScriptsList.add(scriptCode);
          }

          if (scriptsUpdated) {
            allPrefs['saved_scripts_v1'] = jsonEncode(updatedScriptsList);
          }
        } else {
          debugPrint(
            '❌ Import Error: saved_scripts_v1 is not a List (got ${decodedScripts.runtimeType}). Skipping import for this key.',
          );
          allPrefs.remove('saved_scripts_v1');
        }
      } catch (e) {
        debugPrint('❌ Error fixing script paths: $e');
        allPrefs.remove('saved_scripts_v1');
      }
    }
  }
}
