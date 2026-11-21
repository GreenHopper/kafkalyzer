import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
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
  final RegExp? highlightPattern;
  final List<String>? associatedFailureTopics;
  final ValueChanged<String>? onSelectFailureTopic;
  final bool isFavourite;
  final VoidCallback? onToggleFavourite;
  final bool isMissingFavourite;

  /// Session-wide collaborators; null falls back to the application container.
  final TopicController? topicController;
  final SchemaController? schemaController;

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
    this.highlightPattern,
    this.associatedFailureTopics,
    this.onSelectFailureTopic,
    this.isFavourite = false,
    this.onToggleFavourite,
    this.isMissingFavourite = false,
    this.topicController,
    this.schemaController,
  });

  @override
  State<TopicListItem> createState() => _TopicListItemState();
}

class _TopicListItemState extends State<TopicListItem> {
  bool _isExpanded = false;

  TopicController? get _topicController =>
      widget.topicController ??
      (getIt.isRegistered<TopicController>() ? getIt<TopicController>() : null);

  SchemaController? get _schemaController =>
      widget.schemaController ??
      (getIt.isRegistered<SchemaController>()
          ? getIt<SchemaController>()
          : null);

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
      child: _topicController != null && widget.clusterProfile != null
          ? ListenableBuilder(
              listenable: _topicController!,
              builder: (context, child) => Tooltip(
                message: _buildTooltipMessage(context),
                waitDuration: const Duration(milliseconds: 350),
                child: child,
              ),
              child: _buildCardContent(context),
            )
          : Tooltip(
              message: _buildTooltipMessage(context),
              waitDuration: const Duration(milliseconds: 350),
              child: _buildCardContent(context),
            ),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
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
          subtitle: widget.isMissingFavourite
              ? Text(
                  l10n?.topicListNotInList ?? 'not in topic list',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                )
              : null,
          onTap: widget.onTap,
          trailing: _buildTrailing(context),
        ),
        if (_isExpanded &&
            widget.associatedFailureTopics != null &&
            widget.associatedFailureTopics!.isNotEmpty)
          _buildChildFailureTopics(context),
      ],
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = widget.isSelected;
    final l10n = AppLocalizations.of(context);

    final prefixStyle =
        theme.textTheme.bodyMedium?.copyWith(
          color: widget.isMissingFavourite
              ? colorScheme.outline
              : isSelected
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.normal,
        ) ??
        const TextStyle();

    final leafStyle =
        theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: widget.isMissingFavourite
              ? colorScheme.outline
              : isSelected
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
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
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
                highlightPattern: widget.highlightPattern,
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
            backgroundColor: Theme.of(context).colorScheme.errorContainer,
            foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ] else if (DlqTopicDetector.isRetryTopic(widget.topic.name)) ...[
          const SizedBox(width: 4),
          _buildBadge(
            key: const Key('topic_retry_badge'),
            label: l10n?.retryBadgeLabel ?? 'Retry',
            backgroundColor: Theme.of(context).colorScheme.tertiaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onTertiaryContainer,
          ),
        ],
      ],
    );
  }

  Widget _buildBadge({
    required Key key,
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border.all(color: foregroundColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
          color: foregroundColor,
        ),
      ),
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final List<Widget> children = [];

    if (!widget.topic.metadataKnown && !widget.isMissingFavourite) {
      children.add(
        Icon(
          Icons.warning_amber_rounded,
          key: const Key('topic_metadata_error_icon'),
          size: 16,
          color: theme.colorScheme.error,
        ),
      );
    }

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
                style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
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
                  style: theme.textTheme.labelSmall?.copyWith(
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
          tooltip: _isExpanded
              ? (AppLocalizations.of(context)?.collapseTooltip ?? 'Collapse')
              : (AppLocalizations.of(context)?.expandTooltip ?? 'Expand'),
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: () => setState(() => _isExpanded = !_isExpanded),
        ),
      );
    }

    if (widget.onToggleFavourite != null) {
      children.add(
        IconButton(
          key: Key('topic_favourite_button_${widget.topic.name}'),
          icon: Icon(
            widget.isFavourite ? Icons.star : Icons.star_border,
            size: 16,
            color: widget.isFavourite ? theme.colorScheme.primary : null,
          ),
          tooltip: widget.isFavourite
              ? (l10n?.topicListRemoveFavouriteTooltip ??
                    'Remove from favourites')
              : (l10n?.topicListAddFavouriteTooltip ?? 'Add to favourites'),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          onPressed: widget.onToggleFavourite,
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
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.errorContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onErrorContainer,
                      )
                    else if (DlqTopicDetector.isRetryTopic(childTopic))
                      _buildBadge(
                        key: Key('child_retry_badge_$childTopic'),
                        label: l10n?.retryBadgeLabel ?? 'Retry',
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.tertiaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onTertiaryContainer,
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
    if (l10n == null) return topic.name;

    if (widget.isMissingFavourite) {
      return '${topic.name}\n${l10n.topicListNotInList}';
    }

    if (!topic.metadataKnown) {
      final err = topic.metadataError!;
      final reason = switch (err.kind) {
        TopicMetadataErrorKind.notFound => l10n.topicMetadataNotFound,
        TopicMetadataErrorKind.notAuthorized => l10n.topicConfigNotReadable,
        TopicMetadataErrorKind.other => l10n.topicConfigLoadFailed,
      };
      return '${topic.name}\n$reason';
    }

    final schemaLabel =
        widget.clusterProfile != null && _schemaController != null
        ? resolveTopicSchemaLabel(
            l10n,
            _schemaController!,
            widget.clusterProfile!,
            topic.name,
          )
        : null;

    final TopicConfigView? configView =
        widget.clusterProfile != null && _topicController != null
        ? _topicController!.configFor(widget.clusterProfile!, topic.name)
        : null;

    String meta;
    if (configView != null) {
      switch (configView.state) {
        case TopicConfigViewState.loading:
          if (topic.cleanupPolicy != null || topic.retentionMs != null) {
            final retention = topic.retentionMs != null
                ? formatRetentionDuration(topic.retentionMs!, l10n)
                : l10n.topicMetadataUnknown;
            final cleanup = topic.cleanupPolicy != null
                ? splitPolicy(topic.cleanupPolicy!)
                : l10n.topicMetadataUnknown;
            meta = l10n.topicTooltip(
              topic.partitionCount,
              topic.replicationFactor,
              retention,
              cleanup,
            );
          } else {
            meta = l10n.topicTooltip(
              topic.partitionCount,
              topic.replicationFactor,
              l10n.topicConfigLoading,
              l10n.topicConfigLoading,
            );
          }
        case TopicConfigViewState.available:
          final retention = configView.retentionMs != null
              ? formatRetentionDuration(configView.retentionMs!, l10n)
              : l10n.topicMetadataUnknown;
          final cleanup = configView.cleanupPolicy != null
              ? splitPolicy(configView.cleanupPolicy!)
              : l10n.topicMetadataUnknown;
          meta = l10n.topicTooltip(
            topic.partitionCount,
            topic.replicationFactor,
            retention,
            cleanup,
          );
        case TopicConfigViewState.notReadable:
          meta = l10n.topicTooltip(
            topic.partitionCount,
            topic.replicationFactor,
            l10n.topicConfigNotReadable,
            l10n.topicConfigNotReadable,
          );
        case TopicConfigViewState.failed:
          meta = l10n.topicTooltip(
            topic.partitionCount,
            topic.replicationFactor,
            l10n.topicConfigLoadFailed,
            l10n.topicConfigLoadFailed,
          );
      }
    } else if (topic.cleanupPolicy != null || topic.retentionMs != null) {
      meta = l10n.topicTooltip(
        topic.partitionCount,
        topic.replicationFactor,
        topic.retentionMs != null
            ? formatRetentionDuration(topic.retentionMs!, l10n)
            : l10n.topicMetadataUnknown,
        topic.cleanupPolicy != null
            ? splitPolicy(topic.cleanupPolicy!)
            : l10n.topicMetadataUnknown,
      );
    } else {
      meta = l10n.topicTooltipSimple(
        topic.partitionCount,
        topic.replicationFactor,
      );
    }

    if (schemaLabel != null) {
      meta += l10n.schemaTooltipSuffix(schemaLabel);
    }
    if ((topic.underReplicatedPartitions ?? 0) +
            (topic.leaderlessPartitions ?? 0) >
        0) {
      meta +=
          '\n${l10n.topicHealthWarning(topic.underReplicatedPartitions ?? 0, topic.leaderlessPartitions ?? 0)}';
    }

    return '${topic.name}\n$meta';
  }
}
