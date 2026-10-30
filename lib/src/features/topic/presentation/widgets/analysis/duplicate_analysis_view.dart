import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/models/duplicate_navigation_target.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/duplicate_details_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

/// Displays duplicate message metrics and the top duplicated messages.
class DuplicateAnalysisView extends StatelessWidget {
  final DuplicateAnalysisResult? result;
  final void Function(DuplicateNavigationTarget target)? onNavigateToTarget;
  final void Function(int partition, int offset)? onNavigateToMessage;

  const DuplicateAnalysisView({
    super.key,
    required this.result,
    this.onNavigateToTarget,
    this.onNavigateToMessage,
  });

  void _openDetails(
    BuildContext context,
    TopDuplicateOccurrence duplicate,
    int rank,
  ) {
    if (result == null) return;
    showDialog(
      context: context,
      builder: (dialogContext) => DuplicateDetailsDialog(
        duplicate: duplicate,
        rank: rank,
        scope: result!.scope,
        onNavigateToTarget: onNavigateToTarget,
        onNavigateToMessage: onNavigateToMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (result == null) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: colorScheme.onSurfaceVariant,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n?.duplicateAnalysisUnavailable ??
                      'Duplicate analysis is not available for this report.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final duplicates = result!.topDuplicates;
    final numberFormat = NumberFormat.decimalPattern();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.copy_all_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n?.topDuplicatesTitle ?? 'Top Duplicated Messages',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n?.topDuplicatesSubtitle ??
                            'Showing up to 20 most frequent duplicated messages',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _scopeLabel(result!.scope, l10n),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (duplicates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n?.noDuplicatesDetected ??
                            'No duplicate messages detected in this scan.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth,
                      ),
                      child: DataTable(
                        columnSpacing: 16,
                        horizontalMargin: 8,
                        headingRowHeight: 38,
                        dataRowMinHeight: 46,
                        dataRowMaxHeight: 58,
                        showCheckboxColumn: false,
                        columns: [
                          DataColumn(
                            label: Text(
                              l10n?.duplicateRankHeader ?? '#',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              l10n?.duplicateCountHeader ?? 'Occurrences',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              l10n?.duplicateKeyHeader ?? 'Key',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              l10n?.duplicatePayloadPreviewHeader ??
                                  'Payload Preview',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              l10n?.duplicateSampleCoordinatesHeader ??
                                  'Sample Location',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const DataColumn(label: SizedBox(width: 80)),
                        ],
                        rows: List.generate(duplicates.length, (index) {
                          final item = duplicates[index];
                          final rank = index + 1;
                          return DataRow(
                            onSelectChanged: (_) =>
                                _openDetails(context, item, rank),
                            cells: [
                              DataCell(
                                Text(
                                  '$rank',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${numberFormat.format(item.count)} '
                                      '(${item.percentage.toStringAsFixed(1)}%)',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(2),
                                      child: SizedBox(
                                        width: 80,
                                        child: LinearProgressIndicator(
                                          value: (item.percentage / 100.0)
                                              .clamp(0.0, 1.0),
                                          minHeight: 3,
                                          backgroundColor: colorScheme
                                              .surfaceContainerHighest,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              DataCell(
                                item.key != null && item.key!.isNotEmpty
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 120,
                                            ),
                                            child: Text(
                                              item.key!,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    fontFamily: 'monospace',
                                                  ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.copy_rounded,
                                              size: 14,
                                            ),
                                            tooltip:
                                                l10n?.copyKey ?? 'Copy key',
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 24,
                                              minHeight: 24,
                                            ),
                                            onPressed: () {
                                              Clipboard.setData(
                                                ClipboardData(text: item.key!),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    l10n?.copiedKey ??
                                                        'Key copied to clipboard',
                                                  ),
                                                  duration: const Duration(
                                                    seconds: 1,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      )
                                    : Text(
                                        '-',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: Text(
                                    item.payloadPreview.isEmpty
                                        ? '<empty>'
                                        : item.payloadPreview,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: item.payloadPreview.isEmpty
                                          ? colorScheme.onSurfaceVariant
                                          : null,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n?.sampleLocation(
                                            item.samplePartition,
                                            item.sampleOffset.toInt(),
                                          ) ??
                                          'P${item.samplePartition} • Offset ${item.sampleOffset}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    if (item.sampleTimestampMs > 0)
                                      Text(
                                        DateFormat(
                                          'yyyy-MM-dd HH:mm:ss',
                                        ).format(
                                          DateTime.fromMillisecondsSinceEpoch(
                                            item.sampleTimestampMs.toInt(),
                                            isUtc: true,
                                          ).toLocal(),
                                        ),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                              fontSize: 10,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.info_outline_rounded,
                                        size: 16,
                                      ),
                                      tooltip:
                                          l10n?.inspectDuplicateTooltip ??
                                          'View duplicate details',
                                      onPressed: () =>
                                          _openDetails(context, item, rank),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.copy_rounded,
                                        size: 16,
                                      ),
                                      tooltip:
                                          l10n?.copyPayload ?? 'Copy payload',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(
                                            text: item.payloadPreview,
                                          ),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              l10n?.copiedPayload ??
                                                  'Payload copied to clipboard',
                                            ),
                                            duration: const Duration(
                                              seconds: 1,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _scopeLabel(DuplicateDetectionScope scope, AppLocalizations? l10n) {
    switch (scope) {
      case DuplicateDetectionScope.payloadOnly:
        return l10n?.duplicateScopePayloadOnly ?? 'Payload (Value)';
      case DuplicateDetectionScope.keyAndPayload:
        return l10n?.duplicateScopeKeyAndPayload ?? 'Key + Payload';
    }
  }
}
