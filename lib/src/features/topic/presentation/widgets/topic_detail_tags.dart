import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_detail_fact_tags.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_tag.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_facts_controller.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';

/// The fact strip under the topic title: health, partitions, estimate,
/// schema, config status, retention and time range, with the tags that do not
/// fit moved behind an overflow chip.
///
/// The local schema tag is passed in as a record, because only the caller
/// holds the local schema services.
class TopicDetailTags extends StatelessWidget {
  final ClusterProfile profile;
  final TopicMetadata topic;
  final TopicController? topicController;
  final TopicFactsController factsController;
  final SchemaController schemaController;
  final TimeDisplaySettings timeDisplaySettings;
  final ({Widget? tag, bool isPinned, double estimatedWidth}) localSchemaFact;
  final VoidCallback onOpenPartitionHealthDialog;

  const TopicDetailTags({
    super.key,
    required this.profile,
    required this.topic,
    required this.topicController,
    required this.factsController,
    required this.schemaController,
    required this.timeDisplaySettings,
    required this.localSchemaFact,
    required this.onOpenPartitionHealthDialog,
  });

  @override
  Widget build(BuildContext context) => _buildTopicTags(context);


Widget _buildTopicTags(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  final healthTooltip =
      l10n?.partitionHealthTooltip ??
      'View partition replication & health details';

  if (!topic.metadataKnown) {
return _metadataErrorTags(context, l10n);
  }

  final configView = topicController?.configFor(profile, topic.name);

  return ListenableBuilder(
    listenable: Listenable.merge([
      factsController,
      timeDisplaySettings,
      schemaController,
    ]),
    builder: (context, _) {
      final pinned = <({Widget widget, double width})>[];
      final regular = <({Widget widget, double width})>[];

        _addHealthFacts(pinned, regular, l10n, healthTooltip);

      // 1. Unhealthy partitions warning (always pinned)

      // 2. Partitions & RF (primary regular facts)


      // 3. Estimate fact (pinned if unknown/notReadable, else regular)
      for (final estItem in buildEstimateFactItems(factsController, context, l10n, topic)) {
        if (estItem.isPinned) {
          pinned.add((widget: estItem.widget, width: estItem.width));
        } else {
          regular.add((widget: estItem.widget, width: estItem.width));
        }
      }

      // 4. Schema tags (pinned if unknown/error, else primary regular)
_addSchemaFact(pinned, regular, l10n);

      final localSchemaItem = localSchemaFact;
      if (localSchemaItem.tag != null) {
        if (localSchemaItem.isPinned) {
          pinned.add((
            widget: localSchemaItem.tag!,
            width: localSchemaItem.estimatedWidth,
          ));
        } else {
          regular.add((
            widget: localSchemaItem.tag!,
            width: localSchemaItem.estimatedWidth,
          ));
        }
      }

      // 5. Config view status (pinned if notReadable/failed, regular if loading)
_addConfigStatusFacts(pinned, regular, l10n, configView);

      // 6. Retention & policy tags
      for (final retItem in buildRetentionAndPolicyFactItems(
        factsController,
        context,
        l10n,
        topic,
        configView,
      )) {
        if (retItem.isPinned) {
          pinned.add((widget: retItem.widget, width: retItem.width));
        } else {
          regular.add((widget: retItem.widget, width: retItem.width));
        }
      }

      // 7. Time range facts
      for (final trItem in buildTimeRangeFactItems(
        factsController,
        timeDisplaySettings,
        context,
        l10n,
        topic,
      )) {
        if (trItem.isPinned) {
          pinned.add((widget: trItem.widget, width: trItem.width));
        } else {
          regular.add((widget: trItem.widget, width: trItem.width));
        }
      }

return _factsStrip(context, l10n, pinned, regular);
    },
  );
}

  Widget _metadataErrorTags(BuildContext context, AppLocalizations? l10n) {
final err = topic.metadataError!;
final reason = switch (err.kind) {
  TopicMetadataErrorKind.notFound =>
    l10n?.topicMetadataNotFound ?? 'topic not found',
  TopicMetadataErrorKind.notAuthorized =>
    l10n?.topicConfigNotReadable ?? 'not readable — permission?',
  TopicMetadataErrorKind.other =>
    l10n?.topicConfigLoadFailed ?? 'could not be loaded',
};
final schemaLabel = resolveTopicSchemaLabel(
  l10n,
  schemaController,
  profile,
  topic.name,
);
final localSchemaItem = localSchemaFact;
return Wrap(
  spacing: 8,
  runSpacing: 4,
  children: [
    TopicTag(reason, key: const Key('topic_metadata_error_tag')),
    if (schemaLabel != null)
      TopicTag(
        schemaLabel,
        key: const Key('topic_schema_tag'),
        isSchema: true,
      ),
    ?localSchemaItem.tag,
  ],
);
  }

