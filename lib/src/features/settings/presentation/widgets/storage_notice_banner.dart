import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/services/secure_storage_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:material_ui/material_ui.dart';

/// Displays persistent, non-blocking warnings for keyring unavailability,
/// unreadable or partially unreadable stores, and duplicate profile names.
class StorageNoticeBanner extends StatelessWidget {
  final ValueListenable<bool>? keyringUnavailableOverride;
  final ClusterListController? clusterControllerOverride;
  final ScriptController? scriptControllerOverride;

  const StorageNoticeBanner({
    super.key,
    this.keyringUnavailableOverride,
    this.clusterControllerOverride,
    this.scriptControllerOverride,
  });

  @override
  Widget build(BuildContext context) {
    final ValueListenable<bool>? keyringUnavailable =
        keyringUnavailableOverride ??
        (getIt.isRegistered<SecureStorageService>()
            ? getIt<SecureStorageService>().unavailable
            : null);
    final ClusterListController? clusterController =
        clusterControllerOverride ??
        (getIt.isRegistered<ClusterListController>()
            ? getIt<ClusterListController>()
            : null);
    final ScriptController? scriptController =
        scriptControllerOverride ??
        (getIt.isRegistered<ScriptController>()
            ? getIt<ScriptController>()
            : null);

    final listenables = <Listenable>[
      ?keyringUnavailable,
      ?clusterController,
      ?scriptController,
    ];

    if (listenables.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final isKeyringUnavailable = keyringUnavailable?.value ?? false;
        final clusterStatus =
            clusterController?.storeStatus ?? const StoreStatus.ok();
        final scriptStatus =
            scriptController?.storeStatus ?? const StoreStatus.ok();

        final notices = <Widget>[];

        if (isKeyringUnavailable) {
          notices.add(
            _NoticeRow(
              icon: Icons.key_off_outlined,
              iconSemanticLabel: 'Keyring unavailable',
              message:
                  l10n?.keyringUnavailableNotice ??
                  'System keyring is unavailable. Credentials are kept in memory for this session only and will not be persisted securely.',
              isError: true,
            ),
          );
        }

        if (clusterStatus.isUnreadable && clusterController != null) {
          notices.add(
            _UnreadableNoticeRow(
              message:
                  l10n?.profileStoreUnreadableNotice ??
                  'Saved cluster profiles could not be read and were left untouched so nothing is lost.',
              backupPath: clusterStatus.backupPath,
              onDiscard: clusterController.discardUnreadable,
            ),
          );
        } else if (clusterStatus.isPartiallyUnreadable) {
          notices.add(
            _NoticeRow(
              icon: Icons.warning_amber_rounded,
              iconSemanticLabel: 'Partially unreadable cluster profiles',
              message:
                  l10n?.storePartiallyUnreadable(
                    clusterStatus.unreadableCount,
                    'cluster_profiles',
                  ) ??
                  '${clusterStatus.unreadableCount} unreadable cluster profile entries were skipped and preserved.',
              isError: false,
            ),
          );
        }

        if (clusterStatus.hasDuplicates) {
          final names = clusterStatus.duplicateNames.join(', ');
          notices.add(
            _NoticeRow(
              icon: Icons.warning_amber_rounded,
              iconSemanticLabel: 'Duplicate cluster profile names',
              message:
                  l10n?.duplicateProfileNamesNotice(names) ??
                  'Duplicate cluster profile names detected: $names. Please rename duplicates so each profile has a unique name.',
              isError: false,
            ),
          );
        }

        if (scriptStatus.isUnreadable && scriptController != null) {
          notices.add(
            _UnreadableNoticeRow(
              message:
                  l10n?.scriptStoreUnreadableNotice ??
                  'Saved scripts could not be read and were left untouched so nothing is lost.',
              backupPath: scriptStatus.backupPath,
              onDiscard: scriptController.discardUnreadable,
            ),
          );
        } else if (scriptStatus.isPartiallyUnreadable) {
          notices.add(
            _NoticeRow(
              icon: Icons.warning_amber_rounded,
              iconSemanticLabel: 'Partially unreadable scripts',
              message:
                  l10n?.storePartiallyUnreadable(
                    scriptStatus.unreadableCount,
                    'saved_scripts_v1',
                  ) ??
                  '${scriptStatus.unreadableCount} unreadable script entries were skipped and preserved.',
              isError: false,
            ),
          );
        }

        if (notices.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(mainAxisSize: MainAxisSize.min, children: notices);
      },
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final IconData icon;
  final String iconSemanticLabel;
  final String message;
  final bool isError;

  const _NoticeRow({
    required this.icon,
    required this.iconSemanticLabel,
    required this.message,
    required this.isError,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = isError
        ? colorScheme.errorContainer
        : colorScheme.tertiaryContainer;
    final fgColor = isError
        ? colorScheme.onErrorContainer
        : colorScheme.onTertiaryContainer;

    return Semantics(
      container: true,
      child: Material(
        color: bgColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: fgColor,
                semanticLabel: iconSemanticLabel,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: fgColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadableNoticeRow extends StatelessWidget {
  final String message;
  final String? backupPath;
  final Future<void> Function() onDiscard;

  const _UnreadableNoticeRow({
    required this.message,
    required this.backupPath,
    required this.onDiscard,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final bgColor = colorScheme.errorContainer;
    final fgColor = colorScheme.onErrorContainer;
    final backupText = backupPath != null
        ? (l10n?.storeBackupLocation(backupPath!) ??
              'Backup saved at: $backupPath')
        : (l10n?.storeBackupFailed ?? 'No backup file could be written.');

    return Semantics(
      container: true,
      child: Material(
        color: bgColor,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                size: 18,
                color: fgColor,
                semanticLabel:
                    l10n?.unreadableStoredData ?? 'Unreadable stored data',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: fgColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      backupText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: fgColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (backupPath != null)
                Tooltip(
                  message: l10n?.copyBackupPath ?? 'Copy backup path',
                  child: TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: backupPath!));
                    },
                    child: Text(l10n?.copyBackupPath ?? 'Copy backup path'),
                  ),
                ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    l10n?.discardUnreadableData ?? 'Discard unreadable data',
                child: TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: Text(
                          l10n?.discardUnreadableData ??
                              'Discard unreadable data',
                        ),
                        content: Text(
                          l10n?.discardUnreadableConfirm ??
                              'This will permanently delete the unreadable stored data so you can save new items. Continue?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: Text(l10n?.cancel ?? 'Cancel'),
                          ),
                          FilledButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: Text(
                              l10n?.discardUnreadableData ??
                                  'Discard unreadable data',
                            ),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await onDiscard();
                    }
                  },
                  child: Text(
                    l10n?.discardUnreadableData ?? 'Discard unreadable data',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
