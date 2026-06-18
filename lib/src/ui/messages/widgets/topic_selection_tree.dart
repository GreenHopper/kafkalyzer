import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class TopicSelectionTopicNode {
  final String topic;
  final int count;
  final int examined;
  final bool isGlobal;

  const TopicSelectionTopicNode({
    required this.topic,
    required this.count,
    this.examined = 0,
    this.isGlobal = false,
  });
}

class TopicSelectionStepNode {
  final String id;
  final String name;
  final int totalMatches;
  final List<TopicSelectionTopicNode> topics;

  const TopicSelectionStepNode({
    required this.id,
    required this.name,
    required this.totalMatches,
    required this.topics,
  });
}

class TopicSelectionTree extends StatelessWidget {
  final List<TopicSelectionStepNode> steps;
  final Map<String, Set<String>> selectedTopics;
  final Function(String stepId, String topic) onTopicToggle;
  final Function(String stepId, bool selectAll) onStepToggle;
  final Function() onClearSelection;
  final Widget? otherResultsNode;

  const TopicSelectionTree({
    super.key,
    required this.steps,
    required this.selectedTopics,
    required this.onTopicToggle,
    required this.onStepToggle,
    required this.onClearSelection,
    this.otherResultsNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildShowAllTile(context),
        const SizedBox(height: 4),
        const Divider(),
        ...steps.map((step) => _buildStepTile(context, step)),
        ?otherResultsNode,
      ],
    );
  }

  Widget _buildShowAllTile(BuildContext context) {
    final isSelected = selectedTopics.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
      child: ListTile(
        leading: Icon(
          Icons.dashboard,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(
          AppLocalizations.of(context)?.allMessages ?? "All Messages",
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        selected: isSelected,
        selectedTileColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withAlpha(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onTap: onClearSelection,
      ),
    );
  }

  Widget _buildStepTile(BuildContext context, TopicSelectionStepNode step) {
    final stepSelectedTopics = selectedTopics[step.id] ?? {};
    final allCount = step.topics.length;
    final selectedCount = stepSelectedTopics.length;

    final isAllSelected = selectedCount == allCount && allCount > 0;
    final isNoneSelected = selectedCount == 0;

    IconData icon;
    Color? iconColor;

    if (isAllSelected) {
      icon = Icons.check_circle;
      iconColor = null;
    } else if (isNoneSelected) {
      icon = Icons.circle_outlined;
      iconColor = Colors.grey;
    } else {
      icon = Icons.remove_circle_outlined;
      iconColor = null;
    }

    final l10n = AppLocalizations.of(context);
    final subtitleText = l10n != null
        ? l10n.stepMatches(step.totalMatches)
        : "${step.totalMatches} matches";

    return ExpansionTile(
      key: ValueKey(step.id),
      initiallyExpanded: true,
      tilePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      childrenPadding: EdgeInsets.zero,
      leading: IconButton(
        icon: Icon(icon, size: 22, color: iconColor),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: () => onStepToggle(step.id, !isAllSelected),
      ),
      title: Text(
        step.name,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      subtitle: Text(subtitleText, style: const TextStyle(fontSize: 12)),
      children: step.topics.map((topicNode) {
        return _buildTopicTile(context, step.id, topicNode);
      }).toList(),
    );
  }

  Widget _buildTopicTile(
    BuildContext context,
    String stepId,
    TopicSelectionTopicNode node,
  ) {
    final isSelected = selectedTopics[stepId]?.contains(node.topic) ?? false;
    final title = node.isGlobal ? "${node.topic} (Global)" : node.topic;
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        selected: isSelected,
        selectedTileColor: Theme.of(context).colorScheme.primaryContainer,
        selectedColor: Theme.of(context).colorScheme.onPrimaryContainer,
        leading: isSelected
            ? const Icon(Icons.check_circle, size: 20)
            : const Icon(Icons.circle_outlined, size: 20, color: Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        subtitle: node.examined > 0
            ? Text(
                l10n != null
                    ? l10n.scanned(node.examined)
                    : "${node.examined} scanned",
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer.withAlpha(200)
                      : null,
                ),
              )
            : null,
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: node.count > 0
                ? (isSelected
                      ? Theme.of(context).colorScheme.surface.withAlpha(100)
                      : Theme.of(context).primaryColor.withAlpha(25))
                : Colors.grey.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "${node.count}",
            style: TextStyle(
              color: node.count > 0
                  ? (isSelected
                        ? Theme.of(context).colorScheme.onPrimaryContainer
                        : Theme.of(context).primaryColor)
                  : Colors.grey,
              fontWeight: node.count > 0 ? FontWeight.bold : FontWeight.normal,
              fontSize: 11,
            ),
          ),
        ),
        onTap: () => onTopicToggle(stepId, node.topic),
      ),
    );
  }
}
