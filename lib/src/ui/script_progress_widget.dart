import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';

class ScriptProgressWidget extends StatelessWidget {
  final Script script;
  final ScriptRunner runner;
  final String? title;
  final String? overrideClusterName;

  const ScriptProgressWidget({
    super.key,
    required this.script,
    required this.runner,
    this.title,
    this.overrideClusterName,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: runner,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  title!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: script.steps.length,
              itemBuilder: (context, index) {
                final step = script.steps[index];
                final stepStatus =
                    runner.stepStatuses[step.id] ?? StepStatus.pending;
                final errorMessage = runner.stepErrorMessages[step.id];

                final stepIcon = _getStatusIcon(stepStatus);
                final stepColor = _getStatusColor(stepStatus);
                final stepText = _getStatusText(stepStatus);

                final isNoMessages =
                    errorMessage?.contains("No messages found") ?? false;
                final subtitleColor = isNoMessages
                    ? Colors.orange
                    : (stepStatus == StepStatus.error ? Colors.red : null);

                return Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    key: ValueKey("${step.id}_$stepStatus"),
                    initiallyExpanded:
                        stepStatus == StepStatus.running ||
                        stepStatus == StepStatus.error,
                    leading: stepStatus == StepStatus.running
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(stepIcon, color: stepColor),
                    title: Text(step.name),
                    subtitle: errorMessage != null
                        ? Text(
                            errorMessage,
                            style: TextStyle(
                              color: subtitleColor,
                              fontSize: 12,
                            ),
                          )
                        : (stepStatus == StepStatus.completed
                              ? Builder(
                                  builder: (context) {
                                    int totalMatches = 0;
                                    int topicsWithMatches = 0;
                                    for (final topic in step.topicNames) {
                                      final count = runner.getMatchCount(
                                        step.id,
                                        topic,
                                      );
                                      totalMatches += count;
                                      if (count > 0) topicsWithMatches++;
                                    }
                                    return Text(
                                      "$totalMatches matches found in $topicsWithMatches topics",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  overrideClusterName ?? step.clusterName,
                                  style: const TextStyle(fontSize: 12),
                                )),
                    trailing: Text(
                      stepText,
                      style: TextStyle(
                        color: stepColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    children: step.topicNames.map((topic) {
                      final key = "${step.id}_$topic";
                      final tStatus =
                          runner.topicStatuses[key] ?? StepStatus.pending;

                      return ListenableBuilder(
                        listenable: runner.multiSearchController,
                        builder: (context, _) {
                          final progress = runner.getProgress(step.id, topic);
                          final matchCount = runner.getMatchCount(
                            step.id,
                            topic,
                          );
                          return TopicProgressTile(
                            topic: topic,
                            status: tStatus,
                            progress: progress,
                            matchCount: matchCount,
                          );
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getStatusIcon(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Icons.radio_button_unchecked;
      case StepStatus.running:
        return Icons.play_circle_outline;
      case StepStatus.completed:
        return Icons.check_circle;
      case StepStatus.error:
        return Icons.error;
    }
  }

  Color _getStatusColor(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return Colors.grey;
      case StepStatus.running:
        return Colors.blue;
      case StepStatus.completed:
        return Colors.green;
      case StepStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(StepStatus status) {
    switch (status) {
      case StepStatus.pending:
        return "PENDING";
      case StepStatus.running:
        return "RUNNING";
      case StepStatus.completed:
        return "COMPLETED";
      case StepStatus.error:
        return "FAILED";
    }
  }
}
