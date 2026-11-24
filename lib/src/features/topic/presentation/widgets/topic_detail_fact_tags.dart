import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_tag.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';

/// The fact tags of the topic header: message estimate, retention and policy,
/// time range, and the overflow chip that hides them on narrow panes.
///
/// They take the facts controller as a parameter instead of reading it off a
/// state object, which keeps the header itself free of the fetch logic.

double estimateTagWidth(String text, {bool hasIcon = false}) {
  return text.length * 5.2 + 14.0 + (hasIcon ? 16.0 : 0.0);
}

Widget buildOverflowFactsChip(
  BuildContext context,
  AppLocalizations? l10n,
  List<Widget> overflowItems,
) {
  final count = overflowItems.length;
  final semanticLabel =
      l10n?.topicFactsMoreCount(count) ?? '$count more topic facts';

  return MenuAnchor(
    style: MenuStyle(
      padding: const WidgetStatePropertyAll(EdgeInsets.all(10)),
      backgroundColor: WidgetStatePropertyAll(
        Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
    ),
    menuChildren: [
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: overflowItems,
        ),
      ),
    ],
    builder: (context, controller, child) {
      return Semantics(
        label: semanticLabel,
        button: true,
        child: Tooltip(
          message: semanticLabel,
          child: TopicTag(
            '+$count',
            key: const Key('topic_facts_overflow_tag'),
            isConfig: true,
            onTap: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
          ),
        ),
      );
    },
  );
}

List<({Widget widget, bool isPinned, double width})> buildEstimateFactItems(
  TopicFactsController facts,
  BuildContext context,
  AppLocalizations? l10n,
  TopicMetadata topic,
) {
  final offsets = facts.offsets;
  switch (offsets.status) {
    case TopicFactStatus.idle:
      return const [];
    case TopicFactStatus.loading:
      final text = l10n?.topicConfigLoading ?? 'loading';
      return [
        (
          widget: TopicTag(
            text,
            key: const Key('topic_estimate_loading_tag'),
            isConfig: true,
          ),
          isPinned: false,
          width: estimateTagWidth(text),
        ),
      ];
    case TopicFactStatus.error:
      if (offsets.notReadable) {
        final text =
            l10n?.topicHeaderEstimateNotReadable ?? 'Messages: not readable';
        return [
          (
            widget: TopicTag(
              text,
              key: const Key('topic_estimate_not_readable_tag'),
              isConfig: true,
            ),
            isPinned: true,
            width: estimateTagWidth(text),
          ),
        ];
      }
      final text = l10n?.topicHeaderEstimateUnknown ?? 'Messages: unknown';
      return [
        (
          widget: Tooltip(
            message: offsets.error ?? '',
            child: TopicTag(
              text,
              key: const Key('topic_estimate_unknown_tag'),
              isConfig: true,
            ),
          ),
          isPinned: true,
          width: estimateTagWidth(text),
        ),
      ];
    case TopicFactStatus.value:
      final est = offsets.data!;
      if (est.notReadable) {
        final text =
            l10n?.topicHeaderEstimateNotReadable ?? 'Messages: not readable';
        return [
          (
            widget: Tooltip(
              message: est.unreadableReason ?? '',
              child: TopicTag(
                text,
                key: const Key('topic_estimate_not_readable_tag'),
                isConfig: true,
              ),
            ),
            isPinned: true,
            width: estimateTagWidth(text),
          ),
        ];
      }
      if (est.totalSpan == null) {
        final text = l10n?.topicHeaderEstimateUnknown ?? 'Messages: unknown';
        return [
          (
            widget: Tooltip(
              message: est.unreadableReason ?? '',
              child: TopicTag(
                text,
                key: const Key('topic_estimate_unknown_tag'),
                isConfig: true,
              ),
            ),
            isPinned: true,
            width: estimateTagWidth(text),
          ),
        ];
      }
      final locale = Localizations.localeOf(context).toString();
      final formattedCount = NumberFormat.decimalPattern(
        locale,
      ).format(est.totalSpan!);
      final label =
          l10n?.topicHeaderEstimateValue(formattedCount) ??
          '≈ $formattedCount messages (estimate)';
      final policy = facts.configs.data?.cleanupPolicy ?? topic.cleanupPolicy;
      final isCompactedOrUnknown =
          policy == null || policy.isEmpty || policy.contains('compact');
      final tag = TopicTag(
        label,
        key: const Key('topic_estimate_tag'),
        isConfig: true,
      );
      final widget = (isCompactedOrUnknown && l10n != null)
          ? Tooltip(
              key: const Key('topic_estimate_compaction_tooltip'),
              message: l10n.topicHeaderEstimateCompactedNote,
              child: tag,
            )
          : tag;
      return [
        (widget: widget, isPinned: false, width: estimateTagWidth(label)),
      ];
  }
}

