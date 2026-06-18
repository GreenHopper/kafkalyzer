import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_tag.dart';
import 'package:kafkalyzer/src/features/topic/topic_utils.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/schema/presentation/widgets/schema_viewer_dialog.dart';

class TopicListItem extends StatelessWidget {
  final TopicMetadata topic;
  final bool isSelected;
  final VoidCallback? onTap;
  final Widget? trailing;
  final ClusterProfile? clusterProfile;

  const TopicListItem({
    super.key,
    required this.topic,
    this.isSelected = false,
    this.onTap,
    this.trailing,
    this.clusterProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          topic.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Theme.of(context).colorScheme.onSecondaryContainer
                : null,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: _buildSubtitle(context),
        ),
        onTap: onTap,
        trailing: trailing,
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TopicTag("${topic.partitionCount} Partitions"),
        TopicTag("RF: ${topic.replicationFactor}"),
        if (topic.cleanupPolicy != null || topic.retentionMs != null) ...[
          if (topic.cleanupPolicy != null)
            TopicTag(splitPolicy(topic.cleanupPolicy!), isConfig: true),
          if (topic.retentionMs != null) ...[
            TopicTag(formatRetention(topic.retentionMs!), isConfig: true),
          ],
        ],
        if (clusterProfile != null &&
            hasSchema(
              getIt<SchemaController>(),
              clusterProfile!,
              topic.name,
            )) ...[
          const TopicTag("Avro", isSchema: true),
          _buildSchemaButton(context),
        ],
      ],
    );
  }

  Widget _buildSchemaButton(BuildContext context) {
    return SizedBox(
      height: 24,
      child: OutlinedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => SchemaViewerDialog(
              profile: clusterProfile!,
              topicName: topic.name,
              controller: getIt<SchemaController>(),
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 24),
          visualDensity: VisualDensity.compact,
          side: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.visibility,
              size: 14,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              "Schema",
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
