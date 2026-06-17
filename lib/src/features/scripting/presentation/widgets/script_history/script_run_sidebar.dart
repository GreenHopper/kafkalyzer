import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/parameter_values_dialog.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/topic_selection_tree.dart';
import 'package:flutter/material.dart';

class ScriptRunSidebar extends StatelessWidget {
  final ScriptRun run;
  final List<ScriptStep> scriptSteps;
  final Map<String, Map<String, List<KafkaMessage>>> groupedResults;
  final int totalMessages;
  final Map<String, Set<String>> selectedTopics;
  final Map<String, Set<String>> parameterFilters;
  final Function(String, String) onTopicToggle;
  final Function() onClearSelection;
  final Function(String, Set<String>) onParameterFilterChanged;
  final Function(String, bool) onStepToggle;

  const ScriptRunSidebar({
    super.key,
    required this.run,
    required this.scriptSteps,
    required this.groupedResults,
    required this.totalMessages,
    required this.selectedTopics,
    required this.parameterFilters,
    required this.onTopicToggle,
    required this.onClearSelection,
    required this.onParameterFilterChanged,
    required this.onStepToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: ListView(
          children: [
            _buildSummaryCard(context),
            TopicSelectionTree(
              steps: _buildStepNodes(),
              selectedTopics: selectedTopics,
              onTopicToggle: onTopicToggle,
              onStepToggle: onStepToggle,
              onClearSelection: onClearSelection,
              otherResultsNode: _buildOtherResultsNode(context),
            ),
          ],
        ),
      ),
    );
  }

  List<TopicSelectionStepNode> _buildStepNodes() {
    return scriptSteps.map((step) {
      final stepResults = groupedResults[step.id] ?? {};
      int stepTotal = 0;
      stepResults.forEach((_, msgs) => stepTotal += msgs.length);

      final topics = step.topicNames.map((topic) {
        final msgs = stepResults[topic] ?? [];
        final count = msgs.length;
        final key = "${step.id}_$topic";
        final examined = run.topicExamined[key] ?? 0;
        return TopicSelectionTopicNode(topic: topic, count: count, examined: examined);
      }).toList();

      return TopicSelectionStepNode(id: step.id, name: step.name, totalMatches: stepTotal, topics: topics);
    }).toList();
  }

  Widget? _buildOtherResultsNode(BuildContext context) {
    if (!groupedResults.containsKey("global") &&
        !groupedResults.keys.any((k) => !scriptSteps.any((s) => s.id == k) && k != "global")) {
      return null;
    }

    final otherSteps = groupedResults.entries.where((e) => !scriptSteps.any((s) => s.id == e.key)).toList();

    return ExpansionTile(
      initiallyExpanded: true,
      title: const Text("Other Results"),
      children: otherSteps.expand((e) {
        return e.value.entries.map((tEntry) {
          final count = tEntry.value.length;
          final key = "${e.key}_${tEntry.key}";
          final examined = run.topicExamined[key] ?? 0;
          final isGlobal = e.key == 'global';

          return TopicSelectionTree(
            selectedTopics: selectedTopics,
            onClearSelection: onClearSelection,
            onStepToggle: onStepToggle,
            onTopicToggle: onTopicToggle,
            steps: [
              TopicSelectionStepNode(
                id: e.key,
                name: e.key,
                topics: [
                  TopicSelectionTopicNode(topic: tEntry.key, count: count, examined: examined, isGlobal: isGlobal),
                ],
                totalMatches: count,
              ),
            ],
          );
        });
      }).toList(),
    );
  }

  Widget _buildSummaryCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)!.runSummary,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.matchesCount(totalMessages, run.totalExamined ?? 0),
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (run.totalExamined != null)
              Text(
                AppLocalizations.of(context)!.examinedMessages(run.totalExamined!),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text("Cluster: ${run.clusterName ?? 'Default'}", style: Theme.of(context).textTheme.bodySmall),
            if (run.startTime != null && run.endTime != null) ...[
              const SizedBox(height: 4),
              Text(
                "Started: ${DateFormatUtils.formatDateTime(context, DateTime.fromMillisecondsSinceEpoch(run.startTime!))}",
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                "Finished: ${DateFormatUtils.formatDateTime(context, DateTime.fromMillisecondsSinceEpoch(run.endTime!))}",
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(
                "Total Runtime: ${_formatDuration(run.runtime)}",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
            if (run.parameters.isNotEmpty) ...[
              const Divider(height: 16),
              Text(
                AppLocalizations.of(context)!.parameters,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              ...run.parameters.entries.map((e) {
                final values = e.value.split(',').map((v) => v.trim()).where((v) => v.isNotEmpty).toList();
                final isLong = e.value.length > 50 || values.length > 1;
                final activeFilters = parameterFilters[e.key];

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    onTap: isLong || values.length > 1
                        ? () async {
                            final selected = await showDialog<Set<String>>(
                              context: context,
                              builder: (context) => ParameterValuesDialog(
                                parameterName: e.key,
                                values: values,
                                initiallySelected: parameterFilters[e.key] ?? {},
                              ),
                            );

                            if (selected != null) {
                              onParameterFilterChanged(e.key, selected);
                            }
                          }
                        : null,
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "${e.key}:",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              if (activeFilters != null && activeFilters.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8.0),
                                  child: Icon(Icons.filter_list, size: 14, color: Theme.of(context).primaryColor),
                                ),
                            ],
                          ),
                          if (isLong)
                            Text(
                              values.take(3).join(", ") + (values.length > 3 ? ", ..." : ""),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.blue,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          else
                            Text(e.value, style: Theme.of(context).textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration? d) {
    if (d == null) return "N/A";
    if (d.inSeconds < 1) return "${d.inMilliseconds}ms";
    if (d.inMinutes < 1) return "${d.inSeconds}s";
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return "${minutes}m ${seconds}s";
  }
}
