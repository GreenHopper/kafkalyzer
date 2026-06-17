import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/features/topic/presentation/controllers/topic_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

class ClusterDropdown extends StatelessWidget {
  final ClusterProfile? value;
  final ValueChanged<ClusterProfile?> onChanged;
  final String? labelText;
  final bool isDense;
  final bool isExpanded;
  final EdgeInsetsGeometry? contentPadding;

  const ClusterDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.labelText = "Cluster",
    this.isDense = true,
    this.isExpanded = true,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final clusterController = getIt<ClusterListController>();
    final topicController = getIt<TopicController>();

    return ListenableBuilder(
      listenable: Listenable.merge([clusterController, topicController]),
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
                      if (topicController.hasCachedTopics(c))
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Icon(Icons.check_circle, size: 16, color: Theme.of(context).colorScheme.primary),
                        ),
                      Text(
                        c.name,
                        style: TextStyle(
                          color: topicController.hasCachedTopics(c) ? Theme.of(context).colorScheme.primary : null,
                          fontWeight: topicController.hasCachedTopics(c) ? FontWeight.w600 : null,
                        ),
                      ),
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
