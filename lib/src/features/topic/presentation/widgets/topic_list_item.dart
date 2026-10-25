import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class TopicListItem extends StatelessWidget {
  final TopicMetadata topic;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onOpenInNewTab;
  final Widget? trailing;
  final ClusterProfile? clusterProfile;
  final String? highlightQuery;

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
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      color: isSelected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected
              ? Colors.transparent
              : Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Tooltip(
        message: _buildTooltipMessage(context),
        waitDuration: const Duration(milliseconds: 350),
        child: ListTile(
          dense: true,
          visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 0,
          ),
          title: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onDoubleTap: onDoubleTap,
            child: _buildTitle(context),
          ),
          onTap: onTap,
          trailing: _buildTrailing(context),
        ),
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final spans = fitTopicNameToWidth(
          topicName: topic.name,
          maxWidth: constraints.maxWidth,
          prefixStyle: prefixStyle,
          leafStyle: leafStyle,
          highlightStyle: highlightStyle,
          ellipsisStyle: ellipsisStyle,
          highlightQuery: highlightQuery,
        );

        return Text.rich(
          TextSpan(children: spans),
          maxLines: 1,
          softWrap: false,
        );
      },
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<Widget> children = [];

    final underReplicated = topic.underReplicatedPartitions ?? 0;
    final leaderless = topic.leaderlessPartitions ?? 0;
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
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 2),
              Text(
                '${underReplicated + leaderless}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (isSelected) {
      children.add(const Icon(Icons.check, size: 16));
    }
    if (trailing != null) {
      children.add(trailing!);
    }
    if (onOpenInNewTab != null) {
      children.add(
        IconButton(
          icon: const Icon(Icons.add_to_photos_outlined, size: 16),
          tooltip: l10n?.openInNewTab ?? 'Open in New Tab',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: onOpenInNewTab,
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

  String _buildTooltipMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasExtendedConfig =
        topic.cleanupPolicy != null || topic.retentionMs != null;
    final isAvro =
        clusterProfile != null &&
        hasSchema(getIt<SchemaController>(), clusterProfile!, topic.name);

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
