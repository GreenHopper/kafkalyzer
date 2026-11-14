import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:logger/logger.dart';
import 'package:velopack_flutter/velopack_flutter.dart' as velopack;
import 'package:velopack_flutter/velopack_flutter.dart' show UpdateInfo;

export 'package:velopack_flutter/velopack_flutter.dart' show UpdateInfo;

/// Outcome of an update availability check.
enum UpdateCheckStatus {
  /// Verified contact with the update source; no newer release exists.
  upToDate,

  /// A newer release is available and can be auto-applied via Velopack.
  updateAvailable,

  /// A newer release is available on GitHub; user must install manually.
  manualUpdateAvailable,

  /// Running version is up to date according to GitHub releases (manual install).
  manualUpToDate,

  /// Latest GitHub release is known, but running version could not be compared.
  latestKnown,

  /// The current process cannot apply in-place updates (e.g. unpackaged / non-AppImage).
  unsupportedEnvironment,

  /// The check failed (network, HTTP, rate limit, or source resolution).
  failed,
}

/// Metadata for a discovered update (auto-apply or manual).
class AvailableUpdate {
  const AvailableUpdate({
    required this.version,
    this.releaseNotes,
    this.releaseUrl,
    required this.canAutoApply,
  });

  final String version;
  final String? releaseNotes;
  final String? releaseUrl;
  final bool canAutoApply;
}

enum DownloadPhase { idle, running, finished, failed }

class DownloadState {
  const DownloadState({
    this.phase = DownloadPhase.idle,
    this.progress = 0,
    this.cancelled = false,
    this.errorMessage,
  });

  final DownloadPhase phase;
  final int progress;
  final bool cancelled;
  final String? errorMessage;

  bool get canApply => phase == DownloadPhase.finished && !cancelled;
}

/// Structured result of [UpdateService.checkForUpdates].
class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? updateInfo;
  final String? latestVersion;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? errorMessage;
  final bool canAutoApply;

  const UpdateCheckResult({
    required this.status,
    this.updateInfo,
    this.latestVersion,
    this.releaseUrl,
    this.releaseNotes,
    this.errorMessage,
    this.canAutoApply = true,
  });

  bool get isUpdateAvailable =>
      status == UpdateCheckStatus.updateAvailable ||
      status == UpdateCheckStatus.manualUpdateAvailable;
}

class UpdateService {
  static const String defaultRepositoryUrl =
      'https://github.com/GreenHopper/kafkalyzer';
  static const String releasesUrl =
      'https://github.com/GreenHopper/kafkalyzer/releases';
  static const String latestReleaseApiUrl =
      'https://api.github.com/repos/GreenHopper/kafkalyzer/releases/latest';
  static const Duration backgroundCheckDelay = Duration(seconds: 3);
  static const Duration githubRequestTimeout = Duration(seconds: 10);

  final Logger _logger;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final String Function() _currentVersionProvider;
  final Stream<int> Function() _downloadStreamFactory;
  final Future<void> Function() _applyAndRestartFn;
  final bool Function() _isDebugMode;

  bool _isInitialized = false;
  bool _backgroundCheckStarted = false;
  StreamSubscription<int>? _activeDownloadSub;

  /// Notifies listeners when a background check finds an available update.
  final ValueNotifier<AvailableUpdate?> availableUpdateNotifier =
      ValueNotifier<AvailableUpdate?>(null);

  /// Observable state of the current or most recent update download.
  final ValueNotifier<DownloadState> downloadState =
      ValueNotifier<DownloadState>(const DownloadState());

  UpdateService({
    Logger? logger,
    http.Client? httpClient,
    String Function()? currentVersionProvider,
    Stream<int> Function()? downloadStreamFactory,
    Future<void> Function()? applyAndRestartFn,
    bool Function()? isDebugMode,
  }) : _logger = logger ?? Logger(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _currentVersionProvider =
           currentVersionProvider ?? (() => AppVersionHelper.version),
       _downloadStreamFactory =
           downloadStreamFactory ??
           velopack.checkAndDownloadUpdatesWithProgress,
       _applyAndRestartFn = applyAndRestartFn ?? velopack.updateAndRestart,
       _isDebugMode = isDebugMode ?? (() => kDebugMode);

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
      return checkLatestGitHubRelease();
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
          'Velopack check unavailable; falling back to GitHub release lookup: $e',
          error: e,
          stackTrace: stackTrace,
        );
        return checkLatestGitHubRelease();
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

