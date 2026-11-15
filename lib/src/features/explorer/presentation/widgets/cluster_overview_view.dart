import 'dart:async';

import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/explorer/domain/cluster_summary.dart';
import 'package:kafkalyzer/src/features/explorer/presentation/controllers/cluster_overview_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_metadata.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/recent_topics_service.dart';
import 'package:material_ui/material_ui.dart';

class ClusterOverviewView extends StatefulWidget {
  final ClusterProfile profile;
  final List<TopicMetadata>? topics;
  final bool isLoading;
  final String? topicsError;
  final ValueChanged<String> onSelectTopic;
  final VoidCallback? onShowUnhealthyTopics;
  final ClusterOverviewController? overviewController;

  const ClusterOverviewView({
    super.key,
    required this.profile,
    this.topics,
    this.isLoading = false,
    this.topicsError,
    required this.onSelectTopic,
    this.onShowUnhealthyTopics,
    this.overviewController,
  });

  @override
  State<ClusterOverviewView> createState() => _ClusterOverviewViewState();
}

class _ClusterOverviewViewState extends State<ClusterOverviewView> {
  ClusterOverviewController? get _overviewController {
    if (widget.overviewController != null) return widget.overviewController;
    return getIt.isRegistered<ClusterOverviewController>()
        ? getIt<ClusterOverviewController>()
        : null;
  }

  @override
  void initState() {
    super.initState();
    _scheduleLoad();
  }

