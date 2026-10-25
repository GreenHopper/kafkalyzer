import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/topic_analysis_summary_cards.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/report_compare.dart';

/// Side-by-side deltas of two analysis reports of the same topic.
class TopicReportComparisonView extends StatelessWidget {
  final ReportComparison comparison;
  final TopicAnalysisReport base;
  final TopicAnalysisReport current;
  final String? baseClusterName;
  final String? currentClusterName;
  final DateTime? baseMoment;
  final DateTime? currentMoment;
  final bool baseIsImported;
  final bool currentIsImported;

  const TopicReportComparisonView({
    super.key,
    required this.comparison,
    required this.base,
    required this.current,
    this.baseClusterName,
    this.currentClusterName,
    this.baseMoment,
    this.currentMoment,
    this.baseIsImported = true,
    this.currentIsImported = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();
    final added = comparison.fields.where((f) => f.added).toList();
    final removed = comparison.fields.where((f) => f.removed).toList();

    return Column(
      key: const Key('report_comparison_view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n?.comparisonTitle ?? 'Report comparison'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SideLabel(
                key: const Key('comparison_side_base'),
                title: baseIsImported
                    ? (l10n?.comparisonSourceImported ?? 'Imported')
                    : (l10n?.comparisonSourceLive ?? 'Live'),
                topic: base.topic,
                cluster: baseClusterName,
                moment: baseMoment,
              ),
            ),
            Expanded(
              child: _SideLabel(
                key: const Key('comparison_side_current'),
                title: currentIsImported
                    ? (l10n?.comparisonSourceImported ?? 'Imported')
                    : (l10n?.comparisonSourceLive ?? 'Live'),
                topic: current.topic,
                cluster: currentClusterName,
                moment: currentMoment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final metric in comparison.metrics)
          _MetricRow(
            metric: metric,
            label: _label(l10n, metric.metric),
            format: numberFormat,
          ),
        if (added.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n?.comparisonFieldsAdded ?? 'Fields added',
            key: const Key('comparison_fields_added'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final field in added)
                Text(
                  '+${field.field}',
                  key: Key('comparison_added_${field.field}'),
                ),
            ],
          ),
        ],
        if (removed.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            l10n?.comparisonFieldsRemoved ?? 'Fields removed',
            key: const Key('comparison_fields_removed'),
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final field in removed)
                Text(
                  '-${field.field}',
                  key: Key('comparison_removed_${field.field}'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  String _label(AppLocalizations? l10n, String metric) => switch (metric) {
    'total_messages' => l10n?.totalMessages ?? 'Total Messages',
    'total_bytes' => l10n?.totalPayloadSize ?? 'Total Payload Size',
    'avg_message_size' => l10n?.avgMessageSize ?? 'Avg Message Size',
    'min_message_size' => l10n?.comparisonMinSize ?? 'Min message size',
    'max_message_size' => l10n?.comparisonMaxSize ?? 'Max message size',
    'tombstones' => l10n?.tombstones ?? 'Tombstones',
    'null_keys' => l10n?.nullKeys ?? 'Null Keys',
    'distinct_keys' => l10n?.distinctKeys ?? 'Distinct keys',
    'busiest_partition_share' =>
      l10n?.comparisonBusiestPartition ?? 'Busiest partition share',
    'size_p50' => 'p50',
    'size_p95' => 'p95',
    'size_p99' => 'p99',
    _ => metric,
  };
}

class _SideLabel extends StatelessWidget {
  final String title;
  final String topic;
  final String? cluster;
  final DateTime? moment;

  const _SideLabel({
    super.key,
    required this.title,
    required this.topic,
    this.cluster,
    this.moment,
  });

  @override
  Widget build(BuildContext context) {
    final time = moment == null ? '' : DateFormat.Hm().format(moment!);
    final parts = [
      title,
      topic,
      ?cluster,
      time,
    ].where((p) => p.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Text(parts, overflow: TextOverflow.ellipsis),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final MetricDelta metric;
  final String label;
  final NumberFormat format;

  const _MetricRow({
    required this.metric,
    required this.label,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sizeMetric = metric.metric.startsWith('size_');
    final bytesMetric =
        sizeMetric ||
        const {
          'total_bytes',
          'avg_message_size',
          'min_message_size',
          'max_message_size',
        }.contains(metric.metric);

    String value(double? v) {
      if (v == null) {
        return AppLocalizations.of(context)?.comparisonNotAvailable ??
            'not available';
      }
      if (metric.metric == 'busiest_partition_share') {
        return '${v.toStringAsFixed(1)} %';
      }
      return bytesMetric
          ? TopicAnalysisSummaryCards.formatBytes(v.round())
          : format.format(v.round());
    }

    final delta = metric.absolute;
    final deltaText = delta == null
        ? ''
        : '${delta >= 0 ? '+' : ''}${format.format(delta.round())}'
              '${metric.relativePercent == null ? '' : ' (${metric.relativePercent! >= 0 ? '+' : ''}${metric.relativePercent!.toStringAsFixed(1)} %)'}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        key: Key('comparison_metric_${metric.metric}'),
        children: [
          SizedBox(
            width: 190,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(width: 110, child: Text(value(metric.before))),
          SizedBox(width: 110, child: Text(value(metric.after))),
          Expanded(
            child: Text(
              deltaText,
              style: TextStyle(
                color: metric.comparable
                    ? (delta != null && delta > 0
                          ? Colors.green
                          : delta != null && delta < 0
                          ? scheme.error
                          : null)
                    : scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
