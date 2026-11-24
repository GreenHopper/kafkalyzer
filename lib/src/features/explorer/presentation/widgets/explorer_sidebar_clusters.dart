import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/active_connection_controller.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/features/schema/presentation/controllers/schema_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/cluster_service.dart';

/// The cluster entry in `ClusterProfile` currently being shown, refreshed from
/// the controller list so renamed or edited profiles do not go stale.
ClusterProfile resolveLatestProfile(
  ClusterProfile fallback,
  ClusterListController clusterController,
) {
  return clusterController.clusters.cast<ClusterProfile?>().firstWhere(
        (c) => c?.name == fallback.name,
        orElse: () => null,
      ) ??
      fallback;
}

/// Disconnects [cluster], asking first when that cluster still has a running
/// stream or analysis.
Future<void> disconnectCluster(
  BuildContext context,
  ClusterProfile cluster,
  ActiveConnectionController activeController,
) async {
  if (activeController.hasRunningOperations(cluster)) {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.disconnectConfirmTitle(cluster.name)),
        content: Text(l10n.disconnectConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.disconnectConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
  }
  activeController.disconnect();
}

/// Sidebar list of configured clusters with its own filter field, appearing
/// once the list grows past five entries.
class ExplorerClusterList extends StatefulWidget {
  final ClusterListController clusterController;
  final ActiveConnectionController activeController;
  final TopicController topicController;
  final SchemaController schemaController;

  const ExplorerClusterList({
    super.key,
    required this.clusterController,
    required this.activeController,
    required this.topicController,
    required this.schemaController,
  });

  @override
  State<ExplorerClusterList> createState() => _ExplorerClusterListState();
}

class _ExplorerClusterListState extends State<ExplorerClusterList> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final clusters = widget.clusterController.clusters;
    final showFilter = clusters.length > 5;
    final filtered = showFilter
        ? clusters.where((c) => matchesClusterFilter(c, _filterQuery)).toList()
        : clusters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showFilter) ...[
          ClusterFilterField(
            controller: _filterController,
            dense: true,
            onChanged: (q) => setState(() => _filterQuery = q),
          ),
          const SizedBox(height: 8),
        ],
        if (showFilter && filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Text(
                  l10n.clusterFilterNoMatch,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TextButton(
                  onPressed: () {
                    _filterController.clear();
                    setState(() => _filterQuery = '');
                  },
                  child: Text(l10n.clusterFilterClear),
                ),
              ],
            ),
          )
        else
          LimitedBox(
            maxHeight: 200,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: filtered.map((cluster) {
                  return _ClusterTile(
                    cluster: cluster,
                    activeController: widget.activeController,
                    topicController: widget.topicController,
                    schemaController: widget.schemaController,
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClusterTile extends StatelessWidget {
  final ClusterProfile cluster;
  final ActiveConnectionController activeController;
  final TopicController topicController;
  final SchemaController schemaController;

  const _ClusterTile({
    required this.cluster,
    required this.activeController,
    required this.topicController,
    required this.schemaController,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isActive = activeController.activeProfile?.name == cluster.name;
    final isConnecting =
        activeController.connectingProfile?.name == cluster.name ||
        (isActive && activeController.isConnecting);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isActive,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
        title: _ClusterTitle(
          cluster: cluster,
          isActive: isActive,
          topicController: topicController,
        ),
        onTap: isConnecting
            ? null
            : () {
                activeController.connect(cluster);
                schemaController.fetchSchemas(cluster);
              },
        trailing: isConnecting
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (isActive
                  ? Semantics(
                      label: l10n.disconnectClusterTooltip,
                      button: true,
                      child: IconButton(
                        icon: const Icon(Icons.link_off, size: 16),
                        tooltip: l10n.disconnectClusterTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => disconnectCluster(
                          context,
                          cluster,
                          activeController,
                        ),
                      ),
                    )
                  : null),
      ),
    );
  }
}

class _ClusterTitle extends StatelessWidget {
  final ClusterProfile cluster;
  final bool isActive;
  final TopicController topicController;

  const _ClusterTitle({
    required this.cluster,
    required this.isActive,
    required this.topicController,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasEnvTag =
            cluster.environmentLabel != null &&
            cluster.environmentLabel!.trim().isNotEmpty;
        final isNarrow =
            constraints.maxWidth.isFinite &&
            (constraints.maxWidth < 210 ||
                (hasEnvTag && constraints.maxWidth < 250) ||
                (cluster.name.length > 14 && constraints.maxWidth < 245));
        return Row(
          children: [
            if (topicController.hasCachedTopics(cluster))
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(
                  Icons.check_circle,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            Flexible(
              child: Text(
                cluster.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Theme.of(context).colorScheme.onPrimaryContainer
                      : (topicController.hasCachedTopics(cluster)
                            ? Theme.of(context).colorScheme.primary
                            : null),
                ),
              ),
            ),
            if (hasEnvTag) ...[
              const SizedBox(width: 6),
              EnvironmentTagChip(profile: cluster, compact: true),
            ],
            if (cluster.tlsVerification == TlsVerification.disabled) ...[
              const SizedBox(width: 6),
              InsecureTlsBadge(compact: true, iconOnly: isNarrow),
            ],
          ],
        );
      },
    );
  }
}
