import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/message_search_bar.dart';
import 'package:kafkalyzer/src/ui/messages/widgets/view_mode_switcher.dart';

class ScriptRunHeader extends StatelessWidget {
  final ScriptRun? run;
  final String timelineMode;
  final String activeView;
  final String searchPhrase;
  final bool showNonMatches;
  final int matchCount;
  final ValueChanged<String> onTimelineModeChanged;
  final ValueChanged<String> onActiveViewChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<bool> onShowNonMatchesChanged;
  final VoidCallback onBack;

  const ScriptRunHeader({
    super.key,
    required this.run,
    required this.timelineMode,
    required this.activeView,
    required this.searchPhrase,
    required this.showNonMatches,
    required this.matchCount,
    required this.onTimelineModeChanged,
    required this.onActiveViewChanged,
    required this.onSearchChanged,
    required this.onShowNonMatchesChanged,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
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
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context)!.runDetails,
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
              // View Mode Toggles
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'topic',
                    label: Text(AppLocalizations.of(context)!.byTopic),
                  ),
                  ButtonSegment(
                    value: 'chronological',
                    label: Text(AppLocalizations.of(context)!.chronological),
                  ),
                  ButtonSegment(
                    value: 'step',
                    label: Text(AppLocalizations.of(context)!.byStep),
                  ),
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
              const SizedBox(width: 8),
              const SizedBox(width: 8),
              ViewModeSwitcher(
                activeView: activeView,
                onViewChanged: onActiveViewChanged,
              ),
            ],
          ),

          // Search
          MessageSearchBar(
            searchPhrase: searchPhrase,
            onSearchChanged: onSearchChanged,
            matchCount: matchCount,
            showNonMatches: showNonMatches,
            onShowNonMatchesChanged: onShowNonMatchesChanged,
          ),
        ],
      ),
    );
  }
}