List<({Widget widget, bool isPinned, double width})>
buildRetentionAndPolicyFactItems(
  TopicFactsController facts,
  BuildContext context,
  AppLocalizations? l10n,
  TopicMetadata topic,
  TopicConfigView? configView,
) {
  final configs = facts.configs;
  if (configs.status == TopicFactStatus.error && configs.notReadable) {
    if (configView?.state == TopicConfigViewState.notReadable) {
      return const [];
    }
    final text =
        l10n?.topicHeaderRetentionLabel(l10n.topicHeaderRetentionNotReadable) ??
        'Retention: not readable';
    return [
      (
        widget: TopicTag(
          text,
          key: const Key('topic_retention_not_readable_tag'),
          isConfig: true,
        ),
        isPinned: true,
        width: estimateTagWidth(text),
      ),
    ];
  }

  final policy =
      configs.data?.cleanupPolicy ??
      configView?.cleanupPolicy ??
      topic.cleanupPolicy;
  final retentionMs =
      configs.data?.retentionMs ?? configView?.retentionMs ?? topic.retentionMs;
  final retentionBytes = configs.data?.retentionBytes;

  final items = <({Widget widget, bool isPinned, double width})>[];
  if (policy != null && policy.isNotEmpty) {
    final policyText = splitPolicy(policy);
    items.add((
      widget: TopicTag(policyText, isConfig: true),
      isPinned: false,
      width: estimateTagWidth(policyText),
    ));
  }
  if (retentionMs != null && retentionMs.isNotEmpty && l10n != null) {
    final retText = l10n.topicHeaderRetentionLabel(
      formatRetentionDuration(retentionMs, l10n),
    );
    items.add((
      widget: TopicTag(
        retText,
        key: const Key('topic_retention_tag'),
        isConfig: true,
      ),
      isPinned: false,
      width: estimateTagWidth(retText),
    ));
  }
  if (retentionBytes != null && retentionBytes.isNotEmpty && l10n != null) {
    final bytesText = l10n.topicHeaderRetentionBytesLabel(
      formatRetentionBytes(retentionBytes, l10n),
    );
    items.add((
      widget: TopicTag(
        bytesText,
        key: const Key('topic_retention_bytes_tag'),
        isConfig: true,
      ),
      isPinned: false,
      width: estimateTagWidth(bytesText),
    ));
  }
  return items;
}