  /// Queries GitHub `releases/latest` for unpackaged / non-Velopack installs.
  Future<UpdateCheckResult> checkLatestGitHubRelease() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse(latestReleaseApiUrl),
            headers: const {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'Kafkalyzer',
            },
          )
          .timeout(githubRequestTimeout);

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.failed,
          canAutoApply: false,
          errorMessage: 'GitHub API returned HTTP ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.failed,
          canAutoApply: false,
          errorMessage: 'Unexpected GitHub release response format',
        );
      }

      final tagRaw = decoded['tag_name'];
      final latestTuple = tagRaw is String ? parseSemverTuple(tagRaw) : null;
      if (latestTuple == null) {
        return const UpdateCheckResult(
          status: UpdateCheckStatus.failed,
          canAutoApply: false,
          errorMessage: 'Missing or invalid tag_name in GitHub release',
        );
      }

      final latestClean =
          '${latestTuple.$1}.${latestTuple.$2}.${latestTuple.$3}';
      final htmlUrlRaw = decoded['html_url'];
      final safeUrl =
          (htmlUrlRaw is String &&
              htmlUrlRaw.startsWith('$defaultRepositoryUrl/'))
          ? htmlUrlRaw
          : releasesUrl;
      final notes = decoded['body'] is String
          ? decoded['body'] as String
          : null;

      final currentTuple = parseSemverTuple(_currentVersionProvider());
      if (currentTuple == null) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.latestKnown,
          latestVersion: latestClean,
          releaseUrl: safeUrl,
          releaseNotes: notes,
          canAutoApply: false,
        );
      }

      if (_compareSemver(latestTuple, currentTuple) > 0) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.manualUpdateAvailable,
          latestVersion: latestClean,
          releaseUrl: safeUrl,
          releaseNotes: notes,
          canAutoApply: false,
        );
      }

      return UpdateCheckResult(
        status: UpdateCheckStatus.manualUpToDate,
        latestVersion: latestClean,
        releaseUrl: safeUrl,
        releaseNotes: notes,
        canAutoApply: false,
      );
    } catch (e, stackTrace) {
      _logger.w(
        'GitHub latest release lookup failed: $e',
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

  /// Parses `major.minor.patch` from a version string, ignoring leading `v`
  /// and `-prerelease` / `+build` suffixes. Returns `null` if unparseable.
  static (int, int, int)? parseSemverTuple(String raw) {
    var trimmed = raw.trim();
    if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
      trimmed = trimmed.substring(1);
    }
    final plusIdx = trimmed.indexOf('+');
    if (plusIdx != -1) trimmed = trimmed.substring(0, plusIdx);
    final dashIdx = trimmed.indexOf('-');
    if (dashIdx != -1) trimmed = trimmed.substring(0, dashIdx);

    final parts = trimmed.split('.');
    if (parts.length != 3) return null;
    final major = int.tryParse(parts[0]);
    final minor = int.tryParse(parts[1]);
    final patch = int.tryParse(parts[2]);
    if (major == null || minor == null || patch == null) return null;
    if (major < 0 || minor < 0 || patch < 0) return null;
    return (major, minor, patch);
  }

  static int _compareSemver((int, int, int) a, (int, int, int) b) {
    if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
    if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
    return a.$3.compareTo(b.$3);
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

  /// Starts downloading the update package (or reattaches to an in-flight
  /// download, clearing any pending cancellation).
  void startDownload() {
    final current = downloadState.value;
    if (current.phase == DownloadPhase.running) {
      if (current.cancelled) {
        downloadState.value = DownloadState(
          phase: DownloadPhase.running,
          progress: current.progress,
          cancelled: false,
        );
      }
      return;
    }

    downloadState.value = const DownloadState(
      phase: DownloadPhase.running,
      progress: 0,
      cancelled: false,
    );

    try {
      final stream = _downloadStreamFactory();
      _activeDownloadSub = stream.listen(
        (progress) {
          final clamped = progress.clamp(0, 100);
          downloadState.value = DownloadState(
            phase: DownloadPhase.running,
            progress: clamped,
            cancelled: downloadState.value.cancelled,
          );
        },
        onError: (Object error, StackTrace stackTrace) {
          _activeDownloadSub = null;
          _logger.e(
            'Update download failed: $error',
            error: error,
            stackTrace: stackTrace,
          );
          if (downloadState.value.cancelled) {
            downloadState.value = const DownloadState(
              phase: DownloadPhase.idle,
            );
          } else {
            downloadState.value = DownloadState(
              phase: DownloadPhase.failed,
              errorMessage: error.toString(),
            );
          }
        },
        onDone: () {
          _activeDownloadSub = null;
          if (downloadState.value.phase == DownloadPhase.failed) {
            return;
          }
          if (downloadState.value.cancelled) {
            downloadState.value = const DownloadState(
              phase: DownloadPhase.idle,
            );
          } else {
            downloadState.value = const DownloadState(
              phase: DownloadPhase.finished,
              progress: 100,
              cancelled: false,
            );
          }
        },
      );
    } catch (e, stackTrace) {
      _activeDownloadSub = null;
      _logger.e(
        'Failed to start update download: $e',
        error: e,
        stackTrace: stackTrace,
      );
      downloadState.value = DownloadState(
        phase: DownloadPhase.failed,
        errorMessage: e.toString(),
      );
    }
  }

  /// Marks an in-flight download as cancelled so it resets to `idle` on
  /// completion and is never offered for restart.
  void cancelDownload() {
    final current = downloadState.value;
    if (current.phase == DownloadPhase.running && !current.cancelled) {
      downloadState.value = DownloadState(
        phase: DownloadPhase.running,
        progress: current.progress,
        cancelled: true,
      );
    }
  }

  /// Applies the downloaded update package and restarts the application.
  /// Only succeeds when the download finished without cancellation.
  Future<void> applyAndRestart() async {
    if (!downloadState.value.canApply) {
      throw StateError('No completed uncancelled update ready to apply');
    }
    try {
      _logger.i('Applying update and restarting application...');
      await _applyAndRestartFn();
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
  /// Skips the GitHub release lookup in debug mode.
  Future<void> runBackgroundCheck() async {
    if (_backgroundCheckStarted) {
      return;
    }
    _backgroundCheckStarted = true;

    await Future<void>.delayed(backgroundCheckDelay);

    if (!_isInitialized) {
      await initialize();
    }
    if ((!_isInitialized || !isEnvironmentSupported) && _isDebugMode()) {
      return;
    }

    try {
      final result = await checkForUpdates();
      if (result.status == UpdateCheckStatus.updateAvailable &&
          result.updateInfo != null) {
        final version = result.updateInfo!.targetFullRelease.version;
        availableUpdateNotifier.value = AvailableUpdate(
          version: version,
          releaseNotes: result.updateInfo!.targetFullRelease.notesMarkdown,
          canAutoApply: true,
        );
        _logger.i('Background update check found version $version');
      } else if (result.status == UpdateCheckStatus.manualUpdateAvailable &&
          result.latestVersion != null) {
        availableUpdateNotifier.value = AvailableUpdate(
          version: result.latestVersion!,
          releaseNotes: result.releaseNotes,
          releaseUrl: result.releaseUrl,
          canAutoApply: false,
        );
        _logger.i(
          'Background update check found manual release ${result.latestVersion}',
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
    _activeDownloadSub?.cancel();
    availableUpdateNotifier.dispose();
    downloadState.dispose();
    if (_ownsHttpClient) {
      _httpClient.close();
    }
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
