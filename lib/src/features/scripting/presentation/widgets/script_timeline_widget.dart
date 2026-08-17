import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';

class ScriptTimelineWidget extends StatelessWidget {
  final Script script;
  final ScriptRunner runner;

  const ScriptTimelineWidget({
    super.key,
    required this.script,
    required this.runner,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: runner,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final stepCount = script.steps.length;
            if (stepCount == 0) return const SizedBox.shrink();

            final stepWidth = constraints.maxWidth / stepCount;

            // Calculate active index for progress line
            int lastCompletedIndex = -1;
            int runningIndex = -1;

            for (int i = 0; i < stepCount; i++) {
              final status =
                  runner.stepStatuses[script.steps[i].id] ?? StepStatus.pending;
              if (status == StepStatus.completed) {
                lastCompletedIndex = i;
              } else if (status == StepStatus.running) {
                runningIndex = i;
              }
            }

            // Determine how far the line goes
            int progressToIndex = -1;
            Color lineColor = Colors.green;

            if (runningIndex != -1) {
              progressToIndex = runningIndex;
              lineColor = Colors.blue;
            } else if (lastCompletedIndex != -1) {
              progressToIndex = lastCompletedIndex;
              lineColor = Colors.green;
            }

            return SizedBox(
              height: 48,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Background Line
                  Positioned(
                    left: stepWidth / 2,
                    right: stepWidth / 2,
                    top: 23,
                    child: Container(
                      height: 2,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),

                  // Progress Line
                  if (progressToIndex > 0)
                    Positioned(
                      left: stepWidth / 2,
                      width: stepWidth * progressToIndex,
                      top: 23,
                      child: Container(height: 2, color: lineColor),
                    ),

                  // Steps
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: script.steps.asMap().entries.map((entry) {
                      final index = entry.key;
                      final step = entry.value;
                      final status =
                          runner.stepStatuses[step.id] ?? StepStatus.pending;

                      return Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Tooltip(
                                message:
                                    "${step.name}: ${status.name.toUpperCase()}",
                                child: _buildStepIndicator(
                                  context,
                                  status,
                                  index + 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStepIndicator(
    BuildContext context,
    StepStatus status,
    int index,
  ) {
    Widget child;

    switch (status) {
      case StepStatus.pending:
        child = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            "$index",
            style: TextStyle(
              color: Colors.grey.withValues(alpha: 0.7),
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        );
        break;
      case StepStatus.running:
        child = SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ),
              Text(
                "$index",
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
        break;
      case StepStatus.completed:
        child = Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 18),
        );
        break;
      case StepStatus.error:
        child = Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.priority_high, color: Colors.white, size: 18),
        );
        break;
    }

    if (status == StepStatus.pending) {
      return Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        child: child,
      );
    }

    return child;
  }
}
