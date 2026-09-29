import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:material_ui/material_ui.dart';

class ScriptRunHeader extends StatelessWidget {
  final ScriptRun? run;
  final String timelineMode;
  final ValueChanged<String> onTimelineModeChanged;
  final VoidCallback onBack;
  final bool isSidebarVisible;
  final VoidCallback? onToggleSidebar;

  const ScriptRunHeader({
    super.key,
    required this.run,
    required this.timelineMode,
    required this.onTimelineModeChanged,
    required this.onBack,
    this.isSidebarVisible = true,
    this.onToggleSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
              if (onToggleSidebar != null)
                IconButton(
                  key: const Key('script_run_toggle_sidebar'),
                  icon: Icon(
                    Icons.view_sidebar_outlined,
                    color: isSidebarVisible
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: l10n.toggleRunOverview,
                  isSelected: isSidebarVisible,
                  onPressed: onToggleSidebar,
                ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.runDetails,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    run != null
                        ? DateFormatUtils.formatDateTime(
                            context,
                            DateTime.fromMillisecondsSinceEpoch(run!.timestamp),
                          )
                        : "Running...",
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 24),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'topic', label: Text(l10n.byTopic)),
                  ButtonSegment(
                    value: 'chronological',
                    label: Text(l10n.chronological),
                  ),
                  ButtonSegment(value: 'step', label: Text(l10n.byStep)),
                ],
                selected: {timelineMode},
                onSelectionChanged: (Set<String> newSelection) {
                  onTimelineModeChanged(newSelection.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
