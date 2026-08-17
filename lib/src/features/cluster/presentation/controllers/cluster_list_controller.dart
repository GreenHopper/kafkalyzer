import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';

class ClusterListController extends ChangeNotifier {
  final ClusterService _clusterService = getIt<ClusterService>();
  List<ClusterProfile> _clusters = [];
  bool _isLoading = false;

  List<ClusterProfile> get clusters => _clusters;
  bool get isLoading => _isLoading;

  ClusterListController() {
    loadClusters();
  }

  Future<void> loadClusters() async {
    _isLoading = true;
    notifyListeners();

    _clusters = await _clusterService.loadClusters();

    // Fallback if empty (for demo/first run)
    // Default fallback removed per user request.

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addCluster(ClusterProfile profile) async {
    _clusters = List.from(_clusters)..add(profile);
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  Future<void> updateCluster(int index, ClusterProfile updatedProfile) async {
    _clusters = List.from(_clusters)..[index] = updatedProfile;
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  Future<void> deleteCluster(int index) async {
    _clusters = List.from(_clusters)..removeAt(index);
    await _clusterService.saveClusters(_clusters);
    notifyListeners();
  }

  Future<void> importClustersZip(List<int> zipBytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(zipBytes);
      final prefsDir = await getApplicationDocumentsDirectory();
      final sharedPrefsDir = Directory('${prefsDir.path}/shared_preferences');
      if (!await sharedPrefsDir.exists()) {
        await sharedPrefsDir.create(recursive: true);
      }

      // First pass: extract files and find clusters.json
      String? jsonString;

      for (final file in archive) {
        if (file.isFile) {
          if (file.name == 'clusters.json') {
            final content = file.content as List<int>;
            jsonString = utf8.decode(content);
          } else {
            // Extract other files (keystores/truststores)
            final filename = file.name;
            final data = file.content as List<int>;
            File('${sharedPrefsDir.path}/$filename')
              ..createSync(recursive: true)
              ..writeAsBytesSync(data);
          }
        }
      }

      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final List<ClusterProfile> importedClusters = jsonList.map((e) {
          var profile = ClusterProfileExtension.fromJson(e);
          // Update paths to point to the new location
          String? updatePath(String? path) {
            if (path == null || path.isEmpty) return null;
            // We assume the exported path was a relative filename.
            // Even if it was absolute in the export, we only care about the filename here
            // because we flattened the structure in the ZIP or kept it simple.
            // Let's assume the ZIP contains the files at root or we just take the basename.
            final filename = path.split('/').last.split('\\').last;
            return '${sharedPrefsDir.path}/$filename';
          }

          return profile.copyWith(
            sslKeystoreLocation: updatePath(profile.sslKeystoreLocation),
            sslTruststoreLocation: updatePath(profile.sslTruststoreLocation),
          );
        }).toList();

        final newClusters = List<ClusterProfile>.from(_clusters);
        for (var imported in importedClusters) {
          final existingIndex = newClusters.indexWhere(
            (c) => c.name == imported.name,
          );
          if (existingIndex != -1) {
            newClusters[existingIndex] = imported;
          } else {
            newClusters.add(imported);
          }
        }
        _clusters = newClusters;
        await _clusterService.saveClusters(_clusters);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error importing clusters ZIP: $e");
      rethrow;
    }
  }

  // Keeping legacy method for backward compatibility if needed, or removing/renaming it.
  // For now, let's keep it but maybe it's unused if we switch UI entirely.
  // Actually, the plan implies switching to ZIP, so we might not use this anymore for files.
  Future<void> importClusters(String jsonString) async {
    // ... existing implementation ...
    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      final List<ClusterProfile> importedClusters = jsonList
          .map((e) => ClusterProfileExtension.fromJson(e))
          .toList();

      final newClusters = List<ClusterProfile>.from(_clusters);
      for (var imported in importedClusters) {
        final existingIndex = newClusters.indexWhere(
          (c) => c.name == imported.name,
        );
        if (existingIndex != -1) {
          newClusters[existingIndex] = imported;
        } else {
          newClusters.add(imported);
        }
      }
      _clusters = newClusters;
      await _clusterService.saveClusters(_clusters);
      notifyListeners();
    } catch (e) {
      debugPrint("Error importing clusters: $e");
      rethrow;
    }
  }

  Future<List<int>> exportClustersZip(
    List<ClusterProfile> clustersToExport,
  ) async {
    final archive = Archive();

    // Create a modified list of clusters for the JSON where paths are relative filenames
    final List<Map<String, dynamic>> exportJsonList = [];

    for (var cluster in clustersToExport) {
      var exportCluster = cluster;

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

      exportJsonList.add(exportCluster.toJson());
    }

    final jsonString = jsonEncode(exportJsonList);
    final jsonBytes = utf8.encode(jsonString);
    archive.addFile(ArchiveFile('clusters.json', jsonBytes.length, jsonBytes));

    return ZipEncoder().encode(archive);
  }

  String exportClusters(List<ClusterProfile> clustersToExport) {
    return jsonEncode(clustersToExport.map((e) => e.toJson()).toList());
  }
}
