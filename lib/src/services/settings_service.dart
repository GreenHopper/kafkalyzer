import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:path/path.dart' as p;

class ImportConfigurationResult {
  final ImportSummary? summary;
  const ImportConfigurationResult({this.summary});
}

class IntSetting {
  final String key;
  final int defaultValue;
  final int min;
  final int max;

  const IntSetting(this.key, this.defaultValue, this.min, this.max);
}

class SettingsService {
  /// Group lag above which the lag view warns. 0 disables the warning.
  static const lagWarnThresholdKey = 'consumer_lag_warn_threshold';

  static const maxRunHistorySetting = IntSetting(
    'scripting_max_run_history',
    30,
    0,
    1000,
  );
  static const maxConcurrentLagQueriesSetting = IntSetting(
    'consumer_max_concurrent_queries',
    5,
    1,
    20,
  );
  static const lagWarnThresholdSetting = IntSetting(
    lagWarnThresholdKey,
    0,
    0,
    1000000000000,
  );
  static const defaultResultLimitSetting = IntSetting(
    'default_result_limit',
    200,
    1,
    100000,
  );
  static const partitionSkewThresholdSetting = IntSetting(
    'topic_partition_skew_threshold_percent',
    50,
    1,
    100,
  );
  static const analysisConfirmThresholdSetting = IntSetting(
    'analysis_confirm_threshold',
    1000000,
    1000,
    1000000000000,
  );
  static const analysisHistoryPerTopicSetting = IntSetting(
    'analysis_history_per_topic',
    10,
    0,
    100,
  );

  static int readInt(SharedPreferences prefs, IntSetting setting) {
    final raw = prefs.get(setting.key);
    if (raw is int && raw >= setting.min && raw <= setting.max) {
      return raw;
    }
    return setting.defaultValue;
  }

  static int? parseInt(String text, IntSetting setting) {
    final parsed = int.tryParse(text.trim());
    if (parsed == null || parsed < setting.min || parsed > setting.max) {
      return null;
    }
    return parsed;
  }

  Future<void> writeInt(IntSetting setting, int value) async {
    if (value < setting.min || value > setting.max) {
      throw ArgumentError.value(
        value,
        'value',
        'Must be between ${setting.min} and ${setting.max}',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(setting.key, value);
    if (setting.key == defaultResultLimitSetting.key) {
      defaultResultLimit.value = value;
    }
  }

  final ValueNotifier<int> defaultResultLimit = ValueNotifier<int>(
    defaultResultLimitSetting.defaultValue,
  );

  Future<int> loadDefaultResultLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final value = readInt(prefs, defaultResultLimitSetting);
    defaultResultLimit.value = value;
    return value;
  }

  Future<void> setDefaultResultLimit(int limit) async {
    await writeInt(defaultResultLimitSetting, limit);
  }

  /// Maximum retained messages per result list (topic stream or search target).
  static const messageBufferLimitKey = 'message_buffer_limit';
  static const int defaultMessageBufferLimit = 50000;
  static const int minMessageBufferLimit = 1000;
  static const int maxMessageBufferLimit = 1000000;

  final ValueNotifier<int> messageBufferLimit = ValueNotifier<int>(
    defaultMessageBufferLimit,
  );

  static int? parseMessageBufferLimit(String input) {
    final parsed = int.tryParse(input.trim());
    if (parsed == null ||
        parsed < minMessageBufferLimit ||
        parsed > maxMessageBufferLimit) {
      return null;
    }
    return parsed;
  }

  Future<int> loadMessageBufferLimit() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.get(messageBufferLimitKey);
    if (raw is int &&
        raw >= minMessageBufferLimit &&
        raw <= maxMessageBufferLimit) {
      messageBufferLimit.value = raw;
      return raw;
    }
    messageBufferLimit.value = defaultMessageBufferLimit;
    return defaultMessageBufferLimit;
  }

