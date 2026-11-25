import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/headless_profiles.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:material_ui/material_ui.dart';

/// True when [profile] is marked shared but the latest sync failed for it.
bool mcpSharingFailedFor(ClusterProfile profile, SharedProfilesStatus status) {
  if (profile.headlessShared != true) return false;
  if (status.isOk) return false;
  if (status.fileError != null || status.bridgeError != null) return true;
  return status.failed.any((f) => f.name == profile.name);
}

/// Pretty-printed MCP client JSON for starting kafkalyzer-mcp on [clusterName].
String buildMcpClientSnippet({
  required String command,
  required List<String> leadingArgs,
  required String clusterName,
}) {
  return const JsonEncoder.withIndent('  ').convert({
    'mcpServers': {
      'kafkalyzer': {
        'command': command,
        'args': [...leadingArgs, '--cluster', clusterName],
      },
    },
  });
}

/// Dialog to share one cluster profile with headless kafkalyzer / MCP clients.
class McpSharingDialog extends StatefulWidget {
  final ClusterProfile profile;
  final int index;
  final ClusterListController? clusterController;
  final Future<McpServerLaunch> Function()? launchLoader;

  const McpSharingDialog({
    super.key,
    required this.profile,
    required this.index,
    this.clusterController,
    this.launchLoader,
  });

  static Future<void> show(
    BuildContext context, {
    required ClusterProfile profile,
    required int index,
    ClusterListController? clusterController,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => McpSharingDialog(
        profile: profile,
        index: index,
        clusterController: clusterController,
      ),
    );
  }

  @override
  State<McpSharingDialog> createState() => _McpSharingDialogState();
}

class _McpSharingDialogState extends State<McpSharingDialog> {
  late bool _shared;
  bool _busy = false;
  McpServerLaunch? _launch;
  String? _launchError;

  ClusterListController get _controller =>
      widget.clusterController ?? getIt<ClusterListController>();

  @override
  void initState() {
    super.initState();
    _shared = widget.profile.headlessShared == true;
    _loadLaunch();
  }

  Future<void> _loadLaunch() async {
    try {
      final loader = widget.launchLoader ?? mcpServerLaunch;
      final launch = await loader();
      if (!mounted) return;
      setState(() {
        _launch = launch;
        _launchError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _launchError = e.toString();
      });
    }
  }

  Future<void> _onToggle(bool value) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await _controller.updateCluster(
        widget.index,
        widget.profile.copyWith(headlessShared: value),
      );
      if (!mounted) return;
      final status = _controller.sharedProfilesStatus.value;
      if (!status.isOk) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.mcpSharingToggleFailed)));
        // Keep switch reflecting persisted intent only when sync succeeded.
        setState(() {
          _shared = _controller.clusters[widget.index].headlessShared == true;
          _busy = false;
        });
        return;
      }
      setState(() {
        _shared = value;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mcpSharingToggleFailed)));
      setState(() => _busy = false);
    }
  }

  Future<void> _copySnippet(String snippet) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: snippet));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.mcpSharingCopiedConfirmation)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final launch = _launch;
    final snippet = launch == null
        ? null
        : buildMcpClientSnippet(
            command: launch.command,
            leadingArgs: launch.leadingArgs,
            clusterName: widget.profile.name,
          );
    final snippetText = snippet;
    final canCopy = _shared && snippetText != null;

    return AlertDialog(
      title: Text(l10n.mcpSharingDialogTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(widget.profile.name, style: theme.textTheme.titleMedium),
                  EnvironmentTagChip(profile: widget.profile, compact: true),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.mcpSharingDataFlowWarning,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.mcpSharingSwitchLabel),
                value: _shared,
                onChanged: _busy ? null : _onToggle,
              ),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                l10n.mcpSharingSnippetLabel,
                style: theme.textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              if (snippetText != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    snippetText,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                )
              else if (_launchError != null)
                Text(_launchError!, style: theme.textTheme.bodySmall)
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (launch != null && !launch.exists) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.mcpSharingProgramNotFoundHint(launch.command),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              if (!_shared) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.mcpSharingShareFirstHint,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: canCopy ? () => _copySnippet(snippetText) : null,
          child: Text(l10n.mcpSharingCopyAction),
        ),
      ],
    );
  }
}
