import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

enum _UpdateDialogStatus {
  checking,
  upToDate,
  available,
  manualAvailable,
  manualUpToDate,
  latestKnown,
  downloading,
  readyToRestart,
  unsupportedEnvironment,
  error,
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key, this.updateService});

  /// Null falls back to the application container; a test injects its own.
  final UpdateService? updateService;

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpdateDialog(),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  _UpdateDialogStatus _status = _UpdateDialogStatus.checking;
  UpdateInfo? _updateInfo;
  String? _latestVersion;
  String? _releaseUrl;
  String? _releaseNotes;
  String? _errorMessage;
  int _downloadProgress = 0;

  UpdateService get _updateService =>
      widget.updateService ?? getIt<UpdateService>();

  @override
  void initState() {
    super.initState();
    final updateService = _updateService;
    updateService.downloadState.addListener(_onDownloadStateChanged);
    final dl = updateService.downloadState.value;
    if (dl.phase == DownloadPhase.running && !dl.cancelled) {
      _status = _UpdateDialogStatus.downloading;
      _downloadProgress = dl.progress;
    } else if (dl.canApply) {
      _status = _UpdateDialogStatus.readyToRestart;
      _downloadProgress = 100;
    } else {
      _checkForUpdates();
    }
  }

  @override
  void dispose() {
    _updateService.downloadState.removeListener(_onDownloadStateChanged);
    super.dispose();
  }

  void _onDownloadStateChanged() {
    if (!mounted) return;
    final dl = _updateService.downloadState.value;
    setState(() {
      _downloadProgress = dl.progress;
      if (dl.phase == DownloadPhase.running && !dl.cancelled) {
        _status = _UpdateDialogStatus.downloading;
      } else if (dl.canApply) {
        _status = _UpdateDialogStatus.readyToRestart;
      } else if (dl.phase == DownloadPhase.failed) {
        _errorMessage = dl.errorMessage;
        _status = _UpdateDialogStatus.error;
      }
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _status = _UpdateDialogStatus.checking;
      _errorMessage = null;
    });

    final updateService = _updateService;

    try {
      final result = await updateService.checkForUpdates();
      if (!mounted) return;

      switch (result.status) {
        case UpdateCheckStatus.updateAvailable:
          setState(() {
            _updateInfo = result.updateInfo;
            _status = _UpdateDialogStatus.available;
          });
        case UpdateCheckStatus.upToDate:
          setState(() {
            _status = _UpdateDialogStatus.upToDate;
          });
        case UpdateCheckStatus.manualUpdateAvailable:
          setState(() {
            _latestVersion = result.latestVersion;
            _releaseUrl = result.releaseUrl;
            _releaseNotes = result.releaseNotes;
            _status = _UpdateDialogStatus.manualAvailable;
          });
        case UpdateCheckStatus.manualUpToDate:
          setState(() {
            _latestVersion = result.latestVersion;
            _releaseUrl = result.releaseUrl;
            _status = _UpdateDialogStatus.manualUpToDate;
          });
        case UpdateCheckStatus.latestKnown:
          setState(() {
            _latestVersion = result.latestVersion;
            _releaseUrl = result.releaseUrl;
            _status = _UpdateDialogStatus.latestKnown;
          });
        case UpdateCheckStatus.unsupportedEnvironment:
          setState(() {
            _errorMessage = result.errorMessage;
            _status = _UpdateDialogStatus.unsupportedEnvironment;
          });
        case UpdateCheckStatus.failed:
          setState(() {
            _errorMessage = result.errorMessage;
            _status = _UpdateDialogStatus.error;
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _status = _UpdateDialogStatus.error;
      });
    }
  }

  void _startDownload() {
    _updateService.startDownload();
  }

  void _cancelDownload(AppLocalizations l10n) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    _updateService.cancelDownload();
    Navigator.of(context).pop();
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.downloadCancelledSnackbar)),
    );
  }

  Future<void> _applyAndRestart() async {
    final updateService = _updateService;
    try {
      await updateService.applyAndRestart();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _status = _UpdateDialogStatus.error;
      });
    }
  }

  Future<void> _openGitHubReleases() async {
    final uri = Uri.parse(_releaseUrl ?? UpdateService.releasesUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.system_update_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Text(l10n.checkForUpdates),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 480),
        child: _buildContent(context, l10n, theme),
      ),
      actions: _buildActions(context, l10n, theme),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (_status) {
      case _UpdateDialogStatus.checking:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l10n.checkingForUpdates, style: theme.textTheme.bodyMedium),
            ],
          ),
        );

      case _UpdateDialogStatus.upToDate:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appUpToDate,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.appUpToDateDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );

      case _UpdateDialogStatus.available:
        final targetVersion = _updateInfo?.targetFullRelease.version ?? '';
        final releaseNotes = _updateInfo?.targetFullRelease.notesMarkdown;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.new_releases_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.updateAvailable,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (targetVersion.isNotEmpty) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'v$targetVersion',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.releaseNotes,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: SingleChildScrollView(
                child: Text(
                  (releaseNotes != null && releaseNotes.trim().isNotEmpty)
                      ? releaseNotes
                      : l10n.noReleaseNotes,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
          ],
        );

      case _UpdateDialogStatus.manualAvailable:
        final version = _latestVersion ?? '';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.new_releases_outlined,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.manualUpdateAvailableTitle(version),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.manualUpdateAvailableBody(version),
              style: theme.textTheme.bodyMedium,
            ),
            if (_releaseNotes != null && _releaseNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: Text(_releaseNotes!, style: theme.textTheme.bodySmall),
                ),
              ),
            ],
          ],
        );

      case _UpdateDialogStatus.manualUpToDate:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.appUpToDate,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.manualUpToDateHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );

      case _UpdateDialogStatus.latestKnown:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.latestReleaseKnownBody(_latestVersion ?? ''),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        );

      case _UpdateDialogStatus.downloading:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l10n.downloadingUpdate} ($_downloadProgress%)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress / 100.0,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          ),
        );

      case _UpdateDialogStatus.readyToRestart:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.published_with_changes,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.updateReadyRestart,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case _UpdateDialogStatus.unsupportedEnvironment:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 48,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.updateUnsupportedEnvironment,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.updateUnsupportedEnvironmentDescription,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        );

      case _UpdateDialogStatus.error:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.updateError(_errorMessage ?? l10n.unknownError),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        );
    }
  }

  List<Widget> _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
  ) {
    switch (_status) {
      case _UpdateDialogStatus.checking:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ];

      case _UpdateDialogStatus.upToDate:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ];

      case _UpdateDialogStatus.unsupportedEnvironment:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          FilledButton.icon(
            onPressed: _openGitHubReleases,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openGitHubReleases),
          ),
        ];

      case _UpdateDialogStatus.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          TextButton.icon(
            onPressed: _openGitHubReleases,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openGitHubReleases),
          ),
          FilledButton.icon(
            onPressed: _checkForUpdates,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ];

      case _UpdateDialogStatus.available:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton.icon(
            onPressed: _startDownload,
            icon: const Icon(Icons.download),
            label: Text(l10n.downloadUpdate),
          ),
        ];

      case _UpdateDialogStatus.manualAvailable:
      case _UpdateDialogStatus.latestKnown:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          FilledButton.icon(
            onPressed: _openGitHubReleases,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openReleasePage),
          ),
        ];

      case _UpdateDialogStatus.manualUpToDate:
        return [
          TextButton.icon(
            onPressed: _openGitHubReleases,
            icon: const Icon(Icons.open_in_new),
            label: Text(l10n.openReleasePage),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ];

      case _UpdateDialogStatus.downloading:
        return [
          TextButton(
            onPressed: () => _cancelDownload(l10n),
            child: Text(l10n.cancel),
          ),
        ];

      case _UpdateDialogStatus.readyToRestart:
        return [
          FilledButton.icon(
            onPressed: _applyAndRestart,
            icon: const Icon(Icons.restart_alt),
            label: Text(l10n.restartNow),
          ),
        ];
    }
  }
}
