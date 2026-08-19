import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

class PartitionBalanceView extends StatelessWidget {
  final List<PartitionAnalysis> partitionStats;
  final int totalMessages;

  const PartitionBalanceView({
    super.key,
    required this.partitionStats,
    required this.totalMessages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();

    final partitionCount = partitionStats.length;
    final expectedAvg = partitionCount > 0
        ? (totalMessages / partitionCount)
        : 0.0;

    bool hasSkew = false;
    if (partitionCount > 1 && totalMessages > 100) {
      for (final p in partitionStats) {
        if (p.messageCount > expectedAvg * 1.5 ||
            p.messageCount < expectedAvg * 0.5) {
          hasSkew = true;
          break;
        }
      }
    }

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pie_chart_outline_rounded,
                      size: 20,
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.partitionUtilization ??
                          'Partition Utilization & Balance',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: hasSkew
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasSkew ? Colors.amber : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasSkew
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: hasSkew
                            ? Colors.amber.shade900
                            : Colors.green.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasSkew
                            ? (l10n?.hotPartition ?? 'Partition Skew Detected')
                            : (l10n?.balancedPartitions ?? 'Balanced'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: hasSkew
                              ? Colors.amber.shade900
                              : Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (partitionStats.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    l10n?.emptyTopicMessage ?? 'No partitions available',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: partitionStats.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final p = partitionStats[index];
                  final isSkewed =
                      partitionCount > 1 &&
                      totalMessages > 100 &&
                      (p.messageCount > expectedAvg * 1.5 ||
                          p.messageCount < expectedAvg * 0.5);

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 100,
                          child: Text(
                            'Partition ${p.partition}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${numberFormat.format(p.messageCount)} msgs '
                                    '(${p.percentage.toStringAsFixed(1)}%) • '
                                    '${_formatBytes(p.byteSize)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Offsets: ${numberFormat.format(p.earliestOffset)} '
                                    '.. ${numberFormat.format(p.latestOffset)}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: totalMessages > 0
                                      ? (p.messageCount / totalMessages).clamp(
                                          0.0,
                                          1.0,
                                        )
                                      : 0.0,
                                  minHeight: 6,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  color: isSkewed
                                      ? Colors.orange
                                      : colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}