  @override
  void didUpdateWidget(covariant ClusterOverviewView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile.name != widget.profile.name ||
        oldWidget.overviewController != widget.overviewController) {
      _scheduleLoad();
    }
  }

  void _scheduleLoad() {
    final ctrl = _overviewController;
    if (ctrl == null) return;
    Future.microtask(() {
      if (mounted) {
        unawaited(ctrl.load(widget.profile));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final recentTopicsService = getIt<RecentTopicsService>();
    final overviewCtrl = _overviewController;

    final hasSchemaRegistry =
        widget.profile.schemaRegistryUrl != null &&
        widget.profile.schemaRegistryUrl!.trim().isNotEmpty;

    final Listenable listenable = overviewCtrl ?? ChangeNotifier();

    return ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final overviewState =
            overviewCtrl?.stateFor(widget.profile) ??
            const ClusterOverviewState.idle();
        final anyLoading =
            widget.isLoading ||
            overviewState.status == ClusterOverviewStatus.loading;
        final summary = (widget.topics != null && widget.topicsError == null)
            ? summarizeCluster(widget.topics!)
            : null;

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(
                    l10n: l10n,
                    theme: theme,
                    colorScheme: colorScheme,
                    anyLoading: anyLoading,
                    onRefresh: overviewCtrl == null
                        ? null
                        : () => unawaited(overviewCtrl.refresh(widget.profile)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildTotalsCard(
                          l10n: l10n,
                          theme: theme,
                          colorScheme: colorScheme,
                          summary: summary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSchemaRegistryCard(
                          l10n: l10n,
                          theme: theme,
                          colorScheme: colorScheme,
                          hasSchemaRegistry: hasSchemaRegistry,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildHealthCard(
                    l10n: l10n,
                    theme: theme,
                    colorScheme: colorScheme,
                    summary: summary,
                  ),
                  const SizedBox(height: 16),
                  _buildBrokersCard(
                    l10n: l10n,
                    theme: theme,
                    colorScheme: colorScheme,
                    state: overviewState,
                    onRetry: overviewCtrl == null
                        ? null
                        : () => unawaited(overviewCtrl.refresh(widget.profile)),
                  ),
                  const SizedBox(height: 24),
                  _buildPromptBanner(
                    l10n: l10n,
                    theme: theme,
                    colorScheme: colorScheme,
                  ),
                  const SizedBox(height: 28),
                  _buildRecentTopics(
                    l10n: l10n,
                    theme: theme,
                    colorScheme: colorScheme,
                    recentTopicsService: recentTopicsService,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool anyLoading,
    required VoidCallback? onRefresh,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.storage_outlined,
            size: 30,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      widget.profile.name,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer.withValues(
                        alpha: 0.7,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      widget.profile.securityProtocol?.toUpperCase() ??
                          'PLAINTEXT',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.profile.bootstrapServers,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (anyLoading)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SizedBox(
              key: Key('cluster_overview_loading_indicator'),
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Semantics(
          label: l10n.clusterOverviewRefreshTooltip,
          button: true,
          child: IconButton(
            key: const Key('cluster_overview_refresh_button'),
            icon: const Icon(Icons.refresh),
            tooltip: l10n.clusterOverviewRefreshTooltip,
            onPressed: anyLoading ? null : onRefresh,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsCard({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ClusterSummary? summary,
  }) {
    final String primaryText;
    final String? secondaryText;
    if (widget.isLoading) {
      primaryText = l10n.clusterOverviewTotalsLoading;
      secondaryText = null;
    } else if (summary == null) {
      primaryText = l10n.clusterOverviewTotalsUnknown;
      secondaryText = null;
    } else {
      primaryText = l10n.clusterOverviewTopicsCount(summary.totalTopics);
      secondaryText = l10n.clusterOverviewPartitionsTotal(
        summary.totalPartitions,
      );
    }

    return Card(
      key: const Key('cluster_overview_totals_card'),
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(Icons.topic_outlined, size: 32, color: colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    primaryText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (secondaryText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      secondaryText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSchemaRegistryCard({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required bool hasSchemaRegistry,
  }) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Icon(
              hasSchemaRegistry ? Icons.schema_outlined : Icons.schema,
              size: 32,
              color: hasSchemaRegistry
                  ? colorScheme.primary
                  : colorScheme.outline,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasSchemaRegistry
                        ? l10n.schemaRegistryActive
                        : l10n.schemaRegistryNotConfigured,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasSchemaRegistry
                        ? widget.profile.schemaRegistryUrl!
                        : l10n.optionalMetadataRegistry,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthCard({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ClusterSummary? summary,
  }) {
    final Widget content;
    if (widget.isLoading) {
      content = Row(
        children: [
          Icon(Icons.health_and_safety_outlined, color: colorScheme.outline),
          const SizedBox(width: 12),
          Text(
            l10n.clusterOverviewHealthStatusLoading,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else if (summary == null) {
      content = Row(
        children: [
          Icon(Icons.help_outline, color: colorScheme.outline),
          const SizedBox(width: 12),
          Text(
            l10n.clusterOverviewHealthStatusUnknown,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else {
      final hasUnhealthy = summary.unhealthyTopicCount > 0;
      final unhealthyText = hasUnhealthy
          ? l10n.clusterOverviewHealthUnhealthy(summary.unhealthyTopicCount)
          : l10n.clusterOverviewHealthHealthy;

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasUnhealthy
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline,
                color: hasUnhealthy
                    ? colorScheme.tertiary
                    : colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unhealthyText,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: hasUnhealthy ? colorScheme.tertiary : null,
                      ),
                    ),
                    if (hasUnhealthy)
                      Text(
                        l10n.clusterOverviewHealthPartitionCounts(
                          summary.underReplicatedPartitions,
                          summary.leaderlessPartitions,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (hasUnhealthy && widget.onShowUnhealthyTopics != null)
                Tooltip(
                  message: l10n.clusterOverviewShowUnhealthyTooltip,
                  child: TextButton.icon(
                    key: const Key('cluster_overview_unhealthy_drilldown'),
                    onPressed: widget.onShowUnhealthyTopics,
                    icon: const Icon(Icons.filter_list, size: 16),
                    label: Text(l10n.clusterOverviewShowUnhealthyTooltip),
                  ),
                ),
            ],
          ),
          if (summary.unknownHealthTopicCount > 0) ...[
            const SizedBox(height: 8),
            Row(
              key: const Key('cluster_overview_health_unknown_count'),
              children: [
                Icon(Icons.help_outline, size: 16, color: colorScheme.outline),
                const SizedBox(width: 8),
                Text(
                  l10n.clusterOverviewHealthUnknownCount(
                    summary.unknownHealthTopicCount,
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    return Card(
      key: const Key('cluster_overview_health_card'),
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16.0), child: content),
    );
  }

  Widget _buildBrokersCard({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ClusterOverviewState state,
    required VoidCallback? onRetry,
  }) {
    final Widget body;
    switch (state.status) {
      case ClusterOverviewStatus.idle:
      case ClusterOverviewStatus.loading:
        if (state.overview == null) {
          body = Row(
            key: const Key('cluster_overview_brokers_loading'),
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(l10n.clusterOverviewBrokersLoading),
            ],
          );
        } else {
          body = _buildBrokersContent(
            l10n: l10n,
            theme: theme,
            colorScheme: colorScheme,
            overview: state.overview!,
          );
        }
      case ClusterOverviewStatus.error:
        body = Row(
          key: const Key('cluster_overview_brokers_error'),
          children: [
            Icon(Icons.error_outline, color: colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                state.notReadable
                    ? l10n.clusterOverviewBrokersNotReadable
                    : l10n.clusterOverviewBrokersError(state.error ?? ''),
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (onRetry != null)
              TextButton(
                key: const Key('cluster_overview_brokers_retry'),
                onPressed: onRetry,
                child: Text(l10n.retry),
              ),
          ],
        );
      case ClusterOverviewStatus.loaded:
        body = _buildBrokersContent(
          l10n: l10n,
          theme: theme,
          colorScheme: colorScheme,
          overview: state.overview!,
        );
    }

    return Card(
      key: const Key('cluster_overview_brokers_card'),
      elevation: 0,
      color: colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(16.0), child: body),
    );
  }

  Widget _buildBrokersContent({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required ClusterOverview overview,
  }) {
    final brokers = [...overview.brokers]..sort((a, b) => a.id.compareTo(b.id));
    final ctrlId = overview.controllerId;
    final ctrlBroker = ctrlId == null
        ? null
        : brokers.where((b) => b.id == ctrlId).firstOrNull;
    final String controllerDisplay;
    if (ctrlId == null) {
      controllerDisplay = l10n.topicMetadataUnknown;
    } else if (ctrlBroker != null) {
      controllerDisplay =
          '${l10n.clusterOverviewBrokerIdLabel(ctrlId)} (${ctrlBroker.host}:${ctrlBroker.port})';
    } else {
      controllerDisplay = l10n.clusterOverviewBrokerIdLabel(ctrlId);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.clusterOverviewBrokersTitle(brokers.length),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 24,
          runSpacing: 6,
          children: [
            if (overview.clusterId != null && overview.clusterId!.isNotEmpty)
              Row(
                key: const Key('cluster_overview_cluster_id'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${l10n.clusterOverviewClusterIdLabel}: ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SelectableText(
                    overview.clusterId!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            Row(
              key: const Key('cluster_overview_controller'),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${l10n.clusterOverviewControllerLabel}: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  controllerDisplay,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (brokers.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 6),
          for (final b in brokers)
            Padding(
              key: Key('cluster_overview_broker_${b.id}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      l10n.clusterOverviewBrokerIdLabel(b.id),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${b.host}:${b.port}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildPromptBanner({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.selectTopicPrompt,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTopics({
    required AppLocalizations l10n,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required RecentTopicsService recentTopicsService,
  }) {
    return ListenableBuilder(
      listenable: recentTopicsService,
      builder: (context, _) {
        final clusterRecent = recentTopicsService.getRecentTopics(
          clusterName: widget.profile.name,
        );
        if (clusterRecent.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.recentTopicsForCluster(widget.profile.name),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: colorScheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < clusterRecent.length; i++) ...[
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
                        clusterRecent[i].topicName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () =>
                          widget.onSelectTopic(clusterRecent[i].topicName),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
