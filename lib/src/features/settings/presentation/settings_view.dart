import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/passphrase_prompt_dialog.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/services/diagnostics/app_logging.dart';
import 'package:kafkalyzer/src/services/diagnostics/diagnostics_report.dart';
import 'package:kafkalyzer/src/services/diagnostics/error_reporter.dart';
import 'package:kafkalyzer/src/services/file_opener_service.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/services/update_service.dart';
import 'package:kafkalyzer/src/ui/shortcuts/shortcut_overview_dialog.dart';
import 'package:watch_it/watch_it.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/import_conflict_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/read_only_guidance_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:kafkalyzer/src/ui/widgets/export_notification_helper.dart';

import 'package:kafkalyzer/src/features/settings/presentation/widgets/export_credentials_dialog.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/general_settings_section.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/section_reset_confirmation.dart';

import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';

class SettingsView extends WatchingStatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Using a Set to store selected cluster names
  final Set<String> _selectedClusterNames = {};
  final TextEditingController _clusterFilterController =
      TextEditingController();
  String _clusterFilterQuery = '';

  @override
  void dispose() {
    _clusterFilterController.dispose();
    super.dispose();
  }

  void _toggleSelection(String clusterName) {
    setState(() {
      if (_selectedClusterNames.contains(clusterName)) {
        _selectedClusterNames.remove(clusterName);
      } else {
        _selectedClusterNames.add(clusterName);
      }
    });
  }

  void _selectAll(List<ClusterProfile> allClusters) {
    setState(() {
      if (_selectedClusterNames.length == allClusters.length) {
        _selectedClusterNames.clear();
      } else {
        _selectedClusterNames.addAll(allClusters.map((c) => c.name));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clusterController = watchIt<ClusterListController>();
    final activeController = watchIt<ActiveConnectionController>();

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              Text(
                l10n.settings,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildAppearanceSection(context, l10n),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              const GeneralSettingsSection(),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              _buildConfigImportExport(context, l10n),
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              _buildClusterHeader(context, l10n, clusterController),
              const SizedBox(height: 16),
              const Divider(),
              _buildClusterListContent(
                context,
                l10n,
                clusterController,
                activeController,
              ),
              const SizedBox(height: 16),
              const Divider(),
              _buildDiagnosticsSection(context, l10n),
              const SizedBox(height: 16),
              const Divider(),
              _buildAboutAndUpdates(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsSection(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context);
    final logPath = AppLogging.fileLogPath;

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
                final ok = await getIt<FileOpenerService>().showInFolder(
                  logPath,
                );
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
                final activeProfile =
                    getIt.isRegistered<ActiveConnectionController>()
                    ? getIt<ActiveConnectionController>().activeProfile
                    : null;
                final recentErrors = getIt.isRegistered<ErrorReporter>()
                    ? getIt<ErrorReporter>().recent
                    : const <ErrorRecord>[];
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

  Widget _buildAboutAndUpdates(BuildContext context, AppLocalizations l10n) {
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

  Widget _buildAppearanceSection(BuildContext context, AppLocalizations l10n) {
    final appearance = getIt.isRegistered<AppearanceSettings>()
        ? getIt<AppearanceSettings>()
        : AppearanceSettings();
    final timeDisplay = getIt.isRegistered<TimeDisplaySettings>()
        ? getIt<TimeDisplaySettings>()
        : TimeDisplaySettings.fallback;

    return AnimatedBuilder(
      animation: Listenable.merge([appearance, timeDisplay]),
      builder: (context, _) {
        final isCustomScale = !AppearanceSettings.textScalePresets.any(
          (p) => (p - appearance.textScale).abs() < 0.001,
        );
        final scaleEntries = <DropdownMenuEntry<double>>[
          for (final preset in AppearanceSettings.textScalePresets)
            DropdownMenuEntry<double>(
              value: preset,
              label: '${(preset * 100).round()}%',
            ),
          if (isCustomScale)
            DropdownMenuEntry<double>(
              value: appearance.textScale,
              label: l10n.textSizeCustom((appearance.textScale * 100).round()),
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.appearanceSectionTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  key: const Key('reset_appearance_button'),
                  onPressed: () => confirmSectionReset(
                    context,
                    l10n,
                    l10n.appearanceSectionTitle,
                    () async {
                      await appearance.resetToDefaults();
                      timeDisplay.setMode(TimeDisplayMode.local);
                    },
                  ),
                  child: Text(l10n.resetToDefaults),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.themeLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<ThemeMode>(
                      key: const Key('appearance_theme_selector'),
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(l10n.themeSystem),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(l10n.themeLight),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(l10n.themeDark),
                        ),
                      ],
                      selected: {appearance.themeMode},
                      onSelectionChanged: (sel) {
                        appearance.setThemeMode(sel.first);
                      },
                    ),
                  ],
                ),
                DropdownMenu<String>(
                  key: const Key('appearance_language_dropdown'),
                  label: Text(l10n.languageLabel),
                  initialSelection: appearance.locale?.languageCode ?? 'system',
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: 'system',
                      label: l10n.languageSystem,
                    ),
                    DropdownMenuEntry(value: 'en', label: l10n.languageEnglish),
                    DropdownMenuEntry(value: 'de', label: l10n.languageGerman),
                  ],
                  onSelected: (val) {
                    if (val == null || val == 'system') {
                      appearance.setLocale(null);
                    } else {
                      appearance.setLocale(Locale(val));
                    }
                  },
                ),
                DropdownMenu<double>(
                  key: const Key('appearance_text_scale_dropdown'),
                  label: Text(l10n.textSizeLabel),
                  initialSelection: appearance.textScale,
                  dropdownMenuEntries: scaleEntries,
                  onSelected: (val) {
                    if (val != null) {
                      appearance.setTextScale(val);
                    }
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.timeDisplayLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<TimeDisplayMode>(
                      key: const Key('appearance_time_display_selector'),
                      segments: [
                        ButtonSegment(
                          value: TimeDisplayMode.local,
                          label: Text(l10n.timeDisplayLocal),
                        ),
                        ButtonSegment(
                          value: TimeDisplayMode.utc,
                          label: Text(l10n.timeDisplayUtc),
                        ),
                      ],
                      selected: {timeDisplay.value},
                      onSelectionChanged: (sel) {
                        timeDisplay.setMode(sel.first);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildConfigImportExport(BuildContext context, AppLocalizations l10n) {
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
                onPressed: () => _handleExportConfiguration(context, l10n),
                icon: const Icon(Icons.download),
                label: Text(l10n.exportConfiguration),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final settingsService = getIt<SettingsService>();
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
                              takenNormalizedNames:
                                  getIt<ClusterListController>().clusters
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
                          content: Text(_mapEncryptedBundleError(l10n, e)),
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

  Widget _buildClusterHeader(
    BuildContext context,
    AppLocalizations l10n,
    ClusterListController clusterController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  l10n.clusterConfiguration,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (clusterController.clusters.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  TextButton.icon(
                    onPressed: () => _selectAll(clusterController.clusters),
                    icon: Icon(
                      _selectedClusterNames.length ==
                              clusterController.clusters.length
                          ? Icons.deselect
                          : Icons.select_all,
                    ),
                    label: Text(
                      _selectedClusterNames.length ==
                              clusterController.clusters.length
                          ? l10n.deselectAll
                          : l10n.selectAll,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          l10n.clusterExportDescription,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  FilePickerResult? result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json', 'zip', 'age'],
                    withData: true,
                  );

                  if (result != null && result.files.isNotEmpty) {
                    final picked = result.files.single;
                    final rawBytes =
                        picked.bytes ??
                        (picked.path != null
                            ? await File(picked.path!).readAsBytes()
                            : null);
                    if (rawBytes == null) {
                      throw Exception('Could not read imported file');
                    }

                    final decryptedBytes = await decryptIfEncrypted(rawBytes, ({
                      required previousAttemptFailed,
                    }) {
                      if (!context.mounted) return Future.value(null);
                      return PassphrasePromptDialog.show(
                        context,
                        previousAttemptFailed: previousAttemptFailed,
                      );
                    });
                    if (decryptedBytes == null) return;

                    ImportSummary? summary;
                    Future<ImportConflictChoice?> resolveConflict(
                      ClusterProfile imported,
                      String suggestedRename,
                    ) {
                      if (!context.mounted) return Future.value(null);
                      return ImportConflictDialog.show(
                        context,
                        profileName: imported.name,
                        suggestedRename: suggestedRename,
                        takenNormalizedNames: clusterController.clusters
                            .map((c) => normalizeProfileName(c.name))
                            .toSet(),
                      );
                    }

                    if (isZipBytes(decryptedBytes)) {
                      summary = await clusterController.importClustersZip(
                        decryptedBytes,
                        onConflict: resolveConflict,
                      );
                    } else {
                      final jsonString = utf8.decode(decryptedBytes);
                      summary = await clusterController.importClusters(
                        jsonString,
                        onConflict: resolveConflict,
                      );
                    }

                    if (summary != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n.importSummary(
                              summary.imported,
                              summary.replaced,
                              summary.renamed,
                              summary.skipped,
                            ),
                          ),
                        ),
                      );
                    }
                  }
                } on EncryptedBundleException catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_mapEncryptedBundleError(l10n, e)),
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
              icon: const Icon(Icons.file_upload_outlined),
              label: Text(l10n.import),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: _selectedClusterNames.isEmpty
                  ? null
                  : () async {
                      try {
                        final choice = await _askExportCredentials(
                          context,
                          l10n,
                          title: l10n.export,
                        );
                        if (choice == null || !context.mounted) return;

                        final selectedClusters = clusterController.clusters
                            .where(
                              (c) => _selectedClusterNames.contains(c.name),
                            )
                            .toList();
                        final isEncrypted = choice.passphrase != null;
                        final zipBytes = isEncrypted
                            ? await _runWithProgressDialog(
                                context,
                                l10n.encryptingBundle,
                                () => clusterController.exportClustersZip(
                                  selectedClusters,
                                  encryptionPassphrase: choice.passphrase,
                                ),
                              )
                            : await clusterController.exportClustersZip(
                                selectedClusters,
                              );

                        String? outputFile = await FilePicker.saveFile(
                          dialogTitle: l10n.export,
                          fileName: isEncrypted
                              ? 'clusters_export.zip.age'
                              : 'clusters_export.zip',
                          type: FileType.custom,
                          allowedExtensions: isEncrypted ? ['age'] : ['zip'],
                        );

                        if (outputFile != null) {
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
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.failedToExport(e.toString())),
                            ),
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.file_download_outlined),
              label: Text("${l10n.export} (${_selectedClusterNames.length})"),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: () async {
                final result = await showDialog<ClusterProfile>(
                  context: context,
                  builder: (context) => ClusterConfigDialog(
                    existingNames: clusterController.clusters
                        .map((c) => c.name)
                        .toList(),
                  ),
                );
                if (result != null) {
                  clusterController.addCluster(result);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.addCluster),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildClusterListContent(
    BuildContext context,
    AppLocalizations l10n,
    ClusterListController clusterController,
    ActiveConnectionController activeController,
  ) {
    if (clusterController.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final filteredEntries = clusterController.clusters
        .asMap()
        .entries
        .where((e) => matchesClusterFilter(e.value, _clusterFilterQuery))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (clusterController.clusters.isNotEmpty) ...[
          ClusterFilterField(
            controller: _clusterFilterController,
            dense: true,
            onChanged: (q) => setState(() => _clusterFilterQuery = q),
          ),
          const SizedBox(height: 12),
        ],
        if (clusterController.clusters.isNotEmpty && filteredEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(l10n.clusterFilterNoMatch),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    _clusterFilterController.clear();
                    setState(() => _clusterFilterQuery = '');
                  },
                  child: Text(l10n.clusterFilterClear),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredEntries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, filteredIndex) {
              final entry = filteredEntries[filteredIndex];
              final index = entry.key;
              final cluster = entry.value;
              final isActive =
                  activeController.activeProfile?.name == cluster.name;
              final isSelected = _selectedClusterNames.contains(cluster.name);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 8,
                ),
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(cluster.name),
                ),
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      cluster.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    EnvironmentTagChip(profile: cluster, compact: true),
                    if (isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          l10n.active,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                              ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (cluster.securityProtocol != null &&
                                cluster.securityProtocol!.isNotEmpty)
                            ? cluster.securityProtocol!
                            : 'PLAINTEXT',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (cluster.schemaRegistryUrl != null &&
                        cluster.schemaRegistryUrl!.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schema_outlined,
                              size: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onTertiaryContainer,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.schemaRegistryConfiguredBadge,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onTertiaryContainer,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    if (cluster.tlsVerification == TlsVerification.disabled)
                      const InsecureTlsBadge(compact: true),
                  ],
                ),
                subtitle: Text(cluster.bootstrapServers),
                onTap: () => _toggleSelection(cluster.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.content_copy_outlined),
                      tooltip: l10n.duplicateClusterAction,
                      onPressed: () async {
                        final result = await showDialog<ClusterProfile>(
                          context: context,
                          builder: (context) => ClusterConfigDialog(
                            cluster: cluster,
                            isDuplicate: true,
                            existingNames: clusterController.clusters
                                .map((c) => c.name)
                                .toList(),
                          ),
                        );
                        if (result != null) {
                          clusterController.addCluster(result);
                        }
                      },
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: l10n.edit,
                      onPressed: () async {
                        final result = await showDialog<ClusterProfile>(
                          context: context,
                          builder: (context) => ClusterConfigDialog(
                            cluster: cluster,
                            existingNames: clusterController.clusters
                                .asMap()
                                .entries
                                .where((e) => e.key != index)
                                .map((e) => e.value.name)
                                .toList(),
                          ),
                        );
                        if (result != null) {
                          final oldName = cluster.name;
                          clusterController.updateCluster(index, result);

                          // If name changed, update selection set
                          if (oldName != result.name &&
                              _selectedClusterNames.contains(oldName)) {
                            setState(() {
                              _selectedClusterNames.remove(oldName);
                              _selectedClusterNames.add(result.name);
                            });
                          }

                          if (isActive) {
                            activeController.connect(result);
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: l10n.delete,
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l10n.deleteCluster),
                            content: Text(
                              l10n.deleteClusterConfirmation(cluster.name),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: Text(l10n.delete),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          if (isActive) {
                            activeController.disconnect();
                          }
                          clusterController.deleteCluster(index);
                          if (_selectedClusterNames.contains(cluster.name)) {
                            setState(() {
                              _selectedClusterNames.remove(cluster.name);
                            });
                          }
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  String _mapEncryptedBundleError(
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

  Future<T> _runWithProgressDialog<T>(
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

  Future<ExportCredentialsChoice?> _askExportCredentials(
    BuildContext context,
    AppLocalizations l10n, {
    required String title,
  }) {
    return showDialog<ExportCredentialsChoice>(
      context: context,
      builder: (_) => ExportCredentialsDialog(title: title, l10n: l10n),
    );
  }

  Future<void> _handleExportConfiguration(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final choice = await _askExportCredentials(
      context,
      l10n,
      title: l10n.exportConfiguration,
    );

    if (choice == null || !context.mounted) return;

    final settingsService = getIt<SettingsService>();
    try {
      final outputFile = choice.passphrase != null
          ? await _runWithProgressDialog(
              context,
              l10n.encryptingBundle,
              () => settingsService.exportConfiguration(
                dialogTitle: l10n.exportConfiguration,
                encryptionPassphrase: choice.passphrase,
              ),
            )
          : await settingsService.exportConfiguration(
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
}
