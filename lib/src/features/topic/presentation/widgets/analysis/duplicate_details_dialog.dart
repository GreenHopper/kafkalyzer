import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

/// Modal dialog displaying comprehensive inspection details for a duplicated message.
class DuplicateDetailsDialog extends StatelessWidget {
  final TopDuplicateOccurrence duplicate;
  final int rank;
  final DuplicateDetectionScope scope;
  final void Function(DuplicateNavigationTarget target)? onNavigateToTarget;
  final void Function(int partition, int offset)? onNavigateToMessage;

  const DuplicateDetailsDialog({
    super.key,
    required this.duplicate,
    required this.rank,
    required this.scope,
    this.onNavigateToTarget,
    this.onNavigateToMessage,
  });

  static String _formatPayload(String raw) {
    if (raw.isEmpty) return raw;
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();

    final formattedPayload = _formatPayload(duplicate.payloadPreview);
    final hasKey = duplicate.key != null && duplicate.key!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: colorScheme.surface,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 650),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.copy_all_rounded,
                    size: 24,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.duplicateDetailsTitle ??
                              'Duplicate Message Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n?.duplicateDetailsSubtitle(
                                rank,
                                numberFormat.format(duplicate.count),
                                duplicate.percentage.toStringAsFixed(1),
                              ) ??
                              'Rank #$rank • ${numberFormat.format(duplicate.count)} occurrences (${duplicate.percentage.toStringAsFixed(1)}%)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: l10n?.close ?? 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Metadata Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    icon: Icons.tag,
                    label:
                        'Partition ${duplicate.samplePartition} • Offset ${duplicate.sampleOffset}',
                  ),
                  if (duplicate.sampleTimestampMs > 0)
                    _InfoChip(
                      icon: Icons.access_time_rounded,
                      label: DateFormat('yyyy-MM-dd HH:mm:ss').format(
                        DateTime.fromMillisecondsSinceEpoch(
                          duplicate.sampleTimestampMs.toInt(),
                          isUtc: true,
                        ).toLocal(),
                      ),
                    ),
                  _InfoChip(
                    icon: Icons.tune_rounded,
                    label: scope == DuplicateDetectionScope.payloadOnly
                        ? (l10n?.duplicateScopePayloadOnly ?? 'Payload (Value)')
                        : (l10n?.duplicateScopeKeyAndPayload ??
                              'Key + Payload'),
                  ),
                ],
              ),

              // Key section (if keyed)
              if (hasKey) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      l10n?.duplicateKey ?? 'Key',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      tooltip: l10n?.copyKey ?? 'Copy key',
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: duplicate.key!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n?.copiedKey ?? 'Key copied to clipboard',
                            ),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.4,
                    ),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: SelectableText(
                    duplicate.key!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],

              // Payload section
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    l10n?.duplicatePayload ?? 'Decoded Payload',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 14),
                    tooltip: l10n?.copyPayload ?? 'Copy payload',
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: duplicate.payloadPreview),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            l10n?.copiedPayload ??
                                'Payload copied to clipboard',
                          ),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      formattedPayload,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Dialog Actions
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (onNavigateToTarget != null) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.pin_drop_outlined, size: 16),
                        label: Text(
                          l10n?.jumpToSampleOffset ?? 'Jump to Sample',
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onNavigateToTarget!(
                            DuplicateNavigationTarget.fromOccurrence(
                              occurrence: duplicate,
                              scope: scope,
                              filterOccurrences: false,
                            ),
                          );
                        },
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.filter_alt_rounded, size: 16),
                        label: Text(
                          l10n?.filterDuplicatesInMessages ??
                              'Filter in Messages',
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onNavigateToTarget!(
                            DuplicateNavigationTarget.fromOccurrence(
                              occurrence: duplicate,
                              scope: scope,
                              filterOccurrences: true,
                            ),
                          );
                        },
                      ),
                    ] else if (onNavigateToMessage != null) ...[
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(l10n?.openInMessages ?? 'Open in Messages'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onNavigateToMessage!(
                            duplicate.samplePartition,
                            duplicate.sampleOffset.toInt(),
                          );
                        },
                      ),
                    ],
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(l10n?.close ?? 'Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
