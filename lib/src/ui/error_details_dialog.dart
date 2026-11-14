import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';

class ErrorDetailsDialog extends StatelessWidget {
  final ErrorRecord record;

  const ErrorDetailsDialog({super.key, required this.record});

  static Future<void> show(BuildContext context, ErrorRecord record) {
    return showDialog<void>(
      context: context,
      builder: (_) => ErrorDetailsDialog(record: record),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final details = record.formatDetails(
      appVersion: AppVersionHelper.version,
      osSummary:
          '${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
    );

    return AlertDialog(
      title: Text(l10n.errorDetailsDialogTitle),
      content: SizedBox(
        width: 600,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 320),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              details,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            try {
              await Clipboard.setData(ClipboardData(text: details));
              messenger
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.errorDetailsCopied)),
                );
            } catch (_) {
              messenger
                ..clearSnackBars()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.errorDetailsCopyFailed)),
                );
            }
          },
          icon: const Icon(Icons.copy),
          label: Text(l10n.errorCopyDetails),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
