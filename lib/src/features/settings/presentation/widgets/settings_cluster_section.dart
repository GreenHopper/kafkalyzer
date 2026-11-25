import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/passphrase_prompt_dialog.dart';
import 'package:kafkalyzer/src/services/encrypted_bundle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:watch_it/watch_it.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/config_dialog/cluster_config_dialog.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/mcp_sharing_dialog.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/import_conflict_dialog.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/rust/api/headless_profiles.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/services/stored_list.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:kafkalyzer/src/features/settings/presentation/controllers/settings_import_export_controller.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/settings_config_section.dart';

/// The cluster list of the settings screen: filtering, selection, import,
/// export and the per-cluster actions.
class SettingsClusterSection extends WatchingStatefulWidget {
  final AppLocalizations l10n;
  final SettingsImportExportController exportController;

  const SettingsClusterSection({
    super.key,
    required this.l10n,
    required this.exportController,
  });

  @override
  State<SettingsClusterSection> createState() => _SettingsClusterSectionState();
}

class _SettingsClusterSectionState extends State<SettingsClusterSection> {
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
    final clusterController = watchIt<ClusterListController>();
    final activeController = watchIt<ActiveConnectionController>();
    final l10n = widget.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildClusterHeader(context, l10n, clusterController),
        const SizedBox(height: 16),
        const Divider(),
        _buildClusterListContent(
          context,
          l10n,
          clusterController,
          activeController,
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
                      SnackBar(content: Text(mapEncryptedBundleError(l10n, e))),
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
                  : () => widget.exportController.exportSelectedClusters(
                      context,
                      l10n,
                      clusterController.clusters
                          .where((c) => _selectedClusterNames.contains(c.name))
                          .toList(),
                    ),
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

  String _sharingFailureReason(
    AppLocalizations l10n,
    SharedProfileFailureKind kind,
  ) {
    return switch (kind) {
      SharedProfileFailureKind.keyringUnavailable =>
        l10n.mcpSharingFailureKeyringUnavailable,
      SharedProfileFailureKind.secretRejected =>
        l10n.mcpSharingFailureSecretRejected,
    };
  }

  Widget _buildSharingStatusBanner(
    BuildContext context,
    AppLocalizations l10n,
    ClusterListController clusterController,
    SharedProfilesStatus status,
  ) {
    final theme = Theme.of(context);
    final lines = <String>[];
    if (status.bridgeError != null) {
      lines.add(l10n.mcpSharingFailureBridgeError(status.bridgeError!));
    }
    if (status.fileError != null) {
      lines.add(l10n.mcpSharingFailureFileError(status.fileError!));
    }
    for (final failure in status.failed) {
      lines.add(
        l10n.mcpSharingFailureNamed(
          failure.name,
          _sharingFailureReason(l10n, failure.kind),
        ),
      );
    }
    if (lines.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.error_outline,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lines.join('\n'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => clusterController.retrySharedProfilesSync(),
                child: Text(l10n.mcpSharingRetry),
              ),
            ],
          ),
        ),
      ),
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
    final sharingStatus = watch(clusterController.sharedProfilesStatus).value;
    final filteredEntries = clusterController.clusters
        .asMap()
        .entries
        .where((e) => matchesClusterFilter(e.value, _clusterFilterQuery))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!sharingStatus.isOk)
          _buildSharingStatusBanner(
            context,
            l10n,
            clusterController,
            sharingStatus,
          ),
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
                    if (mcpSharingFailedFor(cluster, sharingStatus))
                      _McpSharingBadge(
                        label: l10n.mcpSharingFailedBadge,
                        icon: Icons.error_outline,
                        container: Theme.of(context).colorScheme.errorContainer,
                        onContainer: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                      )
                    else if (cluster.headlessShared == true)
                      _McpSharingBadge(
                        label: l10n.mcpSharedBadge,
                        icon: Icons.hub_outlined,
                        container: Theme.of(
                          context,
                        ).colorScheme.secondaryContainer,
                        onContainer: Theme.of(
                          context,
                        ).colorScheme.onSecondaryContainer,
                      ),
                  ],
                ),
                subtitle: Text(cluster.bootstrapServers),
                onTap: () => _toggleSelection(cluster.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.hub_outlined),
                      tooltip: l10n.mcpSharingOpenAction,
                      onPressed: () => McpSharingDialog.show(
                        context,
                        profile: cluster,
                        index: index,
                        clusterController: clusterController,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.content_copy_outlined),
                      tooltip: l10n.duplicateClusterAction,
                      onPressed: () async {
                        final result = await showDialog<ClusterProfile>(
                          context: context,
                          builder: (context) => ClusterConfigDialog(
                            cluster: cluster.copyWith(headlessShared: null),
                            isDuplicate: true,
                            existingNames: clusterController.clusters
                                .map((c) => c.name)
                                .toList(),
                          ),
                        );
                        if (result != null) {
                          clusterController.addCluster(
                            result.copyWith(headlessShared: null),
                          );
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
}

class _McpSharingBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color container;
  final Color onContainer;

  const _McpSharingBadge({
    required this.label,
    required this.icon,
    required this.container,
    required this.onContainer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: container,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onContainer),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
