import 'package:flutter/material.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';

/// Displays a persistent, action-rich SnackBar confirming successful file export/download,
/// offering quick "Open" and "Show in Folder" actions.
void showExportSuccessSnackBar(
  BuildContext context, {
  required String message,
  required String filePath,
  Duration duration = const Duration(seconds: 8),
}) {
  final l10n = AppLocalizations.of(context);
  final theme = Theme.of(context);
  final fileOpener = getIt<FileOpenerService>();

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      content: Text(message),
      action: SnackBarAction(
        label: l10n?.openFile ?? 'Open',
        onPressed: () async {
          final success = await fileOpener.openFile(filePath);
          if (!success && context.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  l10n?.failedToOpenFile(filePath) ??
                      'Failed to open file: $filePath',
                ),
                backgroundColor: theme.colorScheme.error,
              ),
            );
          }
        },
      ),
    ),
  );
}
