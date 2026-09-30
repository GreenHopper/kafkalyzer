import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:velopack_flutter/velopack_flutter.dart' as velopack;
import 'package:velopack_flutter/velopack_flutter.dart' show UpdateInfo;

export 'package:velopack_flutter/velopack_flutter.dart' show UpdateInfo;

/// Outcome of an update availability check.
enum UpdateCheckStatus {
  /// Verified contact with the update source; no newer release exists.
  upToDate,

  /// A newer release is available.
  updateAvailable,

  /// The current process cannot apply in-place updates (e.g. unpackaged / non-AppImage).
  unsupportedEnvironment,

  /// The check failed (network, HTTP, rate limit, or source resolution).
  failed,
}

/// Structured result of [UpdateService.checkForUpdates].
class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? updateInfo;
  final String? errorMessage;
  final bool canAutoApply;

  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    this.errorMessage,
    this.canAutoApply = true,
  });

  bool get isUpdateAvailable => status == UpdateCheckStatus.updateAvailable;
}

class UpdateService {
  static const String defaultRepositoryUrl =
      'https://github.com/GreenHopper/kafkalyzer';
  static const String releasesUrl =
      'https://github.com/GreenHopper/kafkalyzer/releases';
  static const Duration backgroundCheckDelay = Duration(seconds: 3);

  final Logger _logger;
  bool _isInitialized = false;
  bool _backgroundCheckStarted = false;

  /// Notifies listeners when a background check finds an available update.
  final ValueNotifier<UpdateInfo?> availableUpdateNotifier =
      ValueNotifier<UpdateInfo?>(null);

  UpdateService({Logger? logger}) : _logger = logger ?? Logger();

  bool get isInitialized => _isInitialized;

  /// Whether the current process can perform Velopack in-place updates.
  ///
  /// On Linux, Velopack requires an AppImage (`$APPIMAGE`). Unpackaged /
  /// `flutter run` builds are treated as unsupported.
  bool get isEnvironmentSupported {
    if (!_isInitialized) {
      return false;
    }
    if (kIsWeb) {
      return false;
    }
    if (Platform.isLinux) {
      final appImage = Platform.environment['APPIMAGE'];
      return appImage != null && appImage.isNotEmpty;
    }
    // Packaged Windows / macOS installs are expected to initialize Velopack.
    return true;
  }

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

  /// Checks for updates and returns a typed result (never masks failures as up-to-date).
  Future<UpdateCheckResult> checkForUpdates() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized || !isEnvironmentSupported) {
      return const UpdateCheckResult(
        status: UpdateCheckStatus.unsupportedEnvironment,
        canAutoApply: false,
        errorMessage:
            'Automatic updates require a packaged installation '
            '(AppImage on Linux, installer on Windows/macOS).',
      );
    }

    try {
      final isAvailable = await velopack.isUpdateAvailable();
      if (!isAvailable) {
        return const UpdateCheckResult(status: UpdateCheckStatus.upToDate);
      }

      final info = await velopack.getLatestUpdateInfo();
      return UpdateCheckResult(
        status: UpdateCheckStatus.updateAvailable,
        updateInfo: info,
      );
    } catch (e, stackTrace) {
      if (_isUnsupportedEnvironmentError(e)) {
        _logger.w(
          'Update check unavailable in this environment: $e',
          error: e,
          stackTrace: stackTrace,
        );
        return UpdateCheckResult(
          status: UpdateCheckStatus.unsupportedEnvironment,
          canAutoApply: false,
          errorMessage: e.toString(),
        );
      }

      _logger.w(
        'Failed to check for updates: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return UpdateCheckResult(
        status: UpdateCheckStatus.failed,
        errorMessage: e.toString(),
        canAutoApply: false,
      );
    }
  }

  /// Legacy helper: returns true only when an update is available.
  /// Prefer [checkForUpdates] when callers need to distinguish failures.
  Future<bool> isUpdateAvailable() async {
    final result = await checkForUpdates();
    return result.isUpdateAvailable;
  }

  /// Fetches metadata for the latest release if available.
  Future<UpdateInfo?> getLatestUpdateInfo() async {
    final result = await checkForUpdates();
    if (result.status == UpdateCheckStatus.updateAvailable) {
      return result.updateInfo;
    }
    return null;
  }

  /// Starts downloading the update package and returns a stream of progress
  /// percentages (0-100).
  Stream<int> downloadWithProgress() {
    try {
      return velopack.checkAndDownloadUpdatesWithProgress();
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to start update download: $e',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.error(e, stackTrace);
    }
  }

  /// Applies the downloaded update package and restarts the application.
  Future<void> applyAndRestart() async {
    try {
      _logger.i('Applying update and restarting application...');
      await velopack.updateAndRestart();
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to apply update and restart: $e',
        error: e,
        stackTrace: stackTrace,
      );
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

  /// Non-blocking background check after startup. Errors are logged silently.
  ///
  /// Schedules the check after [backgroundCheckDelay] and publishes any found
  /// update via [availableUpdateNotifier]. Runs at most once per process.
  Future<void> runBackgroundCheck() async {
    if (_backgroundCheckStarted) {
      return;
    }
    _backgroundCheckStarted = true;

    await Future<void>.delayed(backgroundCheckDelay);

    try {
      final result = await checkForUpdates();
      if (result.status == UpdateCheckStatus.updateAvailable &&
          result.updateInfo != null) {
        availableUpdateNotifier.value = result.updateInfo;
        _logger.i(
          'Background update check found version '
          '${result.updateInfo!.targetFullRelease.version}',
        );
      } else if (result.status == UpdateCheckStatus.failed) {
        _logger.w('Background update check failed: ${result.errorMessage}');
      }
    } catch (e, stackTrace) {
      _logger.w(
        'Background update check failed: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void dispose() {
    availableUpdateNotifier.dispose();
  }

  bool _isUnsupportedEnvironmentError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('notinstalled') ||
        message.contains('not installed') ||
        message.contains('appimage') ||
        message.contains('updatenix') ||
        message.contains('could not locate');
  }
}
