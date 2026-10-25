import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/topic_partition_health_table.dart';

/// Modal dialog showing partition replication breakdown (leader, replicas, ISR).
class TopicPartitionHealthDialog extends StatelessWidget {
  final ClusterProfile profile;
  final String topicName;

  const TopicPartitionHealthDialog({
    super.key,
    required this.profile,
    required this.topicName,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Dialog(
      key: const Key('topic_partition_health_dialog'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 700,
          maxHeight: 500,
          minWidth: 450,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.dns_outlined,
                    size: 22,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.partitionHealthDialogTitle ??
                              'Partition Health & Replication',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          topicName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('partition_health_dialog_close'),
                    icon: const Icon(Icons.close),
                    tooltip: l10n?.close ?? 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Flexible(
                child: TopicPartitionHealthTable(
                  key: Key('dialog_health_table_${profile.name}_$topicName'),
                  profile: profile,
                  topicName: topicName,
                  maxHeight: 360,
                  decoration: const BoxDecoration(),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
