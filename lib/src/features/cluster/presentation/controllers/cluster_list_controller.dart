import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/tls_transition_controller.dart';
import 'package:kafkalyzer/src/rust/api/json_path.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';

class ClusterListController extends ChangeNotifier {
  final ClusterService _clusterService = getIt<ClusterService>();
  List<ClusterProfile> _clusters = [];
  bool _isLoading = false;

  List<ClusterProfile> get clusters => _clusters;
  bool get isLoading => _isLoading;
  StoreStatus get storeStatus => _clusterService.storeStatus;
  ValueNotifier<SharedProfilesStatus> get sharedProfilesStatus =>
      _clusterService.sharedProfilesStatus;

  /// Re-runs the shared-profiles sync by saving the current in-memory list.
  Future<void> retrySharedProfilesSync() async {
    _requireReadableStore();
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  ClusterListController() {
    loadClusters();
  }

  void _requireReadableStore() {
    if (storeStatus.isUnreadable) {
      throw StoredDataUnreadableException(
        'cluster_profiles',
        backupPath: storeStatus.backupPath,
      );
    }
  }

  Future<void> loadClusters() async {
    _isLoading = true;
    notifyListeners();

    try {
      _clusters = await _clusterService.loadClusters();
    } on StoredDataUnreadableException {
      _clusters = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    if (getIt.isRegistered<TlsTransitionController>() &&
        _clusters.any((c) => c.tlsVerification == TlsVerification.unreviewed)) {
      unawaited(getIt<TlsTransitionController>().runStartupSweep());
    }
  }

  Future<void> discardUnreadable() async {
    await _clusterService.discardUnreadable();
    await loadClusters();
  }

  Future<void> addCluster(ClusterProfile profile) async {
    _requireReadableStore();
    _clusters = List.from(_clusters)..add(profile);
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  Future<void> updateCluster(int index, ClusterProfile updatedProfile) async {
    _requireReadableStore();
    _clusters = List.from(_clusters)..[index] = updatedProfile;
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  Future<void> deleteCluster(int index) async {
    _requireReadableStore();
    _clusters = List.from(_clusters)..removeAt(index);
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  Future<ImportSummary?> importClustersZip(
    List<int> zipBytes, {
    ImportConflictResolver? onConflict,
  }) async {
    _requireReadableStore();
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final prefsDir = await getApplicationDocumentsDirectory();
      final sharedPrefsDir = Directory('${prefsDir.path}/shared_preferences');

      // Validate all entries before creating directories or writing any file.
      final plan = planArchiveExtraction(
        archive,
        sharedPrefsDir.path,
        select: (name) => name != 'clusters.json',
      );

      final clustersEntry = archive.findFile('clusters.json');
      final String? jsonString = clustersEntry != null
          ? utf8.decode(clustersEntry.content as List<int>)
          : null;

      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final List<ClusterProfile> importedClusters = [];
        for (final entry in jsonList) {
          var profile = await deserializeClusterProfile(
            json: jsonEncode(entry),
          );
          // Update paths to point to the new location
          String? updatePath(String? path) {
            if (path == null || path.isEmpty) return null;
            final filename = path.split('/').last.split('\\').last;
            return '${sharedPrefsDir.path}/$filename';
          }

          importedClusters.add(
            profile.copyWith(
              sslKeystoreLocation: updatePath(profile.sslKeystoreLocation),
              sslTruststoreLocation: updatePath(profile.sslTruststoreLocation),
            ),
          );
        }

        final mergeResult = await mergeImportedProfiles(
          _clusters,
          importedClusters,
          onConflict ?? (_, _) async => const ImportConflictChoice.replace(),
        );
        if (mergeResult == null) {
          return null;
        }

        if (plan.isNotEmpty) {
          if (!await sharedPrefsDir.exists()) {
            await sharedPrefsDir.create(recursive: true);
          }
          for (final entry in plan.entries) {
            final data = entry.key.content as List<int>;
            File(entry.value)
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }

        _clusters = mergeResult.clusters;
        await _clusterService.saveClusters(_clusters);
        notifyListeners();
        return mergeResult.summary;
      } else if (plan.isNotEmpty) {
        if (!await sharedPrefsDir.exists()) {
          await sharedPrefsDir.create(recursive: true);
        }
        for (final entry in plan.entries) {
          final data = entry.key.content as List<int>;
          File(entry.value)
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        }
      }
      return const ImportSummary(
        imported: 0,
        replaced: 0,
        renamed: 0,
        skipped: 0,
      );
    } catch (e) {
      debugPrint("Error importing clusters ZIP: $e");
      rethrow;
    }
  }

  // Keeping legacy method for backward compatibility if needed, or removing/renaming it.
  // For now, let's keep it but maybe it's unused if we switch UI entirely.
  // Actually, the plan implies switching to ZIP, so we might not use this anymore for files.
  Future<ImportSummary?> importClusters(
    String jsonString, {
    ImportConflictResolver? onConflict,
  }) async {
    _requireReadableStore();
    // ... existing implementation ...
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<ClusterProfile> importedClusters = [];
      for (final entry in jsonList) {
        importedClusters.add(
          await deserializeClusterProfile(json: jsonEncode(entry)),
        );
      }

      final mergeResult = await mergeImportedProfiles(
        _clusters,
        importedClusters,
        onConflict ?? (_, _) async => const ImportConflictChoice.replace(),
      );
      if (mergeResult == null) {
        return null;
      }

      _clusters = mergeResult.clusters;
      await _clusterService.saveClusters(_clusters);
      notifyListeners();
      return mergeResult.summary;
    } catch (e) {
      debugPrint("Error importing clusters: $e");
      rethrow;
    }
  }

  Future<List<int>> exportClustersZip(
    List<ClusterProfile> clustersToExport, {
    String? encryptionPassphrase,
  }) async {
    final includeSecrets = encryptionPassphrase != null;
    final archive = Archive();

    // Create a modified list of clusters for the JSON where paths are relative filenames
    final List<String> exportJsonList = [];

    for (var cluster in clustersToExport) {
      var exportCluster = includeSecrets ? cluster : cluster.sanitized();

      String? processFile(String? path) {
        if (path == null || path.isEmpty) return null;
        final file = File(path);
        if (file.existsSync()) {
          final filename = path.split('/').last.split('\\').last;
          final bytes = file.readAsBytesSync();
          archive.addFile(ArchiveFile(filename, bytes.length, bytes));
          return filename; // Store only filename in the JSON
        }
        return path; // Keep original if file doesn't exist? Or null? Let's keys original for now or filename.
      }

      exportCluster = exportCluster.copyWith(
        sslKeystoreLocation: processFile(cluster.sslKeystoreLocation),
        sslTruststoreLocation: processFile(cluster.sslTruststoreLocation),
      );

      exportJsonList.add(await serializeClusterProfile(profile: exportCluster));
    }

    final jsonString = '[${exportJsonList.join(',')}]';
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('clusters.json', jsonBytes.length, jsonBytes));

    final zipBytes = ZipEncoder().encode(archive);
    if (encryptionPassphrase != null) {
      return encryptBundle(zipBytes, encryptionPassphrase);
    }
    return zipBytes;
  }

  Future<String> exportClusters(List<ClusterProfile> clustersToExport) async {
    final encoded = <String>[];
    for (final cluster in clustersToExport) {
      encoded.add(await serializeClusterProfile(profile: cluster.sanitized()));
    }
    return '[${encoded.join(',')}]';
  }
}
