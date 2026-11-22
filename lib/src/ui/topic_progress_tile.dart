import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';

/// How far one scan or script step has got.
///
/// Defined once here because this tile renders it; the script runner, the topic
/// detail progress tile and the headless runner all report into it.
enum StepStatus { pending, running, completed, error }

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
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        dense: dense,
        contentPadding: contentPadding,
        leading: Icon(
          _getStatusIcon(status),
          color: _getStatusColor(context, status),
          size: 16,
        ),
        title: Text(topic, overflow: TextOverflow.ellipsis),
        subtitle: Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context);
            final children = <Widget>[];

            if (progress != null) {
              if (status == StepStatus.running) {
                final est = progress!.estimatedRemaining;
                final estText = est != null
                    ? " (~${_formatDuration(est)})"
                    : "";
                final remainingText =
                    l10n?.remainingCount(
                      progress!.remaining,
                      _formatNumber(progress!.remaining),
                    ) ??
                    "${_formatNumber(progress!.remaining)} remaining";

                children.add(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: progress!.fraction,
                        minHeight: 4,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "$remainingText$estText",
                        style: Theme.of(context).textTheme.bodySmall,
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
                        l10n?.matchesFoundScanned(
                              matches,
                              _formatNumber(matches),
                              _formatNumber(scanned),
                            ) ??
                            "${_formatNumber(matches)} matches found (${_formatNumber(scanned)} scanned)",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
          },
        ),
        trailing:
            trailing ??
            Text(
              _getStatusText(context, status),
              style: TextStyle(
                color: _getStatusColor(context, status),
                fontSize: 11,
              ),
            ),
      ),
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

  Color _getStatusColor(BuildContext context, StepStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case StepStatus.pending:
        return colorScheme.outline;
      case StepStatus.running:
        return colorScheme.secondary;
      case StepStatus.completed:
        return colorScheme.primary;
      case StepStatus.error:
        return colorScheme.error;
    }
  }

  String _getStatusText(BuildContext context, StepStatus status) {
    final l10n = AppLocalizations.of(context);
    switch (status) {
      case StepStatus.pending:
        return l10n?.stepStatusPending ?? "PENDING";
      case StepStatus.running:
        return l10n?.stepStatusRunning ?? "RUNNING";
      case StepStatus.completed:
        return l10n?.stepStatusCompleted ?? "COMPLETED";
      case StepStatus.error:
        return l10n?.stepStatusFailed ?? "FAILED";
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
