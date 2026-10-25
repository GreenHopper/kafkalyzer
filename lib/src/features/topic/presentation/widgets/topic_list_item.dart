import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/features/topic/utils/dlq_topic_detector.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class TopicListItem extends StatefulWidget {
  final TopicMetadata topic;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onOpenInNewTab;
  final Widget? trailing;
  final ClusterProfile? clusterProfile;
  final String? highlightQuery;
  final List<String>? associatedFailureTopics;
  final ValueChanged<String>? onSelectFailureTopic;

  const TopicListItem({
    super.key,
    required this.topic,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onOpenInNewTab,
    this.trailing,
    this.clusterProfile,
    this.highlightQuery,
    this.associatedFailureTopics,
    this.onSelectFailureTopic,
  });

  @override
  State<TopicListItem> createState() => _TopicListItemState();
}

class _TopicListItemState extends State<TopicListItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.isSelected;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: isSelected
          ? theme.colorScheme.secondaryContainer
          : theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: _buildTooltipMessage(context),
        waitDuration: const Duration(milliseconds: 350),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              dense: true,
              visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              title: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onDoubleTap: widget.onDoubleTap,
                child: _buildTitle(context),
              ),
              onTap: widget.onTap,
              trailing: _buildTrailing(context),
            ),
            if (_isExpanded &&
                widget.associatedFailureTopics != null &&
                widget.associatedFailureTopics!.isNotEmpty)
              _buildChildFailureTopics(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = widget.isSelected;
    final l10n = AppLocalizations.of(context);

    final prefixStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isSelected
              ? colorScheme.onSecondaryContainer.withValues(alpha: 0.7)
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
          fontWeight: FontWeight.normal,
        ) ??
        const TextStyle();

    final leafStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isSelected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurface,
        ) ??
        const TextStyle(fontWeight: FontWeight.bold);

    final highlightStyle = TextStyle(
      backgroundColor: isSelected
          ? colorScheme.primary.withValues(alpha: 0.28)
          : colorScheme.tertiaryContainer,
      color: isSelected
          ? colorScheme.onSecondaryContainer
          : colorScheme.onTertiaryContainer,
      fontWeight: FontWeight.bold,
    );

    final ellipsisStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: isSelected
              ? colorScheme.onSecondaryContainer.withValues(alpha: 0.5)
              : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          fontWeight: FontWeight.bold,
        ) ??
        const TextStyle();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spans = fitTopicNameToWidth(
                topicName: widget.topic.name,
                maxWidth: constraints.maxWidth,
                prefixStyle: prefixStyle,
                leafStyle: leafStyle,
                highlightStyle: highlightStyle,
                ellipsisStyle: ellipsisStyle,
                highlightQuery: widget.highlightQuery,
              );

              return Text.rich(
                TextSpan(children: spans),
                maxLines: 1,
                softWrap: false,
              );
            },
          ),
        ),
        if (DlqTopicDetector.isDlqTopic(widget.topic.name)) ...[
          const SizedBox(width: 4),
          _buildBadge(
            key: const Key('topic_dlq_badge'),
            label: l10n?.dlqBadgeLabel ?? 'DLQ',
            color: Colors.red,
          ),
        ] else if (DlqTopicDetector.isRetryTopic(widget.topic.name)) ...[
          const SizedBox(width: 4),
          _buildBadge(
            key: const Key('topic_retry_badge'),
            label: l10n?.retryBadgeLabel ?? 'Retry',
            color: Colors.orange,
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required Key key,
    required String label,
    required MaterialColor color,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color.shade800,
        ),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final List<Widget> children = [];

    final underReplicated = widget.topic.underReplicatedPartitions ?? 0;
    final leaderless = widget.topic.leaderlessPartitions ?? 0;
    if (underReplicated + leaderless > 0) {
      children.add(
        Tooltip(
          message:
              l10n?.topicHealthWarning(underReplicated, leaderless) ??
              "$underReplicated under-replicated, $leaderless leaderless",
          child: Row(
            key: const Key('topic_health_warning'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: 2),
              Text(
                '${underReplicated + leaderless}',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.associatedFailureTopics != null &&
        widget.associatedFailureTopics!.isNotEmpty) {
      final count = widget.associatedFailureTopics!.length;
      children.add(
        Tooltip(
          message: l10n?.associatedDlqCount(count) ?? "$count failure topics",
          child: Container(
            key: const Key('topic_associated_failure_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.report_problem_outlined,
                  size: 11,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 3),
                Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      children.add(
        IconButton(
          key: const Key('topic_failure_expand_button'),
          icon: Icon(
            _isExpanded ? Icons.expand_less : Icons.expand_more,
            size: 16,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
        ),
      );
    }

    if (widget.isSelected) {
      children.add(const Icon(Icons.check, size: 16));
    }
    if (widget.trailing != null) {
      children.add(widget.trailing!);
    }
    if (widget.onOpenInNewTab != null) {
      children.add(
        IconButton(
          icon: const Icon(Icons.add_to_photos_outlined, size: 16),
          tooltip: l10n?.openInNewTab ?? 'Open in New Tab',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: widget.onOpenInNewTab,
        ),
      );
    }
    if (children.isEmpty) return null;
    if (children.length == 1) return children.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          children[i],
        ],
      ],
    );
  }

  Widget _buildChildFailureTopics(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.only(left: 24, right: 12, bottom: 6),
      child: Column(
        children: [
          for (final childTopic in widget.associatedFailureTopics!)
            InkWell(
              key: Key('topic_child_failure_$childTopic'),
              onTap: widget.onSelectFailureTopic != null
                  ? () => widget.onSelectFailureTopic!(childTopic)
                  : null,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        childTopic,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (DlqTopicDetector.isDlqTopic(childTopic))
                      _buildBadge(
                        key: Key('child_dlq_badge_$childTopic'),
                        label: l10n?.dlqBadgeLabel ?? 'DLQ',
                        color: Colors.red,
                      )
                    else if (DlqTopicDetector.isRetryTopic(childTopic))
                      _buildBadge(
                        key: Key('child_retry_badge_$childTopic'),
                        label: l10n?.retryBadgeLabel ?? 'Retry',
                        color: Colors.orange,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _buildTooltipMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topic = widget.topic;
    final hasExtendedConfig =
        topic.cleanupPolicy != null || topic.retentionMs != null;
    final isAvro =
        widget.clusterProfile != null &&
        hasSchema(
          getIt<SchemaController>(),
          widget.clusterProfile!,
          topic.name,
        );

    String meta;
    if (l10n != null) {
      if (hasExtendedConfig) {
        meta = l10n.topicTooltip(
          topic.partitionCount,
          topic.replicationFactor,
          topic.retentionMs != null
              ? formatRetention(topic.retentionMs!)
              : "N/A",
          topic.cleanupPolicy != null
              ? splitPolicy(topic.cleanupPolicy!)
              : "N/A",
        );
      } else {
        meta = l10n.topicTooltipSimple(
          topic.partitionCount,
          topic.replicationFactor,
        );
      }
      if (isAvro) {
        meta += l10n.schemaTooltipSuffix("Avro");
      }
      if ((topic.underReplicatedPartitions ?? 0) +
              (topic.leaderlessPartitions ?? 0) >
          0) {
        meta +=
            "\n${l10n.topicHealthWarning(topic.underReplicatedPartitions ?? 0, topic.leaderlessPartitions ?? 0)}";
      }
    } else {
      if (hasExtendedConfig) {
        final retention = topic.retentionMs != null
            ? formatRetention(topic.retentionMs!)
            : "N/A";
        final cleanup = topic.cleanupPolicy != null
            ? splitPolicy(topic.cleanupPolicy!)
            : "N/A";
        meta =
            "Partitions: ${topic.partitionCount} • RF: ${topic.replicationFactor} • Retention: $retention • Cleanup: $cleanup";
      } else {
        meta =
            "Partitions: ${topic.partitionCount} • RF: ${topic.replicationFactor}";
      }
      if (isAvro) {
        meta += " • Schema: Avro";
      }
    }

    return "${topic.name}\n$meta";
  }
}
