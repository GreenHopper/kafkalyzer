import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class DlqFailureDiagnosticsCard extends StatefulWidget {
  final DlqFailureMetadata metadata;
  final KafkaMessage message;
  final ClusterProfile? profile;
  final void Function(String topic, int partition, int offset)?
  onJumpToOriginalMessage;

  const DlqFailureDiagnosticsCard({
    super.key,
    required this.metadata,
    required this.message,
    this.profile,
    this.onJumpToOriginalMessage,
  });

  @override
  State<DlqFailureDiagnosticsCard> createState() =>
      _DlqFailureDiagnosticsCardState();
}

class _DlqFailureDiagnosticsCardState extends State<DlqFailureDiagnosticsCard> {
  bool _isStacktraceExpanded = false;

  void _copyKcatCommand(BuildContext context, AppLocalizations? l10n) {
    final bootstrapServers =
        widget.profile?.bootstrapServers ?? 'localhost:9092';
    final cmd = widget.metadata.generateKcatReplayCommand(
      bootstrapServers: bootstrapServers,
      key: widget.message.key,
      payload: widget.message.payload,
    );

    Clipboard.setData(ClipboardData(text: cmd));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          l10n?.kcatCommandCopied ?? 'kcat replay command copied to clipboard',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final meta = widget.metadata;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      color: colorScheme.errorContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  color: colorScheme.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n?.failureDiagnosticsTitle ??
                        'Failure Diagnostics (DLQ)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.error,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  key: const Key('dlq_copy_kcat_button'),
                  icon: const Icon(Icons.terminal, size: 14),
                  label: Text(
                    l10n?.copyKcatReplayCommand ?? 'Copy kcat Replay Command',
                    style: const TextStyle(fontSize: 11),
                  ),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                  onPressed: () => _copyKcatCommand(context, l10n),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Coordinates & Jump Action
            if (meta.hasCoordinates) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n?.originalCoordinates(
                              meta.originalTopic!,
                              meta.originalPartition!,
                              meta.originalOffset!,
                            ) ??
                            'Origin: ${meta.originalTopic} [P: ${meta.originalPartition}, O: ${meta.originalOffset}]',
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.onJumpToOriginalMessage != null)
                      FilledButton.tonalIcon(
                        key: const Key('dlq_jump_original_button'),
                        icon: const Icon(Icons.arrow_forward, size: 14),
                        label: Text(
                          l10n?.jumpToOriginalMessage ??
                              'Jump to Original Message',
                          style: const TextStyle(fontSize: 11),
                        ),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                        onPressed: () {
                          widget.onJumpToOriginalMessage!(
                            meta.originalTopic!,
                            meta.originalPartition!,
                            meta.originalOffset!,
                          );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Exception Message
            if (meta.exceptionMessage != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n?.exceptionMessageLabel ?? "Exception"}: ',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      meta.exceptionClass != null
                          ? '${meta.exceptionClass}: ${meta.exceptionMessage}'
                          : meta.exceptionMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            // Stacktrace Expandable
            if (meta.exceptionStacktrace != null) ...[
              const SizedBox(height: 6),
              InkWell(
                key: const Key('dlq_toggle_stacktrace_button'),
                onTap: () => setState(
                  () => _isStacktraceExpanded = !_isStacktraceExpanded,
                ),
                child: Row(
                  children: [
                    Icon(
                      _isStacktraceExpanded
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      size: 16,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Stacktrace',
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.outline,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (_isStacktraceExpanded) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    meta.exceptionStacktrace!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
