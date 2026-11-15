import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/analysis_scope_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

class ReportScopeCard extends StatelessWidget {
  final AnalysisScopeSummary? scanScope;

  const ReportScopeCard({super.key, required this.scanScope});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final numFmt = NumberFormat.decimalPattern();

    return Card(
      key: const Key('report_scope_card'),
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
                Icon(Icons.tune, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  l10n?.reportScopeCardTitle ?? 'Scan Scope',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (scanScope == null)
              Text(
                l10n?.reportScopeNotRecorded ??
                    'Scope not recorded for this report.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                formatAnalysisScopeSummary(scanScope!.scope, l10n),
                style: theme.textTheme.bodyMedium,
              ),
              if (scanScope!.excludedByTimeRange > 0) ...[
                const SizedBox(height: 4),
                Text(
                  l10n?.reportScopeExcludedByTime(
                        numFmt.format(scanScope!.excludedByTimeRange.toInt()),
                      ) ??
                      'Excluded by time range: ${numFmt.format(scanScope!.excludedByTimeRange.toInt())}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (scanScope!.unreadable.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: colorScheme.error,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n?.reportScopeUnreadablePartitions(
                              scanScope!.unreadable
                                  .map((u) => 'P${u.partition} (${u.reason})')
                                  .join(', '),
                            ) ??
                            'Unreadable partitions: ${scanScope!.unreadable.map((u) => 'P${u.partition} (${u.reason})').join(', ')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class AnalysisLimitsCard extends StatelessWidget {
  final List<AnalysisLimit>? limits;

  const AnalysisLimitsCard({super.key, required this.limits});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final numFmt = NumberFormat.decimalPattern();

    return Card(
      key: const Key('analysis_limits_card'),
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
                  Icons.speed_outlined,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.analysisLimitsCardTitle ?? 'Analysis Limits',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (limits == null)
              Text(
                l10n?.analysisLimitsNotAvailable ??
                    'Not available for this report.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (final limit in limits!)
                    _LimitBadge(
                      label: _limitLabel(limit.kind, l10n),
                      value: numFmt.format(limit.limit.toInt()),
                      reached: limit.reached,
                      l10n: l10n,
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _limitLabel(AnalysisLimitKind kind, AppLocalizations? l10n) {
    return switch (kind) {
      AnalysisLimitKind.trackedFields =>
        l10n?.limitKindTrackedFields ?? 'Tracked fields',
      AnalysisLimitKind.listedFields =>
        l10n?.limitKindListedFields ?? 'Listed fields',
      AnalysisLimitKind.valuesPerField =>
        l10n?.limitKindValuesPerField ?? 'Values per field',
      AnalysisLimitKind.listedValuesPerField =>
        l10n?.limitKindListedValuesPerField ?? 'Listed values per field',
      AnalysisLimitKind.fieldDepth =>
        l10n?.limitKindFieldDepth ?? 'Field nesting depth',
      AnalysisLimitKind.valueDisplayChars =>
        l10n?.limitKindValueDisplayChars ?? 'Value display length (chars)',
      AnalysisLimitKind.trackedKeys =>
        l10n?.limitKindTrackedKeys ?? 'Tracked keys',
      AnalysisLimitKind.listedKeys =>
        l10n?.limitKindListedKeys ?? 'Listed keys',
      AnalysisLimitKind.sizePercentileSample =>
        l10n?.limitKindSizePercentileSample ?? 'Size percentile sample',
      AnalysisLimitKind.trackedFingerprints =>
        l10n?.limitKindTrackedFingerprints ?? 'Tracked duplicate fingerprints',
      AnalysisLimitKind.duplicateSamples =>
        l10n?.limitKindDuplicateSamples ?? 'Duplicate samples',
      AnalysisLimitKind.listedDuplicates =>
        l10n?.limitKindListedDuplicates ?? 'Listed duplicates',
      AnalysisLimitKind.previewChars =>
        l10n?.limitKindPreviewChars ?? 'Payload preview length (chars)',
      AnalysisLimitKind.timelineWindowDays =>
        l10n?.limitKindTimelineWindowDays ?? 'Timeline window (days)',
    };
  }
}

class _LimitBadge extends StatelessWidget {
  final String label;
  final String value;
  final bool reached;
  final AppLocalizations? l10n;

  const _LimitBadge({
    required this.label,
    required this.value,
    required this.reached,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stateText = reached
        ? (l10n?.analysisLimitReached ?? 'Reached')
        : (l10n?.analysisLimitWithin ?? 'Within limit');
    final fg = reached ? colorScheme.error : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: reached
            ? colorScheme.errorContainer.withValues(alpha: 0.4)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            reached ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value · $stateText',
            style: theme.textTheme.bodySmall?.copyWith(
              color: fg,
              fontWeight: reached ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
