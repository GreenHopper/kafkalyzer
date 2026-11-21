import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/services/diagnostics/app_logging.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/ui/shortcuts/shortcut_overview_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';

class SettingsAboutAndUpdatesSection extends StatelessWidget {
  final AppLocalizations l10n;

  const SettingsAboutAndUpdatesSection({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Kafkalyzer v${AppVersionHelper.version}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 8),
            const ReadOnlySecurityBadge(),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => UpdateDialog.show(context),
                  icon: const Icon(Icons.system_update_alt, size: 18),
                  label: Text(l10n.checkForUpdates),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openAboutDialog(context, l10n),
                  icon: const Icon(Icons.info_outline, size: 18),
                  label: Text(l10n.settingsAboutButton),
                ),
                OutlinedButton.icon(
                  onPressed: () => ShortcutOverviewDialog.show(context),
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  label: Text(l10n.settingsKeyboardShortcutsButton),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAboutDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    String dataFolder;
    try {
      dataFolder = (await getApplicationSupportDirectory()).path;
    } catch (_) {
      dataFolder = l10n.diagnosticsUnknown;
    }

    String outputFolder;
    try {
      final prefs = await SharedPreferences.getInstance();
      final dir = prefs.getString('general_default_output_dir');
      outputFolder = (dir != null && dir.trim().isNotEmpty)
          ? dir
          : l10n.diagnosticsUnknown;
    } catch (_) {
      outputFolder = l10n.diagnosticsUnknown;
    }

    final logFolder = AppLogging.logDirectoryPath ?? l10n.diagnosticsUnknown;
    if (!context.mounted) return;

    showAboutDialog(
      context: context,
      applicationName: 'Kafkalyzer',
      applicationVersion: 'v${AppVersionHelper.version}',
      applicationLegalese: l10n.aboutLegalese,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '${l10n.aboutRepositoryLabel}: ',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final ok = await launchUrl(
                    Uri.parse(UpdateService.defaultRepositoryUrl),
                  );
                  if (!ok) {
                    messenger
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: Text(l10n.aboutOpenLinkFailed)),
                      );
                  }
                } catch (_) {
                  messenger
                    ..clearSnackBars()
                    ..showSnackBar(
                      SnackBar(content: Text(l10n.aboutOpenLinkFailed)),
                    );
                }
              },
              child: const Text(UpdateService.defaultRepositoryUrl),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildAboutPathRow(context, l10n.aboutLogFolderLabel, logFolder),
        _buildAboutPathRow(context, l10n.aboutDataFolderLabel, dataFolder),
        _buildAboutPathRow(context, l10n.aboutOutputFolderLabel, outputFolder),
      ],
    );
  }

  Widget _buildAboutPathRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
