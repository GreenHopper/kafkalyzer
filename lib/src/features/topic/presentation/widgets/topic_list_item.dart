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

  const TopicListItem({
    super.key,
    required this.topic,
    this.isSelected = false,
    this.onTap,
    this.onDoubleTap,
    this.onOpenInNewTab,
    this.trailing,
    this.clusterProfile,
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
    final (prefix, leaf) = parseTopicNameSegments(topic.name);

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isSelected
                    ? colorScheme.onSecondaryContainer.withValues(alpha: 0.7)
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                fontWeight: FontWeight.normal,
              ),
            ),
          TextSpan(
            text: leaf,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurface,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget? _buildTrailing(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final List<Widget> children = [];

    // Micro-badge: Partition count (<N>P)
    final partitionText = l10n != null
        ? l10n.partitionBadge(topic.partitionCount)
        : "${topic.partitionCount}P";
    children.add(_buildMicroBadge(context, text: partitionText));

    // Micro-badge: Schema badge (Avro)
    if (clusterProfile != null &&
        hasSchema(getIt<SchemaController>(), clusterProfile!, topic.name)) {
      children.add(_buildMicroBadge(context, text: "Avro", isSchema: true));
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

  Widget _buildMicroBadge(
    BuildContext context, {
    required String text,
    bool isSchema = false,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bgColor;
    Color textColor;

    if (isSchema) {
      if (isDark) {
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
      } else {
        bgColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
      }
    } else {
      bgColor = colorScheme.surfaceContainerHigh;
      textColor = colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _buildTooltipMessage(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasExtendedConfig =
        topic.cleanupPolicy != null || topic.retentionMs != null;

    if (l10n != null) {
      if (hasExtendedConfig) {
        return l10n.topicTooltip(
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
        return l10n.topicTooltipSimple(
          topic.partitionCount,
          topic.replicationFactor,
        );
      }
    }

    if (hasExtendedConfig) {
      final retention = topic.retentionMs != null
          ? formatRetention(topic.retentionMs!)
          : "N/A";
      final cleanup = topic.cleanupPolicy != null
          ? splitPolicy(topic.cleanupPolicy!)
          : "N/A";
      return "Partitions: ${topic.partitionCount} • RF: ${topic.replicationFactor} • Retention: $retention • Cleanup: $cleanup";
    }
    return "Partitions: ${topic.partitionCount} • RF: ${topic.replicationFactor}";
  }
}
