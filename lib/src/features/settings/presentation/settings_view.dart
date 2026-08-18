import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/settings_service.dart';
import 'package:watch_it/watch_it.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kafkalyzer/src/utils/app_version_helper.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';

import 'package:kafkalyzer/src/features/settings/presentation/widgets/update_dialog.dart';

class SettingsView extends WatchingStatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Using a Set to store selected cluster names
  final Set<String> _selectedClusterNames = {};

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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            Text(
              l10n.settings,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            _buildGeneralSettings(context, l10n),
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
            _buildAboutAndUpdates(context, l10n),
          ],
        ),
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
            OutlinedButton.icon(
              onPressed: () => UpdateDialog.show(context),
              icon: const Icon(Icons.system_update_alt, size: 18),
              label: Text(l10n.checkForUpdates),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettings(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.general, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        FutureBuilder<SharedPreferences>(
          future: SharedPreferences.getInstance(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final prefs = snapshot.data!;
            final defaultDir = prefs.getString('general_default_output_dir');
            final maxRuns = prefs.getInt('scripting_max_run_history') ?? 30;
            final maxLagQueries =
                prefs.getInt('consumer_max_concurrent_queries') ?? 5;
            final isGerman =
                Localizations.localeOf(context).languageCode == 'de';

            final controller = TextEditingController(text: defaultDir);
            final maxRunsController = TextEditingController(
              text: maxRuns.toString(),
            );
            final maxLagQueriesController = TextEditingController(
              text: maxLagQueries.toString(),
            );

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: l10n.defaultScriptOutputDir,
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.folder_open),
                            onPressed: () async {
                              String? selected =
                                  await FilePicker.getDirectoryPath();
                              if (selected != null) {
                                await prefs.setString(
                                  'general_default_output_dir',
                                  selected,
                                );
                                controller.text = selected;
                                getIt<MultiSearchController>().loadDirectory();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxRunsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.maxScriptRunHistory,
                          border: const OutlineInputBorder(),
                          helperText: "Default: 30",
                        ),
                        onChanged: (value) {
                          final val = int.tryParse(value);
                          if (val != null) {
                            prefs.setInt('scripting_max_run_history', val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: maxLagQueriesController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: isGerman
                              ? "Maximale gleichzeitige Lag-Abfragen"
                              : "Maximum Concurrent Lag Queries",
                          border: const OutlineInputBorder(),
                          helperText: isGerman
                              ? "Standard: 5 (Höhere Werte können "
                                    "zu Lasten der Performance gehen)"
                              : "Default: 5 (Higher values can "
                                    "impact performance)",
                        ),
                        onChanged: (value) {
                          final val = int.tryParse(value);
                          if (val != null) {
                            prefs.setInt(
                              'consumer_max_concurrent_queries',
                              val,
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildConfigImportExport(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.configuration, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final settingsService = getIt<SettingsService>();
                  try {
                    await settingsService.exportConfiguration();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.configurationExportedSuccessfully),
                        ),
                      );
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
                    await settingsService.importConfiguration();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.configurationImportedSuccessfully),
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
    return Row(
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
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  FilePickerResult? result = await FilePicker.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['json', 'zip'],
                  );

                  if (result != null && result.files.single.path != null) {
                    final file = File(result.files.single.path!);
                    final extension = result.files.single.extension
                        ?.toLowerCase();

                    if (extension == 'zip') {
                      final bytes = await file.readAsBytes();
                      await clusterController.importClustersZip(bytes);
                    } else {
                      final jsonString = await file.readAsString();
                      await clusterController.importClusters(jsonString);
                    }

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.clustersImportedSuccessfully),
                        ),
                      );
                    }
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
                        final selectedClusters = clusterController.clusters
                            .where(
                              (c) => _selectedClusterNames.contains(c.name),
                            )
                            .toList();
                        final zipBytes = await clusterController
                            .exportClustersZip(selectedClusters);

                        String? outputFile = await FilePicker.saveFile(
                          dialogTitle: l10n.export,
                          fileName: 'clusters_export.zip',
                          type: FileType.custom,
                          allowedExtensions: ['zip'],
                        );

                        if (outputFile != null) {
                          // Ensure extension
                          if (!outputFile.toLowerCase().endsWith('.zip')) {
                            outputFile = '$outputFile.zip';
                          }

                          final file = File(outputFile);
                          await file.writeAsBytes(zipBytes);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  l10n.clustersExportedSuccessfully,
                                ),
                              ),
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
                  builder: (context) => const ClusterConfigDialog(),
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
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: clusterController.clusters.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final cluster = clusterController.clusters[index];
        final isActive = activeController.activeProfile?.name == cluster.name;
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
          title: Row(
            children: [
              Text(
                cluster.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (isActive) ...[
                const SizedBox(width: 8),
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
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(cluster.bootstrapServers),
          onTap: () => _toggleSelection(cluster.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: l10n.edit,
                onPressed: () async {
                  final result = await showDialog<ClusterProfile>(
                    context: context,
                    builder: (context) => ClusterConfigDialog(cluster: cluster),
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
    );
  }
}
