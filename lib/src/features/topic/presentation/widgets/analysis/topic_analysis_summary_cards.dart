import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class TopicAnalysisSummaryCards extends StatelessWidget {
  final TopicAnalysisReport report;

  const TopicAnalysisSummaryCards({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();

    final totalMsgs = report.totalMessages;
    final tombstoneCount = report.tombstonesCount;
    final tombstonePct = totalMsgs > 0
        ? (tombstoneCount / totalMsgs) * 100.0
        : 0.0;
    final nullKeys = report.nullKeysCount;
    final nullKeysPct = totalMsgs > 0 ? (nullKeys / totalMsgs) * 100.0 : 0.0;
    final keyedCount = totalMsgs - nullKeys;
    final keyedPct = totalMsgs > 0 ? (keyedCount / totalMsgs) * 100.0 : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 36) / 4;
        final minWidth = cardWidth < 220 ? double.infinity : cardWidth;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: minWidth,
              child: _SummaryCard(
                icon: Icons.mark_email_read_outlined,
                iconColor: Colors.blue,
                title: l10n?.totalMessages ?? 'Total Messages',
                mainValue: numberFormat.format(totalMsgs),
                subtitle:
                    '${_formatDuration(report.scanDurationMs)} • '
                    '${report.partitionStats.length} partitions',
              ),
            ),
            SizedBox(
              width: minWidth,
              child: _SummaryCard(
                icon: Icons.storage_outlined,
                iconColor: Colors.purple,
                title: l10n?.totalPayloadSize ?? 'Total Payload Size',
                mainValue: _formatBytes(report.totalBytes),
                subtitle:
                    '${l10n?.avgMessageSize ?? 'Avg'}: '
                    '${_formatBytes(report.avgMessageSize.round())} '
                    '(${report.minMessageSize} B - '
                    '${_formatBytes(report.maxMessageSize)})',
              ),
            ),
            SizedBox(
              width: minWidth,
              child: _SummaryCard(
                icon: Icons.delete_sweep_outlined,
                iconColor: report.isCompacted ? Colors.orange : Colors.blueGrey,
                title: l10n?.tombstones ?? 'Tombstones',
                mainValue:
                    '${numberFormat.format(tombstoneCount)} '
                    '(${tombstonePct.toStringAsFixed(1)}%)',
                subtitle: report.isCompacted
                    ? (l10n?.compactedTopic ?? 'Compacted Topic')
                    : (l10n?.nonCompactedTopic ?? 'Delete Policy'),
                badgeText: report.isCompacted ? 'compact' : 'delete',
                badgeColor: report.isCompacted
                    ? Colors.orange.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            SizedBox(
              width: minWidth,
              child: _SummaryCard(
                icon: Icons.vpn_key_outlined,
                iconColor: Colors.teal,
                title: l10n?.keyedMessages ?? 'Keyed Messages',
                mainValue:
                    '${keyedPct.toStringAsFixed(1)}% '
                    '(${numberFormat.format(keyedCount)})',
                subtitle:
                    '${l10n?.nullKeys ?? 'Null Keys'}: '
                    '${numberFormat.format(nullKeys)} '
                    '(${nullKeysPct.toStringAsFixed(1)}%)',
              ),
            ),
          ],
        );
      },
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDuration(int ms) {
    if (ms < 1000) return '${ms}ms';
    final sec = ms / 1000.0;
    if (sec < 60) return '${sec.toStringAsFixed(1)}s';
    final min = (sec / 60).floor();
    final remSec = (sec % 60).round();
    return '${min}m ${remSec}s';
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String mainValue;
  final String subtitle;
  final String? badgeText;
  final Color? badgeColor;

  const _SummaryCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.mainValue,
    required this.subtitle,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor ?? colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              mainValue,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
