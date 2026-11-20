import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/export_credentials_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/ui/widgets/export_notification_helper.dart';

/// Drives the export flows of the settings screen: the global configuration
/// export and the export of the selected clusters.
///
/// Dependencies are constructor parameters that default to the service
/// locator, so a test can pass a failing double without touching
/// `dependency_injection.dart`.
class SettingsImportExportController {
  final SettingsService _settingsService;
  final ClusterListController _clusterListController;

  SettingsImportExportController({
    SettingsService? settingsService,
    ClusterListController? clusterListController,
  }) : _settingsService = settingsService ?? getIt<SettingsService>(),
       _clusterListController =
           clusterListController ?? getIt<ClusterListController>();

  /// Shows [message] in a blocking dialog while [action] runs, then closes it.
  Future<T> runWithProgressDialog<T>(
    BuildContext context,
    String message,
    Future<T> Function() action,
  ) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
    try {
      return await action();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  /// Asks whether the export should carry credentials, and collects the
  /// passphrase when it should. Returns null when the user cancels.
  Future<ExportCredentialsChoice?> askForCredentials(
    BuildContext context,
    AppLocalizations l10n, {
    required String title,
  }) {
    return showDialog<ExportCredentialsChoice>(
      context: context,
      builder: (_) => ExportCredentialsDialog(title: title, l10n: l10n),
    );
  }

  /// Exports the global cluster configuration, encrypted when the user chose
  /// a passphrase.
  Future<void> exportConfiguration(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final choice = await askForCredentials(
      context,
      l10n,
      title: l10n.exportConfiguration,
    );

    if (choice == null || !context.mounted) return;

    try {
      final outputFile = choice.passphrase != null
          ? await runWithProgressDialog(
              context,
              l10n.encryptingBundle,
              () => _settingsService.exportConfiguration(
                dialogTitle: l10n.exportConfiguration,
                encryptionPassphrase: choice.passphrase,
              ),
            )
          : await _settingsService.exportConfiguration(
              dialogTitle: l10n.exportConfiguration,
            );
      if (outputFile != null && context.mounted) {
        showExportSuccessSnackBar(
          context,
          message: l10n.configurationExportedSuccessfully,
          filePath: outputFile,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToExport(e.toString()))),
        );
      }
    }
  }

  /// Exports [selectedClusters] as a zip (or an `age` file when the user chose
  /// a passphrase) and writes it to the file the user picked.
  Future<void> exportSelectedClusters(
    BuildContext context,
    AppLocalizations l10n,
    List<ClusterProfile> selectedClusters,
  ) async {
    try {
      final choice = await askForCredentials(context, l10n, title: l10n.export);
      if (choice == null || !context.mounted) return;

      final isEncrypted = choice.passphrase != null;
      final zipBytes = isEncrypted
          ? await runWithProgressDialog(
              context,
              l10n.encryptingBundle,
              () => _clusterListController.exportClustersZip(
                selectedClusters,
                encryptionPassphrase: choice.passphrase,
              ),
            )
          : await _clusterListController.exportClustersZip(selectedClusters);

      final picked = await FilePicker.saveFile(
        dialogTitle: l10n.export,
        fileName: isEncrypted
            ? 'clusters_export.zip.age'
            : 'clusters_export.zip',
        type: FileType.custom,
        allowedExtensions: isEncrypted ? ['age'] : ['zip'],
      );
      if (picked == null) return;

      var outputFile = picked;
      final requiredExt = isEncrypted ? '.age' : '.zip';
      if (!outputFile.toLowerCase().endsWith(requiredExt)) {
        outputFile = '$outputFile$requiredExt';
      }

      final file = File(outputFile);
      await file.writeAsBytes(zipBytes);
      if (context.mounted) {
        showExportSuccessSnackBar(
          context,
          message: l10n.clustersExportedSuccessfully,
          filePath: outputFile,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToExport(e.toString()))),
        );
      }
    }
  }
}
