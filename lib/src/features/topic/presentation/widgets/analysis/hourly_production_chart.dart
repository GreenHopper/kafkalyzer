import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class HourlyProductionChart extends StatefulWidget {
  final List<HourlyCount> hourlyDistribution;

  const HourlyProductionChart({super.key, required this.hourlyDistribution});

  @override
  State<HourlyProductionChart> createState() => _HourlyProductionChartState();
}

class _HourlyProductionChartState extends State<HourlyProductionChart> {
  int? _hoveredHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();

    int maxCount = 0;
    int peakHour = 0;
    int totalCount = 0;

    for (final item in widget.hourlyDistribution) {
      totalCount += item.count;
      if (item.count > maxCount) {
        maxCount = item.count;
        peakHour = item.hour;
      }
    }

    final peakItem = widget.hourlyDistribution.firstWhere(
      (h) => h.hour == peakHour,
      orElse: () => const HourlyCount(hour: 0, count: 0, percentage: 0.0),
    );

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
                      Icons.bar_chart_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n?.hourlyPeakProduction ??
                          'Hourly Production Peaks (24h UTC)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (totalCount > 0)
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
                      'Peak: ${peakHour.toString().padLeft(2, '0')}:00 UTC '
                      '(${numberFormat.format(peakItem.count)} msgs • '
                      '${peakItem.percentage.toStringAsFixed(1)}%)',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 160,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final barSpacing = 4.0;
                  final availableWidth = constraints.maxWidth;
                  final barWidth = math.max(
                    8.0,
                    (availableWidth - (23 * barSpacing)) / 24,
                  );

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(24, (index) {
                      final item = widget.hourlyDistribution.firstWhere(
                        (h) => h.hour == index,
                        orElse: () =>
                            HourlyCount(hour: index, count: 0, percentage: 0.0),
                      );

                      final isPeak = item.hour == peakHour && maxCount > 0;
                      final isHovered = _hoveredHour == item.hour;
                      final heightFactor = maxCount > 0
                          ? (item.count / maxCount).clamp(0.04, 1.0)
                          : 0.04;

                      Color barColor = colorScheme.primary.withValues(
                        alpha: 0.75,
                      );
                      if (isPeak) {
                        barColor = colorScheme.primary;
                      }
                      if (isHovered) {
                        barColor = colorScheme.tertiary;
                      }

                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: barSpacing / 2,
                          ),
                          child: MouseRegion(
                            onEnter: (_) =>
                                setState(() => _hoveredHour = item.hour),
                            onExit: (_) => setState(() => _hoveredHour = null),
                            child: Tooltip(
                              message:
                                  '${item.hour.toString().padLeft(2, '0')}:00 - '
                                  '${item.hour.toString().padLeft(2, '0')}:59 UTC\n'
                                  '${numberFormat.format(item.count)} msgs '
                                  '(${item.percentage.toStringAsFixed(1)}%)',
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    curve: Curves.easeOutCubic,
                                    width: barWidth,
                                    height:
                                        (constraints.maxHeight - 24) *
                                        heightFactor,
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                      boxShadow: isPeak || isHovered
                                          ? [
                                              BoxShadow(
                                                color: barColor.withValues(
                                                  alpha: 0.4,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    index % 3 == 0
                                        ? '${index.toString().padLeft(2, '0')}h'
                                        : '•',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: isPeak || isHovered
                                          ? colorScheme.primary
                                          : colorScheme.onSurfaceVariant
                                                .withValues(alpha: 0.6),
                                      fontWeight: isPeak || isHovered
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
