import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:velopack_flutter/velopack_flutter.dart' as velopack;
import 'package:velopack_flutter/velopack_flutter.dart' show UpdateInfo;

export 'package:velopack_flutter/velopack_flutter.dart' show UpdateInfo;

class UpdateService {
  static const String defaultRepositoryUrl =
      'https://github.com/Protoss78/kafkalyzer';

  final Logger _logger;
  bool _isInitialized = false;

  UpdateService({Logger? logger}) : _logger = logger ?? Logger();

  bool get isInitialized => _isInitialized;

  /// Initializes the Velopack auto-update bridge with the given repository URL.
  Future<void> initialize({String url = defaultRepositoryUrl}) async {
    try {
      debugPrint('Initializing Velopack with URL: $url');
      await velopack.initializeVelopack(url: url);
      _isInitialized = true;
      _logger.i('Velopack successfully initialized');
    } catch (e, stackTrace) {
      _isInitialized = false;
      _logger.w(
        'Velopack initialization failed (normal in development/debug mode): $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Checks whether an update is available from GitHub Releases.
  Future<bool> isUpdateAvailable() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) {
      return false;
    }

    try {
      return await velopack.isUpdateAvailable();
    } catch (e, stackTrace) {
      _logger.w('Failed to check for updates: $e', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Fetches metadata for the latest release if available.
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    if (!_isInitialized) {
      await initialize();
    }
    if (!_isInitialized) {
      return null;
    }

    try {
      return await velopack.getLatestUpdateInfo();
    } catch (e, stackTrace) {
      _logger.w('Failed to get latest update info: $e', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Starts downloading the update package and returns a stream of progress percentages (0-100).
  Stream<int> downloadWithProgress() {
    try {
      return velopack.checkAndDownloadUpdatesWithProgress();
    } catch (e, stackTrace) {
      _logger.e('Failed to start update download: $e', error: e, stackTrace: stackTrace);
      return Stream.error(e, stackTrace);
    }
  }

  /// Applies the downloaded update package and restarts the application.
  Future<void> applyAndRestart() async {
    try {
      _logger.i('Applying update and restarting application...');
      await velopack.updateAndRestart();
    } catch (e, stackTrace) {
      _logger.e('Failed to apply update and restart: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Returns the current version reported by Velopack, if available.
  Future<String?> getCurrentVersion() async {
    if (!_isInitialized) {
      return null;
    }
    try {
      return await velopack.currentVersion();
    } catch (e) {
      return null;
    }
  }
}
