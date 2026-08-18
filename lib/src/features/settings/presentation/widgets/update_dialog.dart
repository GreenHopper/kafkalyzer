import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/update_service.dart';

enum _UpdateDialogStatus {
  checking,
  upToDate,
  available,
  downloading,
  readyToRestart,
  error,
}

class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

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
  String? _errorMessage;
  int _downloadProgress = 0;
  StreamSubscription<int>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _status = _UpdateDialogStatus.checking;
      _errorMessage = null;
    });

    final updateService = getIt<UpdateService>();

    try {
      final isAvailable = await updateService.isUpdateAvailable();
      if (!mounted) return;

      if (isAvailable) {
        final info = await updateService.getLatestUpdateInfo();
        if (!mounted) return;

        setState(() {
          _updateInfo = info;
          _status = _UpdateDialogStatus.available;
        });
      } else {
        setState(() {
          _status = _UpdateDialogStatus.upToDate;
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
    final updateService = getIt<UpdateService>();

    setState(() {
      _status = _UpdateDialogStatus.downloading;
      _downloadProgress = 0;
    });

    _downloadSubscription = updateService.downloadWithProgress().listen(
      (progress) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress;
          if (progress >= 100) {
            _status = _UpdateDialogStatus.readyToRestart;
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error.toString();
          _status = _UpdateDialogStatus.error;
        });
      },
    );
  }

  Future<void> _applyAndRestart() async {
    final updateService = getIt<UpdateService>();
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
              Text(
                l10n.checkingForUpdates,
                style: theme.textTheme.bodyMedium,
              ),
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
        final targetVersion =
            _updateInfo?.targetFullRelease.version ?? '';
        final releaseNotes =
            _updateInfo?.targetFullRelease.notesMarkdown;

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
                border: Border.all(
                  color: theme.colorScheme.outlineVariant,
                ),
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
                color: Colors.green.shade600,
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
                l10n.updateError(_errorMessage ?? 'Unknown error'),
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
      case _UpdateDialogStatus.error:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
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

      case _UpdateDialogStatus.downloading:
        return const [];

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