  Future<void> setMessageBufferLimit(int limit) async {
    if (limit < minMessageBufferLimit || limit > maxMessageBufferLimit) {
      throw ArgumentError.value(
        limit,
        'limit',
        'Must be between $minMessageBufferLimit and $maxMessageBufferLimit',
      );
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(messageBufferLimitKey, limit);
    messageBufferLimit.value = limit;
  }

  Future<int> lagWarnThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return readInt(prefs, lagWarnThresholdSetting);
  }

  Future<void> setLagWarnThreshold(int messages) async {
    final clamped = messages < lagWarnThresholdSetting.min
        ? lagWarnThresholdSetting.min
        : (messages > lagWarnThresholdSetting.max
              ? lagWarnThresholdSetting.max
              : messages);
    await writeInt(lagWarnThresholdSetting, clamped);
  }

  Future<String?> defaultOutputDirectory() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final docsDir = await getApplicationDocumentsDirectory();
      return p.join(docsDir.path, 'Kafkalyzer', 'Output');
    }
    return null;
  }

  Future<void> initializeSettings() async {
    await loadMessageBufferLimit();
    await loadDefaultResultLimit();
    final prefs = await SharedPreferences.getInstance();
    final defaultDir = prefs.getString('general_default_output_dir');
    if (defaultDir == null ||
        defaultDir.isEmpty ||
        !await Directory(defaultDir).exists()) {
      debugPrint('⚠️ Invalid or missing default output dir: $defaultDir');
      final newDefaultDir = await defaultOutputDirectory();

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

  Future<void> resetGeneralSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await writeInt(
      defaultResultLimitSetting,
      defaultResultLimitSetting.defaultValue,
    );
    await writeInt(maxRunHistorySetting, maxRunHistorySetting.defaultValue);
    await writeInt(
      maxConcurrentLagQueriesSetting,
      maxConcurrentLagQueriesSetting.defaultValue,
    );
    await writeInt(
      lagWarnThresholdSetting,
      lagWarnThresholdSetting.defaultValue,
    );
    await writeInt(
      partitionSkewThresholdSetting,
      partitionSkewThresholdSetting.defaultValue,
    );
    await writeInt(
      analysisConfirmThresholdSetting,
      analysisConfirmThresholdSetting.defaultValue,
    );
    await writeInt(
      analysisHistoryPerTopicSetting,
      analysisHistoryPerTopicSetting.defaultValue,
    );
    await setMessageBufferLimit(defaultMessageBufferLimit);
    await prefs.setBool('general_restore_tabs', true);

    final defaultDir = await defaultOutputDirectory();
    if (defaultDir != null) {
      await prefs.setString('general_default_output_dir', defaultDir);
      try {
        await Directory(defaultDir).create(recursive: true);
      } catch (e) {
        debugPrint('❌ Failed to create default dir: $e');
      }
    }
  }

  Future<String?> exportConfiguration({
    required String dialogTitle,
    String? encryptionPassphrase,
  }) async {
    final isEncrypted = encryptionPassphrase != null;
    debugPrint(
      'DEBUG: Starting Configuration Export (encrypted: $isEncrypted)...',
    );
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

          if (!isEncrypted) {
            for (final field in SecureStorageService.secretFields) {
              exportedCluster.remove(field);
            }
          } else {
            final clusterName = exportedCluster['name'] as String?;
            if (clusterName != null &&
                getIt.isRegistered<SecureStorageService>()) {
              final secrets = await getIt<SecureStorageService>()
                  .getClusterSecrets(clusterName);
              for (final entry in secrets.entries) {
                if (entry.value != null && entry.value!.isNotEmpty) {
                  exportedCluster[entry.key] = entry.value;
                }
              }
            }
          }

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

      // 2. Add Preferences JSON
      final prefsJson = jsonEncode(allPrefs);
      final prefsBytes = utf8.encode(prefsJson);
      archive.addFile(
        ArchiveFile('preferences.json', prefsBytes.length, prefsBytes),
      );

      // 4. Save Zip (or encrypted .zip.age)
      final zipBytes = ZipEncoder().encode(archive);

      String? outputFile;
      if (!kIsWeb) {
        outputFile = await FilePicker.saveFile(
          dialogTitle: dialogTitle,
          fileName: isEncrypted
              ? 'kafkalyzer_config.zip.age'
              : 'kafkalyzer_config.zip',
          type: FileType.custom,
          allowedExtensions: isEncrypted ? ['age'] : ['zip'],
        );
      }

      if (outputFile != null) {
        if (isEncrypted && !outputFile.endsWith('.age')) {
          outputFile = '$outputFile.age';
        }
        final outputBytes = encryptionPassphrase != null
            ? await encryptBundle(zipBytes, encryptionPassphrase)
            : zipBytes;
        final file = File(outputFile);
        await file.writeAsBytes(outputBytes);
        debugPrint('DEBUG: Export success to $outputFile');
        return outputFile;
      }
      return null;
    } catch (e) {
      debugPrint('DEBUG: ❌ Error exporting configuration: $e');
      rethrow;
    }
  }

  Future<ImportConfigurationResult?> importConfiguration({
    required String dialogTitle,
    required PassphrasePrompt promptPassphrase,
    Future<ImportConflictChoice?> Function(
      ClusterProfile imported,
      String suggestedName,
    )?
    onClusterConflict,
  }) async {
    try {
      final result = await FilePicker.pickFiles(
        dialogTitle: dialogTitle,
        type: FileType.custom,
        allowedExtensions: ['zip', 'age'],
        withData: true, // Needed for web/some platforms, but safer for IO
      );

      if (result == null || result.files.isEmpty) return null;

      final fileBytes =
          result.files.single.bytes ??
          (result.files.single.path != null
              ? File(result.files.single.path!).readAsBytesSync()
              : null);

      if (fileBytes == null) throw Exception('Could not read imported file');

      final decryptedBytes = await decryptIfEncrypted(
        fileBytes,
        promptPassphrase,
      );
      if (decryptedBytes == null) return null;

      final archive = ZipDecoder().decodeBytes(decryptedBytes);
      // Changed to getApplicationSupportDirectory to match documentation (AppData on Windows)
      final appSupportDir = await getApplicationSupportDirectory();
      // Use platform-aware path construction
      final sharedPrefsDir = Directory(
        p.join(appSupportDir.path, 'shared_preferences'),
      );

      // Validate all archive entries and parse preferences.json before writing anything.
      final plan = planArchiveExtraction(
        archive,
        sharedPrefsDir.path,
        select: (name) =>
            name.startsWith('files/') &&
            name.substring('files/'.length).isNotEmpty,
        mapEntryName: (name) =>
            name.startsWith('files/') ? name.substring('files/'.length) : name,
      );

      final prefsEntry = archive.findFile('preferences.json');
      final Map<String, dynamic>? parsedPrefs = prefsEntry != null
          ? Map<String, dynamic>.from(
              jsonDecode(utf8.decode(prefsEntry.content as List<int>)) as Map,
            )
          : null;

      MergeImportResult? mergeResult;
      ClusterService? clusterService;
      List<String>? rawImportedClusterJsons;

      if (parsedPrefs != null) {
        // Never import the migration flag from the bundle; secrets must be
        // written to the local OS keyring or migrated on next start.
        parsedPrefs.remove('credentials_migrated_to_keyring_v1');

        if (parsedPrefs.containsKey('cluster_profiles')) {
          try {
            final clustersJsonString =
                parsedPrefs['cluster_profiles'] as String;
            final dynamic decodedClusters = jsonDecode(clustersJsonString);

            if (decodedClusters is List) {
              clusterService = getIt<ClusterService>();
              if (clusterService.storeStatus.isUnreadable) {
                throw StoredDataUnreadableException(
                  'cluster_profiles',
                  backupPath: clusterService.storeStatus.backupPath,
                );
              }
              final existing = await clusterService.loadClusters();

              final importedProfiles = <ClusterProfile>[];
              rawImportedClusterJsons = <String>[];
              for (final clusterJson in decodedClusters) {
                final Map<String, dynamic> importedCluster = Map.from(
                  clusterJson as Map,
                );

                String? fixPath(String? path) {
                  if (path != null && path.startsWith('files/')) {
                    final filename = path.substring('files/'.length);
                    return p.join(sharedPrefsDir.path, filename);
                  }
                  return path;
                }

                importedCluster['sslKeystoreLocation'] = fixPath(
                  importedCluster['sslKeystoreLocation'] as String?,
                );
                importedCluster['sslTruststoreLocation'] = fixPath(
                  importedCluster['sslTruststoreLocation'] as String?,
                );

                final encoded = jsonEncode(importedCluster);
                rawImportedClusterJsons.add(encoded);
                importedProfiles.add(
                  await deserializeClusterProfile(json: encoded),
                );
              }

              mergeResult = await mergeImportedProfiles(
                existing,
                importedProfiles,
                onClusterConflict ??
                    (_, _) async => const ImportConflictChoice.replace(),
              );
              if (mergeResult == null) {
                // User cancelled conflict resolution: abort without writing.
                return null;
              }
              parsedPrefs.remove('cluster_profiles');
            } else {
              debugPrint(
                '❌ Import Error: cluster_profiles is not a List (got ${decodedClusters.runtimeType}). Skipping import for this key.',
              );
              parsedPrefs.remove('cluster_profiles');
            }
          } on StoredDataUnreadableException {
            rethrow;
          } catch (e) {
            debugPrint('❌ Error processing cluster_profiles during import: $e');
            parsedPrefs.remove('cluster_profiles');
          }
        }
      }

      debugPrint('📂 Import Target Directory: ${sharedPrefsDir.path}');

      if (plan.isNotEmpty) {
        if (!await sharedPrefsDir.exists()) {
          debugPrint(
            '⚠️ Directory does not exist, creating: ${sharedPrefsDir.path}',
          );
          await sharedPrefsDir.create(recursive: true);
        } else {
          debugPrint('✅ Directory exists: ${sharedPrefsDir.path}');
        }

        // 1. Extract Files
        for (final entry in plan.entries) {
          final data = entry.key.content as List<int>;
          final targetFile = File(entry.value);
          debugPrint('📄 Extracting file to: ${entry.value}');
          await targetFile.parent.create(recursive: true);
          await targetFile.writeAsBytes(data);
        }
      }

      // 2. Restore Preferences
      if (parsedPrefs != null) {
        final prefs = await SharedPreferences.getInstance();
        final Map<String, dynamic> allPrefs = parsedPrefs;

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

        if (mergeResult != null && clusterService != null) {
          final allWritesOk = await clusterService.saveClusters(
            mergeResult.clusters,
          );
          if (!allWritesOk) {
            // Keyring failed: keep plaintext JSON in preferences and clear the
            // migration flag so migration retries on the next start.
            final encoded = <String>[];
            for (final c in mergeResult.clusters) {
              encoded.add(await serializeClusterProfile(profile: c));
            }
            await prefs.setString('cluster_profiles', '[${encoded.join(',')}]');
            await prefs.setBool('credentials_migrated_to_keyring_v1', false);
          }
        }

        // 3. Reload Controllers
        await getIt<ClusterListController>().loadClusters();
        await getIt<ScriptController>().loadScripts();
        await loadMessageBufferLimit();
        await loadDefaultResultLimit();
        if (getIt.isRegistered<AppearanceSettings>()) {
          await getIt<AppearanceSettings>().load();
        }
      }

      return ImportConfigurationResult(summary: mergeResult?.summary);
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
