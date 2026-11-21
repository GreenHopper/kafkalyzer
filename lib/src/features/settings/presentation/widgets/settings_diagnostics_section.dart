import 'package:flutter/services.dart';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/diagnostics/app_logging.dart';
import 'package:kafkalyzer/src/services/diagnostics/diagnostics_report.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';

class SettingsDiagnosticsSection extends StatelessWidget {
  final AppLocalizations l10n;

  const SettingsDiagnosticsSection({
    super.key,
    required this.l10n,
    this.fileOpener,
    this.activeConnection,
    this.errorReporter,
  });

  /// Session-wide collaborators; null falls back to the application container.
  final FileOpenerService? fileOpener;
  final ActiveConnectionController? activeConnection;
  final ErrorReporter? errorReporter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logPath = AppLogging.fileLogPath;
    final fileOpener = this.fileOpener ?? getIt<FileOpenerService>();
    final activeConnection =
        this.activeConnection ??
        (getIt.isRegistered<ActiveConnectionController>()
            ? getIt<ActiveConnectionController>()
            : null);
    final errorReporter =
        this.errorReporter ??
        (getIt.isRegistered<ErrorReporter>() ? getIt<ErrorReporter>() : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsDiagnosticsTitle, style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${l10n.settingsDiagnosticsLogPathLabel}: '
          '${logPath ?? l10n.settingsFileLoggingUnavailable}',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                if (logPath == null || logPath.isEmpty) {
                  messenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.settingsOpenLogFolderFailed(
                            l10n.diagnosticsUnavailable,
                          ),
                        ),
                      ),
                    );
                  return;
                }
                final ok = await fileOpener.showInFolder(logPath);
                if (!ok) {
                  messenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.settingsOpenLogFolderFailed(logPath),
                        ),
                      ),
                    );
                }
              },
              icon: const Icon(Icons.folder_open, size: 18),
              label: Text(l10n.settingsOpenLogFolder),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final activeProfile = activeConnection?.activeProfile;
                final recentErrors =
                    errorReporter?.recent ?? const <ErrorRecord>[];
                final report = DiagnosticsReport.build(
                  appVersion: AppVersionHelper.version,
                  osName: Platform.operatingSystem,
                  osVersion: Platform.operatingSystemVersion,
                  locale: Localizations.localeOf(context).toLanguageTag(),
                  logPath: logPath,
                  activeProfile: activeProfile,
                  recentErrors: recentErrors,
                );
                try {
                  await Clipboard.setData(ClipboardData(text: report));
                  messenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(content: Text(l10n.settingsDiagnosticsCopied)),
                    );
                } catch (_) {
                  messenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(content: Text(l10n.errorDetailsCopyFailed)),
                    );
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: Text(l10n.settingsCopyDiagnostics),
            ),
          ],
        ),
      ],
    );
  }
}