  void _addHealthFacts(
    List<({Widget widget, double width})> pinned,
    List<({Widget widget, double width})> regular,
    AppLocalizations? l10n,
    String healthTooltip,
  ) {
    final unhealthy =
        (topic.underReplicatedPartitions ?? 0) +
        (topic.leaderlessPartitions ?? 0);
if (unhealthy > 0) {
  final text =
      l10n?.topicHealthWarning(
        topic.underReplicatedPartitions ?? 0,
        topic.leaderlessPartitions ?? 0,
      ) ??
      'Unhealthy partitions';
  pinned.add((
    widget: Tooltip(
      message: healthTooltip,
      child: TopicTag(
        text,
        key: const Key('topic_health_tag'),
        onTap: () => onOpenPartitionHealthDialog(),
      ),
    ),
    width: estimateTagWidth(text),
  ));
}
final partitionsText =
    l10n?.topicPartitionsLabel(topic.partitionCount) ??
    "${topic.partitionCount} Partitions";
regular.add((
  widget: Tooltip(
    message: healthTooltip,
    child: TopicTag(
      partitionsText,
      key: const Key('topic_partitions_tag'),
      onTap: () => onOpenPartitionHealthDialog(),
    ),
  ),
  width: estimateTagWidth(partitionsText),
));
final rfText =
    l10n?.topicRfLabel(topic.replicationFactor) ??
    "RF: ${topic.replicationFactor}";
regular.add((
  widget: Tooltip(
    message: healthTooltip,
    child: TopicTag(
      rfText,
      key: const Key('topic_rf_tag'),
      onTap: () => onOpenPartitionHealthDialog(),
    ),
  ),
  width: estimateTagWidth(rfText),
));
  }

  void _addSchemaFact(
    List<({Widget widget, double width})> pinned,
    List<({Widget widget, double width})> regular,
    AppLocalizations? l10n,
  ) {
    final schemaLabel = resolveTopicSchemaLabel(
      l10n,
      schemaController,
      profile,
      topic.name,
    );
if (schemaLabel != null) {
  final isSchemaUnknown =
      schemaController.errorFor(profile) != null;
  final schemaWidget = TopicTag(
    schemaLabel,
    key: const Key('topic_schema_tag'),
    isSchema: true,
  );
  if (isSchemaUnknown) {
    pinned.add((
      widget: schemaWidget,
      width: estimateTagWidth(schemaLabel),
    ));
  } else {
    regular.add((
      widget: schemaWidget,
      width: estimateTagWidth(schemaLabel),
    ));
  }
}
  }

  void _addConfigStatusFacts(
    List<({Widget widget, double width})> pinned,
    List<({Widget widget, double width})> regular,
    AppLocalizations? l10n,
    TopicConfigView? configView,
  ) {
if (configView != null) {
  switch (configView.state) {
    case TopicConfigViewState.loading:
      if (topic.cleanupPolicy == null && topic.retentionMs == null) {
        final text = l10n?.topicConfigLoading ?? 'loading';
        regular.add((
          widget: TopicTag(
            text,
            key: const Key('topic_config_loading_tag'),
            isConfig: true,
          ),
          width: estimateTagWidth(text),
        ));
      }
    case TopicConfigViewState.available:
      break;
    case TopicConfigViewState.notReadable:
      final text =
          l10n?.topicConfigNotReadable ?? 'not readable — permission?';
      pinned.add((
        widget: TopicTag(
          text,
          key: const Key('topic_config_not_readable_tag'),
          isConfig: true,
        ),
        width: estimateTagWidth(text),
      ));
    case TopicConfigViewState.failed:
      final text =
          '${l10n?.topicConfigLoadFailed ?? 'could not be loaded'} · ${l10n?.retry ?? 'Retry'}';
      pinned.add((
        widget: TopicTag(
          text,
          key: const Key('topic_config_failed_tag'),
          isConfig: true,
          onTap: () =>
              topicController!.retryConfig(profile, topic.name),
        ),
        width: estimateTagWidth(text),
      ));
  }
}
  }

  Widget _factsStrip(
    BuildContext context,
    AppLocalizations? l10n,
    List<({Widget widget, double width})> pinned,
    List<({Widget widget, double width})> regular,
  ) {
return LayoutBuilder(
  builder: (context, constraints) {
    final maxWidth = constraints.maxWidth.isFinite
        ? constraints.maxWidth
        : 1200.0;
    const spacing = 8.0;
    const overflowChipReservedWidth = 44.0;

    double usedWidth = 0.0;
    final visible = <Widget>[];
    final overflow = <Widget>[];

    for (final item in pinned) {
      if (visible.isNotEmpty) usedWidth += spacing;
      usedWidth += item.width;
      visible.add(item.widget);
    }

    // Compute total width if all regular items were shown without overflow chip
    double totalIfAllShown = usedWidth;
    for (int i = 0; i < regular.length; i++) {
      if (visible.isNotEmpty || i > 0) totalIfAllShown += spacing;
      totalIfAllShown += regular[i].width;
    }

    if (totalIfAllShown <= maxWidth) {
      for (final item in regular) {
        visible.add(item.widget);
      }
    } else {
      final budget = maxWidth - overflowChipReservedWidth - spacing;
      for (final item in regular) {
        final nextWidth =
            usedWidth + (visible.isEmpty ? 0 : spacing) + item.width;
        if (overflow.isEmpty &&
            (nextWidth <= budget || visible.isEmpty)) {
          usedWidth = nextWidth;
          visible.add(item.widget);
        } else {
          overflow.add(item.widget);
        }
      }
    }

    if (overflow.isNotEmpty) {
      visible.add(buildOverflowFactsChip(context, l10n, overflow));
    }

    return Wrap(
      key: const Key('topic_facts_strip'),
      spacing: spacing,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: visible,
    );
  },
);
  }
}
