import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/message_stream_controller.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/src/ui/widgets/dropped_messages_indicator.dart';

/// Scan progress and the stream controls next to it: pause, resume, stop,
/// stream and clear.
class TopicDetailProgressTile extends StatelessWidget {
  final MessageStreamController stream;
  final VoidCallback onStart;

  const TopicDetailProgressTile({
    super.key,
    required this.stream,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [_buildProgressTile(context, colorScheme)],
    );
  }

  Widget _buildProgressTile(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final droppedCount = stream.droppedCount;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Row(
        children: [
          Expanded(
            child: TopicProgressTile(
              topic: l10n?.scanProgressTitle ?? "Scan Progress",
              status: stream.isStreaming
                  ? StepStatus.running
                  : (stream.totalConsumed > 0
                        ? StepStatus.completed
                        : StepStatus.pending),
              progress: SearchProgress(
                stream.totalConsumed,
                stream.totalToScan,
                startTime: stream.startTime,
              ),
              matchCount: stream.receivedCount,
              contentPadding: EdgeInsets.zero,
              dense: true,
              extraSubtitle: droppedCount > 0
                  ? DroppedMessagesIndicator(
                      droppedCount: droppedCount,
                      bufferLimit: stream.bufferLimit,
                    )
                  : null,
              trailing: const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: _buildProgressActions(context, colorScheme)),
        ],
      ),
    );
  }

  Widget _buildProgressActions(BuildContext context, ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context);
    final showPauseResume = stream.isStreaming || stream.isPaused;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showPauseResume)
          if (stream.isPaused)
            Tooltip(
              message:
                  l10n?.resumeViewTooltip ?? 'Resume updating the message view',
              child: OutlinedButton.icon(
                onPressed: stream.resume,
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  l10n?.resumeViewWithNew(stream.pendingCount) ??
                      'Resume · ${stream.pendingCount} new',
                ),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            )
          else
            Tooltip(
              message:
                  l10n?.pauseViewTooltip ??
                  'Pause view updates while keeping the stream active',
              child: OutlinedButton.icon(
                onPressed: stream.pause,
                icon: const Icon(Icons.pause, size: 16),
                label: Text(l10n?.pauseView ?? 'Pause view'),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
              ),
            ),
        if (stream.isStreaming)
          FilledButton.icon(
            onPressed: () => stream.stopStreaming(),
            icon: const Icon(Icons.stop, size: 16),
            label: Text(l10n?.stop ?? 'Stop'),
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.error,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          )
        else
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow, size: 16),
            label: Text(l10n?.stream ?? 'Stream'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        IconButton.filledTonal(
          onPressed: stream.clearMessages,
          icon: const Icon(Icons.delete_sweep, size: 16),
          tooltip: l10n?.clearMessagesTooltip ?? "Clear Messages",
          style: IconButton.styleFrom(visualDensity: VisualDensity.compact),
        ),
      ],
    );
  }
}
