import 'dart:io';
import 'package:flutter/material.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:googleapis/storage/v1.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class GcsService {
  static const _scopes = [StorageApi.devstorageReadOnlyScope];
  static const _keyFileName = 'wgs-kaenup-data-test-6d6c17c275e1.json';

  Future<http.Client?> getAuthClient() async {
    try {
      final keyFile = await _findKeyFile();

      if (keyFile == null) {
        debugPrint('GCS Service Account Key file not found.');
        return null;
      }
      debugPrint('Found GCS Key File at: ${keyFile.path}');

      final jsonString = await keyFile.readAsString();
      final credentials = ServiceAccountCredentials.fromJson(jsonString);
      return await clientViaServiceAccount(credentials, _scopes);
    } catch (e) {
      debugPrint('Error creating GCS auth client: $e');
      return null;
    }
  }

  Future<File?> _findKeyFile() async {
    final List<String> candidates = [];

    // 1. Try standard Application Documents Directory
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      candidates.add('${appDocDir.path}/shared_preferences/$_keyFileName');
    } catch (_) {}

    // 2. Documented Paths from README & Explicit OS paths
    if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        // README: ~/.local/share/com.example.kafkalyzer/shared_preferences.json
        candidates.add(
          '$home/.local/share/com.example.kafkalyzer/$_keyFileName',
        );
        candidates.add(
          '$home/.local/share/com.example.kafkalyzer/shared_preferences/$_keyFileName',
        ); // Just in case

        candidates.add('$home/.local/share/kafkalyzer/$_keyFileName');
      }
    } else if (Platform.isWindows) {
      final appData = Platform.environment['APPDATA']; // Roaming
      if (appData != null) {
        candidates.add('$appData\\com.example\\kafkalyzer\\$_keyFileName');
        candidates.add(
          '$appData\\com.example\\kafkalyzer\\shared_preferences\\$_keyFileName',
        );
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null) {
        candidates.add('$home/Library/Preferences/$_keyFileName');
        candidates.add(
          '$home/Library/Preferences/com.example.kafkalyzer/$_keyFileName',
        );
        candidates.add(
          '$home/Library/Application Support/com.example.kafkalyzer/$_keyFileName',
        );
      }
    }

    // Check all candidates
    for (final path in candidates) {
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
    }

    debugPrint("Checked locations for GCS key: $candidates");
    return null;
  }

  /// Downloads a file from GCS and saves it to the specified local path.
  Future<void> downloadFile(
    String bucket,
    String objectName,
    String savePath,
  ) async {
    final client = await getAuthClient();
    if (client == null) {
      throw Exception('Could not authenticate with GCS. Check key file.');
    }

    try {
      final storage = StorageApi(client);

      // The object name in the URL/message might start with /, but GCS API expects it without leading slash
      final cleanObjectName = objectName.startsWith('/')
          ? objectName.substring(1)
          : objectName;

      final media =
          await storage.objects.get(
                bucket,
                cleanObjectName,
                downloadOptions: DownloadOptions.fullMedia,
              )
              as Media;

      final file = File(savePath);
      final sink = file.openWrite();

      await media.stream.pipe(sink);
      await sink.close();
    } finally {
      client.close();
    }
  }

  /// Lists files in a GCS bucket with the given prefix.
  Future<List<String>> listFiles(String bucket, String prefix) async {
    final client = await getAuthClient();
    if (client == null) {
      throw Exception('Could not authenticate with GCS. Check key file.');
    }

    try {
      final storage = StorageApi(client);
      List<String> allFiles = [];
      String? pageToken;

      do {
        final objects = await storage.objects.list(
          bucket,
          prefix: prefix,
          pageToken: pageToken,
        );

        if (objects.items != null) {
          final pageFiles = objects.items!
              .where((item) => item.name != null && !item.name!.endsWith('/'))
              .map(
                (item) => '/${item.name}',
              ); // Prepends / to match existing format
          allFiles.addAll(pageFiles);
        }

        pageToken = objects.nextPageToken;
      } while (pageToken != null);

      return allFiles;
    } finally {
      client.close();
    }
  }
}
