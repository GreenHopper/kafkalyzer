import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';

class ExplorerOnboardingView extends StatelessWidget {
  final List<ClusterProfile> clusters;
  final VoidCallback onAddCluster;
  final ValueChanged<ClusterProfile> onSelectCluster;
  final void Function(String clusterName, String topicName) onSelectRecentTopic;

  const ExplorerOnboardingView({
    super.key,
    required this.clusters,
    required this.onAddCluster,
    required this.onSelectCluster,
    required this.onSelectRecentTopic,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentTopicsService = getIt<RecentTopicsService>();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(
                          alpha: 0.4,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.hub_outlined,
                        size: 44,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n?.welcomeTitle ?? 'Welcome to Kafkalyzer',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.welcomeSubtitle ??
                          'Select a Kafka cluster to explore topics, inspect consumer lag, and run scripts.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Clusters Section
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Text(
                    l10n?.configuredClusters ?? 'Configured Clusters',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: onAddCluster,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(l10n?.addClusterAction ?? 'Add Cluster'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (clusters.isEmpty) ...[
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 40,
                            color: colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n?.noClustersConfigured ??
                                'No clusters configured yet.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: onAddCluster,
                            icon: const Icon(Icons.add, size: 18),
                            label: Text(
                              l10n?.addClusterAction ?? 'Add Cluster',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: clusters.map((cluster) {
                    final hasSchemaRegistry =
                        cluster.schemaRegistryUrl != null &&
                        cluster.schemaRegistryUrl!.trim().isNotEmpty;
                    return SizedBox(
                      width: 420,
                      child: Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      cluster.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.secondaryContainer
                                          .withValues(alpha: 0.7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      cluster.securityProtocol?.toUpperCase() ??
                                          'PLAINTEXT',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme
                                                .onSecondaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cluster.bootstrapServers,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (hasSchemaRegistry) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schema_outlined,
                                      size: 14,
                                      color: colorScheme.primary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l10n?.schemaRegistryActive ??
                                          'Schema Registry Connected',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colorScheme.primary,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerRight,
                                child: FilledButton.tonalIcon(
                                  onPressed: () => onSelectCluster(cluster),
                                  icon: const Icon(Icons.login, size: 18),
                                  label: Text(
                                    l10n?.connectCluster ?? 'Connect',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 40),

              // Recent Topics Section
              ListenableBuilder(
                listenable: recentTopicsService,
                builder: (context, _) {
                  final recentTopics = recentTopicsService.recentTopics;
                  if (recentTopics.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            l10n?.recentTopics ?? 'Recently Viewed Topics',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => recentTopicsService.clearHistory(),
                            icon: const Icon(
                              Icons.delete_sweep_outlined,
                              size: 16,
                            ),
                            label: Text(
                              l10n?.clearRecentTopics ?? 'Clear History',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: colorScheme.outlineVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (int i = 0; i < recentTopics.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ListTile(
                                leading: Icon(
                                  Icons.history,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                title: Text(
                                  recentTopics[i].topicName,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  recentTopics[i].clusterName,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.outline,
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                ),
                                onTap: () => onSelectRecentTopic(
                                  recentTopics[i].clusterName,
                                  recentTopics[i].topicName,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
