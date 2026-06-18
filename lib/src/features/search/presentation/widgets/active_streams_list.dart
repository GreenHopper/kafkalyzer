import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/ui/topic_progress_tile.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';

class SearchJobGroup {
  final String? jobId;
  final List<SearchTarget> targets;

  SearchJobGroup(this.jobId, this.targets);
}

class ActiveStreamsList extends StatelessWidget {
  final List<SearchTarget>? selectedTargets;
  final Function(List<SearchTarget>?) onSelectTargets;

  const ActiveStreamsList({
    super.key,
    required this.selectedTargets,
    required this.onSelectTargets,
  });

  @override
  Widget build(BuildContext context) {
    final searchController = getIt<MultiSearchController>();

    return AnimatedBuilder(
      animation: searchController,
      builder: (context, child) {
        if (searchController.targets.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32.0),
            child: Center(
              child: Text(
                "No active streams",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Active Streams",
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                TextButton(
                  onPressed: searchController.clear,
                  child: const Text(
                    "Clear All",
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._buildJobTiles(context, searchController),
          ],
        );
      },
    );
  }

  List<Widget> _buildJobTiles(
    BuildContext context,
    MultiSearchController searchController,
  ) {
    // Group targets by searchJobId
    final Map<String, List<SearchTarget>> grouped = {};
    final List<SearchTarget> ungrouped = [];

    for (final target in searchController.targets) {
      if (target.searchJobId != null) {
        grouped.putIfAbsent(target.searchJobId!, () => []).add(target);
      } else {
        ungrouped.add(target);
      }
    }

    final List<SearchJobGroup> jobs = [];
    grouped.forEach((jobId, targets) {
      jobs.add(SearchJobGroup(jobId, targets));
    });
    for (final target in ungrouped) {
      jobs.add(SearchJobGroup(null, [target]));
    }

    return jobs.map((job) {
      bool isRunning = false;
      bool isError = false;
      int totalScanned = 0;
      int totalCount = 0;
      int totalMatches = 0;
      bool hasTotal = false;

      // Group selection logic: if selectedTargets matches this job's targets
      final isSelected =
          selectedTargets != null &&
          selectedTargets!.length == job.targets.length &&
          selectedTargets!.every((t) => job.targets.contains(t));

      for (final target in job.targets) {
        final status = searchController.status[target] ?? SearchStatus.stopped;
        if (status == SearchStatus.running) isRunning = true;
        if (status == SearchStatus.error) isError = true;

        final prog = searchController.progress[target];
        if (prog != null) {
          totalScanned += prog.scanned;
          totalCount += prog.total;
          hasTotal = true;
        }

        totalMatches += searchController.getMessagesFor(target).length;
      }

      StepStatus jobStatus = StepStatus.completed;
      if (isRunning) {
        jobStatus = StepStatus.running;
      } else if (isError) {
        jobStatus = StepStatus.error;
      }

      SearchProgress? jobProgress = hasTotal
          ? SearchProgress(totalScanned, totalCount)
          : null;

      final titleText = job.targets.length == 1
          ? job.targets.first.topic.name
          : "${job.targets.length} Topics";
      final subtitleText = job.targets.length == 1
          ? "${job.targets.first.profile.name} • ${job.targets.first.filterTerm ?? 'All'} • ${_getStrategyText(job.targets.first)}"
          : "${job.targets.first.profile.name} • ${job.targets.first.filterTerm ?? 'All'}";

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onSelectTargets(job.targets),
            child: TopicProgressTile(
              topic: titleText,
              status: jobStatus,
              progress: jobProgress,
              matchCount: totalMatches,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4.0,
              ),
              extraSubtitle: Text(
                subtitleText,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isRunning)
                    IconButton(
                      icon: const Icon(
                        Icons.stop_circle_outlined,
                        color: Colors.orange,
                        size: 20,
                      ),
                      onPressed: () {
                        for (final target in job.targets) {
                          searchController.stopTarget(target);
                        }
                      },
                      tooltip: "Stop Stream",
                    )
                  else
                    IconButton(
                      icon: const Icon(
                        Icons.play_circle_outline,
                        color: Colors.green,
                        size: 20,
                      ),
                      onPressed: () {
                        for (final target in job.targets) {
                          searchController.addTarget(
                            target,
                          ); // This implicitly restarts if stopped
                        }
                      },
                      tooltip: "Restart Stream",
                    ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      size: 18,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    onPressed: () {
                      if (isSelected) {
                        onSelectTargets(null);
                      }
                      for (final target in job.targets) {
                        searchController.removeTarget(target);
                      }
                    },
                    tooltip: "Remove Stream",
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _getStrategyText(SearchTarget target) {
    if (target.startTimestamp != null) {
      return "Using Timestamp";
    }
    if (target.startOffset != null) {
      return "Offset: ${target.startOffset}";
    }
    return "Latest";
  }
}
