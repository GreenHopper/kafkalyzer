import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';

class TopicProgressTile extends StatelessWidget {
  final String topic;
  final StepStatus status;
  final SearchProgress? progress;
  final int? matchCount;
  final bool dense;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? trailing;
  final Widget? extraSubtitle;

  const TopicProgressTile({
    super.key,
    required this.topic,
    required this.status,
    this.progress,
    this.matchCount,
    this.dense = true,
    this.contentPadding = const EdgeInsets.only(left: 32, right: 32),
    this.trailing,
    this.extraSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: dense,
      contentPadding: contentPadding,
      leading: Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 16),
      title: Text(topic, overflow: TextOverflow.ellipsis),
      subtitle: Builder(
        builder: (context) {
          final children = <Widget>[];

          if (progress != null) {
            if (status == StepStatus.running) {
              final est = progress!.estimatedRemaining;
              final estText = est != null ? " (~${_formatDuration(est)})" : "";

              children.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: progress!.fraction, minHeight: 4),
                    const SizedBox(height: 2),
                    Text(
                      "${_formatNumber(progress!.remaining)} remaining$estText",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              );
            } else if (status == StepStatus.completed) {
              // Show result stats
              final scanned = progress!.scanned;
              final matches = matchCount ?? 0;

              children.add(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      "$matches matches found (${_formatNumber(scanned)} scanned)",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10, color: Colors.green),
                    ),
                  ],
                ),
              );
            }
          }

          if (extraSubtitle != null) {
            if (children.isNotEmpty) {
              children.add(const SizedBox(height: 4));
            }
            children.add(extraSubtitle!);
          }

          if (children.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
        },
      ),
      trailing:
          trailing ?? Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontSize: 11)),
    );
  }

  IconData _getStatusIcon(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Icons.radio_button_unchecked;
      case StepStatus.running:
        return Icons.play_circle_outline;
      case StepStatus.completed:
        return Icons.check_circle;
      case StepStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey;
      case StepStatus.running:
        return Colors.blue;
      case StepStatus.completed:
        return Colors.green;
      case StepStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return "PENDING";
      case StepStatus.running:
        return "RUNNING";
      case StepStatus.completed:
        return "COMPLETED";
      case StepStatus.error:
        return "FAILED";
    }
  }

  String _formatNumber(int number) {
    final str = number.toString();
    if (str.length <= 3) return str;
    final r = RegExp(r'\B(?=(\d{3})+(?!\d))');
    return str.replaceAll(r, '.');
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return "${d.inDays}d ${d.inHours % 24}h";
    if (d.inHours > 0) return "${d.inHours}h ${d.inMinutes % 60}m";
    if (d.inMinutes > 0) return "${d.inMinutes}m ${d.inSeconds % 60}s";
    return "${d.inSeconds}s";
  }
}
