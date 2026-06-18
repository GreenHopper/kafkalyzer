import 'dart:io';

import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

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
  });

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
                ? const Center(child: Text("No past runs found."))
                : _buildHistoryList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Run History", style: Theme.of(context).textTheme.titleLarge),
          IconButton(
            tooltip: "Import Run Archive",
            icon: const Icon(Icons.upload_file),
            onPressed: () async {
              FilePickerResult? result = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['zip'],
              );

              if (result != null && result.files.single.path != null) {
                try {
                  await getIt<ScriptRunner>().importRunArchive(result.files.single.path!, script);
                  onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Run archive imported')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to import run: $e')));
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
    final dateStr = DateFormatUtils.formatDate(context, DateTime.fromMillisecondsSinceEpoch(run.timestamp));
    final startTimeStr = run.startTime != null
        ? DateFormatUtils.formatTime(context, DateTime.fromMillisecondsSinceEpoch(run.startTime!))
        : '';
    final endTimeStr = run.endTime != null
        ? DateFormatUtils.formatTime(context, DateTime.fromMillisecondsSinceEpoch(run.endTime!))
        : '';
    final timingStr = (startTimeStr.isNotEmpty && endTimeStr.isNotEmpty) ? " • $startTimeStr - $endTimeStr" : "";

    return ListTile(
      leading: Icon(_getRunStatusIcon(run.status), color: _getRunStatusColor(run.status)),
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
          Text("$dateStr$timingStr", style: Theme.of(context).textTheme.bodySmall),
          Text(
            "Cluster: ${run.clusterName ?? 'Default'}${run.runtime != null ? ' • ${_formatDuration(run.runtime)}' : ''}",
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (run.parameters.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                run.parameters.entries.map((e) => "${e.key}: ${e.value}").join(" • "),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.primary.withAlpha(200)),
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
              IconButton(icon: const Icon(Icons.output), tooltip: "Load Results", onPressed: () => onLoadRun!(run)),
          IconButton(icon: const Icon(Icons.replay), tooltip: "Run Again", onPressed: () => onRerun!(run)),
          IconButton(
            key: ValueKey("export_${run.id}"),
            icon: const Icon(Icons.download),
            tooltip: "Export Run Archive",
            onPressed: () async {
              final path = await getIt<ScriptRunner>().exportRunArchive(run);
              if (path != null && context.mounted) {
                final safeName = run.id.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
                String? outputFile = await FilePicker.saveFile(
                  dialogTitle: 'Save Run Archive - ${run.scriptName}',
                  fileName: '$safeName.zip',
                  type: FileType.custom,
                  allowedExtensions: ['zip'],
                );

                if (outputFile != null) {
                  await File(path).copy(outputFile);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Run archive exported')));
                  }
                }
              }
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
            tooltip: "Delete Run",
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Run Result'),
                  content: const Text('Are you sure you want to delete this run result? This cannot be undone.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                try {
                  await getIt<ScriptRunner>().deleteRun(run);
                  onRefresh();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Run result deleted')));
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete run: $e')));
                  }
                }
              }
            },
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => onSelect(run),
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

  Color _getRunStatusColor(ScriptRunStatus status) {
    switch (status) {
      case ScriptRunStatus.completed:
        return Colors.green;
      case ScriptRunStatus.error:
        return Colors.red;
      case ScriptRunStatus.cancelled:
        return Colors.orange;
      case ScriptRunStatus.running:
        return Colors.blue;
      case ScriptRunStatus.pending:
        return Colors.grey;
    }
  }
}