List<({Widget widget, bool isPinned, double width})> buildTimeRangeFactItems(
  TopicFactsController facts,
  TimeDisplaySettings timeDisplaySettings,
  BuildContext context,
  AppLocalizations? l10n,
  TopicMetadata topic,
) {
  final tr = facts.timeRange;
  switch (tr.status) {
    case TopicFactStatus.idle:
      final labelText = l10n?.topicHeaderLoadTimeRange ?? 'Load time range';
      return [
        (
          widget: Tooltip(
            message:
                l10n?.topicHeaderLoadTimeRangeTooltip(topic.partitionCount) ??
                'Read oldest & newest message timestamps across ${topic.partitionCount} partitions',
            child: OutlinedButton.icon(
              key: const Key('topic_load_time_range_button'),
              onPressed: facts.loadTimeRange,
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                minimumSize: const Size(24, 24),
              ),
              icon: const Icon(Icons.schedule, size: 14),
              label: Text(
                labelText,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ),
          isPinned: false,
          width: estimateTagWidth(labelText, hasIcon: true) + 8,
        ),
      ];
    case TopicFactStatus.loading:
      final text = l10n?.topicHeaderTimeRangeLoading ?? 'Loading time range…';
      return [
        (
          widget: TopicTag(
            text,
            key: const Key('topic_time_range_loading_tag'),
            isConfig: true,
          ),
          isPinned: false,
          width: estimateTagWidth(text),
        ),
      ];
    case TopicFactStatus.error:
      final text =
          '${l10n?.topicHeaderTimeRangeError(tr.error ?? '') ?? 'Time range failed'} · ${l10n?.retry ?? 'Retry'}';
      return [
        (
          widget: TopicTag(
            text,
            key: const Key('topic_time_range_error_tag'),
            isConfig: true,
            onTap: facts.loadTimeRange,
          ),
          isPinned: true,
          width: estimateTagWidth(text),
        ),
      ];
    case TopicFactStatus.value:
      final range = tr.data!;
      if (range.allEmpty) {
        final text = l10n?.topicHeaderTimeRangeEmpty ?? 'No messages';
        return [
          (
            widget: TopicTag(
              text,
              key: const Key('topic_time_range_empty_tag'),
              isConfig: true,
            ),
            isPinned: false,
            width: estimateTagWidth(text),
          ),
        ];
      }
      final oldest = range.oldest;
      final newest = range.newest;
      if (oldest == null || newest == null) {
        final text = l10n?.topicHeaderTimeRangeUnknown ?? 'Time range: unknown';
        return [
          (
            widget: TopicTag(
              text,
              key: const Key('topic_time_range_unknown_tag'),
              isConfig: true,
            ),
            isPinned: true,
            width: estimateTagWidth(text),
          ),
        ];
      }
      final oldestStr = formatZoneTimestamp(
        timeDisplaySettings,
        context,
        oldest.timestampMs.toInt(),
      );
      final newestStr = formatZoneTimestamp(
        timeDisplaySettings,
        context,
        newest.timestampMs.toInt(),
      );
      final tooltipLines = <String>[
        'P${oldest.partition} @ ${oldest.offset} (${oldest.timestampType.name})',
        'P${newest.partition} @ ${newest.offset} (${newest.timestampType.name})',
      ];
      final nonFoundReasons = <String>[];
      for (final probe in range.probes) {
        if (probe.oldest.kind != ProbeOutcomeKind.found &&
            probe.oldest.kind != ProbeOutcomeKind.empty) {
          nonFoundReasons.add(
            'P${probe.partition} oldest: ${probe.oldest.reason ?? probe.oldest.kind.name}',
          );
        }
        if (probe.newest.kind != ProbeOutcomeKind.found &&
            probe.newest.kind != ProbeOutcomeKind.empty) {
          nonFoundReasons.add(
            'P${probe.partition} newest: ${probe.newest.reason ?? probe.newest.kind.name}',
          );
        }
      }
      final valueText =
          l10n?.topicHeaderTimeRangeValue(oldestStr, newestStr) ??
          '$oldestStr – $newestStr';
      final mainTag = Tooltip(
        message: tooltipLines.join('\n'),
        child: TopicTag(
          valueText,
          key: const Key('topic_time_range_tag'),
          isConfig: true,
        ),
      );
      if (nonFoundReasons.isEmpty) {
        return [
          (
            widget: mainTag,
            isPinned: false,
            width: estimateTagWidth(valueText),
          ),
        ];
      }
      final partialText =
          l10n?.topicHeaderTimeRangePartial(
            range.oldestKnown,
            range.newestKnown,
            range.partitionsTotal,
          ) ??
          'Partial (${range.oldestKnown}/${range.partitionsTotal} oldest, ${range.newestKnown}/${range.partitionsTotal} newest)';
      return [
        (widget: mainTag, isPinned: false, width: estimateTagWidth(valueText)),
        (
          widget: Tooltip(
            key: const Key('topic_time_range_partial_tooltip'),
            message: nonFoundReasons.join('\n'),
            child: TopicTag(
              partialText,
              key: const Key('topic_time_range_partial_tag'),
              isConfig: true,
            ),
          ),
          isPinned: true,
          width: estimateTagWidth(partialText),
        ),
      ];
  }
}

String formatZoneTimestamp(
  TimeDisplaySettings timeDisplaySettings,
  BuildContext context,
  int timestampMs,
) {
  final utc = DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true);
  final dt = timeDisplaySettings.isUtc ? utc : utc.toLocal();
  final formatted = DateFormatUtils.formatDateTime(context, dt);
  if (timeDisplaySettings.isUtc) {
    return '$formatted UTC';
  }
  final offset = dt.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final absMinutes = offset.inMinutes.abs();
  final hours = absMinutes ~/ 60;
  final mins = absMinutes % 60;
  final offsetLabel = mins == 0
      ? 'UTC$sign$hours'
      : 'UTC$sign$hours:${mins.toString().padLeft(2, '0')}';
  return '$formatted $offsetLabel';
}
