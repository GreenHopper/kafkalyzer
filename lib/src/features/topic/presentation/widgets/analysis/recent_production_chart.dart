import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/domain/production_timeline.dart';
import 'package:material_ui/material_ui.dart';

/// Renders hourly production volume for a selectable recent window (6, 12, 24, 48, 72 hours).
class RecentProductionChart extends StatefulWidget {
  final ProductionTimeline timeline;

  const RecentProductionChart({super.key, required this.timeline});

  @override
  State<RecentProductionChart> createState() => _RecentProductionChartState();
}

class _RecentProductionChartState extends State<RecentProductionChart> {
  int _selectedWindow = ProductionTimeline.defaultWindowHours;
  int? _hoveredEpochHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final numberFormat = NumberFormat.decimalPattern();

    if (!widget.timeline.isAvailable) {
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
          child: Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 20,
                color: colorScheme.outline,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.recentProductionTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  l10n.timelineNotAvailableForReport,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.outline,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final points = widget.timeline.recentHours(windowHours: _selectedWindow);
    final totalInWindow = points.fold<int>(0, (s, p) => s + p.count);
    final maxCount = points.isEmpty
        ? 1
        : math.max(1, points.map((p) => p.count).reduce(math.max));

    final isPartiallyCovered = widget.timeline.isWindowPartiallyCovered(
      _selectedWindow,
    );
    final coveredHours = widget.timeline.coveredHoursInWindow(_selectedWindow);

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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.schedule_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recentProductionTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          l10n.timeZoneLabel(DateTime.now().timeZoneName),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 6, label: Text(l10n.window6h)),
                        ButtonSegment(value: 12, label: Text(l10n.window12h)),
                        ButtonSegment(value: 24, label: Text(l10n.window24h)),
                        ButtonSegment(value: 48, label: Text(l10n.window48h)),
                        ButtonSegment(value: 72, label: Text(l10n.window72h)),
                      ],
                      selected: {_selectedWindow},
                      onSelectionChanged: (set) {
                        if (set.isNotEmpty) {
                          setState(() => _selectedWindow = set.first);
                        }
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${numberFormat.format(totalInWindow)} msgs',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (isPartiallyCovered) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.tertiary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: colorScheme.tertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.coverageHint(coveredHours),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barSpacing = 2.0;
                  final availableWidth = constraints.maxWidth;
                  final numBars = points.length;
                  final barWidth = math.max(
                    4.0,
                    (availableWidth - ((numBars - 1) * barSpacing)) / numBars,
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: points.map((point) {
                      final isHovered = _hoveredEpochHour == point.epochHour;
                      final heightFactor = (point.count / maxCount).clamp(
                        0.04,
                        1.0,
                      );

                      Color barColor;
                      if (!point.isCovered) {
                        barColor = colorScheme.outlineVariant.withValues(
                          alpha: 0.4,
                        );
                      } else if (point.isUnusual) {
                        barColor = Colors.amber.shade700;
                      } else if (point.isCurrentHour) {
                        barColor = colorScheme.secondary;
                      } else {
                        barColor = colorScheme.primary.withValues(alpha: 0.85);
                      }

                      if (isHovered && point.isCovered) {
                        barColor = colorScheme.tertiary;
                      }

                      // Label interval
                      final showLabel = _shouldShowLabel(point, points);

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: barSpacing / 2,
                          ),
                          child: MouseRegion(
                            onEnter: (_) => setState(
                              () => _hoveredEpochHour = point.epochHour,
                            ),
                            onExit: (_) =>
                                setState(() => _hoveredEpochHour = null),
                            child: Tooltip(
                              message: _buildTooltipMessage(
                                point,
                                l10n,
                                numberFormat,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  SizedBox(
                                    height: constraints.maxHeight - 24,
                                    child: Stack(
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 200,
                                          ),
                                          curve: Curves.easeOutCubic,
                                          width: barWidth,
                                          height:
                                              (constraints.maxHeight - 24) *
                                              heightFactor,
                                          decoration: BoxDecoration(
                                            color: barColor,
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(4),
                                                ),
                                            boxShadow: point.isUnusual
                                                ? [
                                                    BoxShadow(
                                                      color: Colors.amber
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                      blurRadius: 6,
                                                      offset: const Offset(
                                                        0,
                                                        1,
                                                      ),
                                                    ),
                                                  ]
                                                : (isHovered
                                                      ? [
                                                          BoxShadow(
                                                            color: barColor
                                                                .withValues(
                                                                  alpha: 0.4,
                                                                ),
                                                            blurRadius: 4,
                                                          ),
                                                        ]
                                                      : null),
                                          ),
                                        ),
                                        if (point.baseline != null &&
                                            point.isCovered) ...[
                                          Positioned(
                                            bottom:
                                                (constraints.maxHeight - 24) *
                                                (point.baseline! / maxCount)
                                                    .clamp(0.02, 1.0),
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              height: 2,
                                              color: colorScheme
                                                  .onSurfaceVariant
                                                  .withValues(alpha: 0.8),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  SizedBox(
                                    height: 14,
                                    child: showLabel
                                        ? Text(
                                            DateFormat.H().format(
                                              point.startTime,
                                            ),
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                                  fontSize: 9,
                                                  color: colorScheme.outline,
                                                  fontWeight:
                                                      point.isCurrentHour
                                                      ? FontWeight.bold
                                                      : FontWeight.normal,
                                                ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowLabel(RecentHourPoint point, List<RecentHourPoint> points) {
    if (point.isCurrentHour) return true;
    final hour = point.startTime.hour;
    if (_selectedWindow <= 12) {
      return hour % 2 == 0;
    } else if (_selectedWindow <= 24) {
      return hour % 4 == 0;
    } else if (_selectedWindow <= 48) {
      return hour % 6 == 0;
    } else {
      return hour % 12 == 0;
    }
  }

  String _buildTooltipMessage(
    RecentHourPoint point,
    AppLocalizations l10n,
    NumberFormat numberFormat,
  ) {
    final startStr = DateFormat('yyyy-MM-dd HH:mm').format(point.startTime);
    final endStr = DateFormat(
      'HH:mm',
    ).format(point.startTime.add(const Duration(hours: 1)));
    final buffer = StringBuffer('$startStr - $endStr\n');

    if (!point.isCovered) {
      buffer.writeln(l10n.uncoveredHourHint(point.count));
      return buffer.toString().trim();
    }

    if (point.isCurrentHour) {
      buffer.writeln(
        '${l10n.currentHourIncomplete} (${numberFormat.format(point.count)} msgs)',
      );
    } else {
      buffer.writeln('${numberFormat.format(point.count)} msgs');
    }

    if (point.baseline != null) {
      final baseStr = numberFormat.format(point.baseline!.round());
      final delta = point.deltaPercent;
      final deltaStr = delta != null
          ? (delta >= 0
                ? '+${delta.toStringAsFixed(0)}%'
                : '${delta.toStringAsFixed(0)}%')
          : '';
      buffer.writeln('${l10n.baselineLabel(baseStr)} ($deltaStr)');
      if (point.isUnusual) {
        buffer.writeln('★ ${l10n.unusualIncreaseBadge}');
      }
    } else {
      buffer.writeln(l10n.noComparisonData);
    }

    if (point.matchCount != null) {
      final matchStr = numberFormat.format(point.matchCount);
      final shareStr = point.matchSharePercent?.toStringAsFixed(1) ?? '0.0';
      buffer.writeln(l10n.hourlyTooltipMatches(matchStr, shareStr));
    }

    return buffer.toString().trim();
  }
}
