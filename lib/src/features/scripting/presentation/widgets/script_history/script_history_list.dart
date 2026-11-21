import 'dart:io';

import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:kafkalyzer/src/ui/widgets/export_notification_helper.dart';
import 'package:kafkalyzer/src/utils/archive_safety.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

class ScriptHistoryList extends StatelessWidget {
  final Script script;
  final List<ScriptRun>? history;
  final Function(ScriptRun) onSelect;
  final Function(ScriptRun)? onRerun;
  final Function(ScriptRun)? onLoadRun;
  final VoidCallback onRefresh;

  const ScriptHistoryList({
    super.key,
    required this.script,
    required this.history,
    required this.onSelect,
    required this.onRefresh,
    this.onRerun,
    this.onLoadRun,
    this.runner,
  });

  /// Session-wide collaborator; null falls back to the application container.
  final ScriptRunner? runner;

  ScriptRunner get _runner => runner ?? getIt<ScriptRunner>();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Divider(),
          Expanded(
            child: history == null
                ? const Center(child: CircularProgressIndicator())
                : history!.isEmpty
                ? Center(
                    child: Text(
                      AppLocalizations.of(context)?.noPastRunsFound ??
                          "No past runs found.",
                    ),
                  )
                : _buildHistoryList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n?.runHistory ?? "Run History",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          IconButton(
            tooltip: l10n?.importRunArchive ?? "Import Run Archive",
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['zip'],
              );

              if (result != null && result.files.single.path != null) {
                try {
                  await _runner.importRunArchive(
                    result.files.single.path!,
                    script,
                  );
                  onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.runArchiveImported ?? 'Run archive imported',
                        ),
                      ),
                    );
                  }
                } on UnsafeArchiveEntryException catch (e) {
                  if (context.mounted) {
                    final l10n = AppLocalizations.of(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.importRejectedUnsafeEntry(e.entryName) ??
                              'Import rejected: unsafe entry (${e.entryName}).',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n?.failedToImportRun(e.toString()) ??
                              'Failed to import run: $e',
                        ),
                      ),
                    );
                  }
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(BuildContext context) {
    return ListView.separated(
      itemCount: history!.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (ctx, index) {
        final run = history![index];
        return _buildHistoryItem(context, run);
      },
    );
  }

  Widget _buildHistoryItem(BuildContext context, ScriptRun run) {
    final dateStr = DateFormatUtils.formatDate(
      context,
      DateTime.fromMillisecondsSinceEpoch(run.timestamp),
    );
    final startTimeStr = run.startTime != null
        ? DateFormatUtils.formatTime(
            context,
            DateTime.fromMillisecondsSinceEpoch(run.startTime!),
          )
        : '';
    final endTimeStr = run.endTime != null
        ? DateFormatUtils.formatTime(
            context,
            DateTime.fromMillisecondsSinceEpoch(run.endTime!),
          )
        : '';
    final timingStr = (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty)
        ? " • $startTimeStr - $endTimeStr"
        : "";

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        leading: Icon(
          _getRunStatusIcon(run.status),
          color: _getRunStatusColor(context, run.status),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                run.scriptName,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 8),
            if (run.totalMessages != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context)?.matchedAnalyzed(
                        run.totalMessages!,
                        run.totalExamined ?? 0,
                      ) ??
                      "${run.totalMessages} matched / ${run.totalExamined ?? 0} analyzed",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "$dateStr$timingStr",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              run.runtime != null
                  ? (AppLocalizations.of(context)?.clusterRuntimeLabel(
                          run.clusterName ??
                              AppLocalizations.of(context)?.defaultLabel ??
                              'Default',
                          _formatDuration(run.runtime),
                        ) ??
                        "Cluster: ${run.clusterName ?? 'Default'} • ${_formatDuration(run.runtime)}")
                  : (AppLocalizations.of(context)?.clusterLabelValue(
                          run.clusterName ??
                              AppLocalizations.of(context)?.defaultLabel ??
                              'Default',
                        ) ??
                        "Cluster: ${run.clusterName ?? 'Default'}"),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (run.parameters.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  run.parameters.entries
                      .map((e) => "${e.key}: ${e.value}")
                      .join(" • "),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary.withAlpha(200),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onRerun != null)
              if (onLoadRun != null)
                IconButton(
                  icon: const Icon(Icons.output),
                  tooltip:
                      AppLocalizations.of(context)?.loadResults ??
                      "Load Results",
                  onPressed: () => onLoadRun!(run),
                ),
            IconButton(
              icon: const Icon(Icons.replay),
              tooltip: AppLocalizations.of(context)?.runAgain ?? "Run Again",
              onPressed: () => onRerun!(run),
            ),
            IconButton(
              key: ValueKey("export_${run.id}"),
              icon: const Icon(Icons.download),
              tooltip:
                  AppLocalizations.of(context)?.exportRunArchive ??
                  "Export Run Archive",
              onPressed: () async {
                final l10n = AppLocalizations.of(context);
                final path = await _runner.exportRunArchive(run);
                if (path != null && context.mounted) {
                  final safeName = run.id.replaceAll(
                    RegExp(r'[<>:"/\\|?*]'),
                    '_',
                  );
                  String? outputFile = await FilePicker.saveFile(
                    dialogTitle: AppLocalizations.of(
                      context,
                    )!.saveRunArchive(run.scriptName),
                    fileName: '$safeName.zip',
                    type: FileType.custom,
                    allowedExtensions: ['zip'],
                  );

                  if (outputFile != null) {
                    await File(path).copy(outputFile);
                    if (context.mounted) {
                      showExportSuccessSnackBar(
                        context,
                        message:
                            l10n?.runArchiveExported ?? 'Run archive exported',
                        filePath: outputFile,
                      );
                    }
                  }
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: Theme.of(context).colorScheme.error,
              tooltip: AppLocalizations.of(context)?.deleteRun ?? "Delete Run",
              onPressed: () async {
                final l10n = AppLocalizations.of(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    final l10n = AppLocalizations.of(context);
                    return AlertDialog(
                      title: Text(
                        l10n?.deleteRunResultTitle ?? 'Delete Run Result',
                      ),
                      content: Text(
                        l10n?.deleteRunResultConfirm ??
                            'Are you sure you want to delete this run result? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(l10n?.cancel ?? 'Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                          child: Text(l10n?.delete ?? 'Delete'),
                        ),
                      ],
                    );
                  },
                );

                if (confirm == true) {
                  try {
                    await _runner.deleteRun(run);
                    onRefresh();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.runResultDeleted ?? 'Run result deleted',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.failedToDeleteRun(e.toString()) ??
                                'Failed to delete run: $e',
                          ),
                        ),
                      );
                    }
                  }
                }
              },
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => onSelect(run),
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return "N/A";
    if (d.inSeconds < 1) return "${d.inMilliseconds}ms";
    if (d.inMinutes < 1) return "${d.inSeconds}s";
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return "${minutes}m ${seconds}s";
  }

  IconData _getRunStatusIcon(ScriptRunStatus status) {
    switch (status) {
      case ScriptRunStatus.completed:
        return Icons.check_circle;
      case ScriptRunStatus.error:
        return Icons.error;
      case ScriptRunStatus.cancelled:
        return Icons.cancel;
      case ScriptRunStatus.running:
        return Icons.play_circle;
      case ScriptRunStatus.pending:
        return Icons.hourglass_empty;
    }
  }

  Color _getRunStatusColor(BuildContext context, ScriptRunStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case ScriptRunStatus.completed:
        return colorScheme.primary;
      case ScriptRunStatus.error:
        return colorScheme.error;
      case ScriptRunStatus.cancelled:
        return colorScheme.tertiary;
      case ScriptRunStatus.running:
        return colorScheme.secondary;
      case ScriptRunStatus.pending:
        return colorScheme.outline;
    }
  }
}
