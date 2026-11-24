import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/ui/widgets/environment_tag.dart';
import 'package:kafkalyzer/src/ui/widgets/insecure_tls_badge.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/services/topic_store.dart';

class ClusterDropdown extends StatelessWidget {
  final ClusterProfile? value;
  final ValueChanged<ClusterProfile?> onChanged;
  final String? labelText;
  final bool isDense;
  final bool isExpanded;
  final EdgeInsetsGeometry? contentPadding;

  /// Session-wide controllers; null falls back to the application container.
  final ClusterListController? clusterController;

  /// Whether a cluster has cached topics, and what repaints that answer. The
  /// caller supplies both, so this widget names no topic type; null falls back
  /// to the shared topic store.
  final bool Function(ClusterProfile)? hasCachedTopics;
  final Listenable? topicsListenable;

  const ClusterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = "Cluster",
    this.isDense = true,
    this.isExpanded = true,
    this.contentPadding,
    this.clusterController,
    this.hasCachedTopics,
    this.topicsListenable,
  });

  @override
  Widget build(BuildContext context) {
    final clusterController =
        this.clusterController ?? getIt<ClusterListController>();
    final store = getIt<TopicStore>();
    final hasCachedTopics = this.hasCachedTopics ?? store.hasCachedTopics;

    return ListenableBuilder(
      listenable: Listenable.merge([
        clusterController,
        topicsListenable ?? store.topicListenable,
      ]),
      builder: (context, _) {
        return DropdownButtonFormField<ClusterProfile>(
          decoration: InputDecoration(
            labelText: labelText,
            isDense: isDense,
            border: const OutlineInputBorder(),
            contentPadding: contentPadding,
          ),
          initialValue: value,
          isExpanded: isExpanded,
          items: clusterController.clusters
              .map(
                (c) => DropdownMenuItem(
                  value: c,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasCachedTopics(c))
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
                          c.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: hasCachedTopics(c)
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            fontWeight: hasCachedTopics(c)
                                ? FontWeight.w600
                                : null,
                          ),
                        ),
                      ),
                      if (c.environmentLabel != null &&
                          c.environmentLabel!.trim().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        EnvironmentTagChip(profile: c, compact: true),
                      ],
                      if (c.tlsVerification == TlsVerification.disabled) ...[
                        const SizedBox(width: 8),
                        const InsecureTlsBadge(compact: true),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        );
      },
    );
  }
}
