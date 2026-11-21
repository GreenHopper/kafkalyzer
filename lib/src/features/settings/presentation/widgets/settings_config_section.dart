import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/import_conflict_dialog.dart';
import 'package:kafkalyzer/src/features/settings/presentation/controllers/settings_import_export_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/passphrase_prompt_dialog.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';

class SettingsConfigSection extends StatelessWidget {
  final AppLocalizations l10n;
  final SettingsImportExportController exportController;

  const SettingsConfigSection({
    super.key,
    required this.l10n,
    required this.exportController,
    this.settingsService,
    this.clusterController,
  });

  /// Session-wide collaborators; null falls back to the application container.
  final SettingsService? settingsService;
  final ClusterListController? clusterController;

  @override
  Widget build(BuildContext context) {
    final settingsService = this.settingsService ?? getIt<SettingsService>();
    final clusterController =
        this.clusterController ?? getIt<ClusterListController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.configuration, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          l10n.globalConfigDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    exportController.exportConfiguration(context, l10n),
                icon: const Icon(Icons.download),
                label: Text(l10n.exportConfiguration),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final importResult = await settingsService
                        .importConfiguration(
                          dialogTitle: l10n.importConfiguration,
                          promptPassphrase: ({required previousAttemptFailed}) {
                            if (!context.mounted) return Future.value(null);
                            return PassphrasePromptDialog.show(
                              context,
                              previousAttemptFailed: previousAttemptFailed,
                            );
                          },
                          onClusterConflict: (imported, suggestedRename) {
                            if (!context.mounted) return Future.value(null);
                            return ImportConflictDialog.show(
                              context,
                              profileName: imported.name,
                              suggestedRename: suggestedRename,
                              takenNormalizedNames: clusterController.clusters
                                  .map((c) => normalizeProfileName(c.name))
                                  .toSet(),
                            );
                          },
                        );
                    if (importResult != null && context.mounted) {
                      final summary = importResult.summary;
                      final message = summary != null
                          ? l10n.importSummary(
                              summary.imported,
                              summary.replaced,
                              summary.renamed,
                              summary.skipped,
                            )
                          : l10n.configurationImportedSuccessfully;
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                  } on EncryptedBundleException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(mapEncryptedBundleError(l10n, e)),
                        ),
                      );
                    }
                  } on StoredDataUnreadableException {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.storeUnreadableActionRefused),
                        ),
                      );
                    }
                  } on UnsafeArchiveEntryException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.importRejectedUnsafeEntry(e.entryName),
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.failedToImport(e.toString())),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.upload),
                label: Text(l10n.importConfiguration),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Maps a failed encrypted import onto the message the UI shows.
String mapEncryptedBundleError(
  AppLocalizations l10n,
  EncryptedBundleException error,
) {
  return switch (error.kind) {
    EncryptedBundleFailure.corrupt => l10n.importEncryptedCorrupt,
    EncryptedBundleFailure.unsupported => l10n.importEncryptedUnsupported,
    EncryptedBundleFailure.tooExpensive => l10n.importEncryptedTooExpensive,
    EncryptedBundleFailure.passphraseTooShort ||
    EncryptedBundleFailure.internal => l10n.failedToImport(
      error.message ?? error.kind.name,
    ),
  };
}
