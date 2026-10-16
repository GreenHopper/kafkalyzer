import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class ViewModeSwitcher extends StatelessWidget {
  final String activeView;
  final ValueChanged<String> onViewChanged;

  final bool showSchemaView;

  const ViewModeSwitcher({
    super.key,
    required this.activeView,
    required this.onViewChanged,
    this.showSchemaView = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ToggleButtons(
      isSelected: [
        activeView == 'table',
        activeView == 'timeline',
        activeView == 'diff',
        if (showSchemaView) activeView == 'schema',
      ],
      onPressed: (index) {
        String newView;
        if (index == 0) {
          newView = 'table';
        } else if (index == 1) {
          newView = 'timeline';
        } else if (index == 2) {
          newView = 'diff';
        } else if (showSchemaView && index == 3) {
          newView = 'schema';
        } else {
          return;
        }
        onViewChanged(newView);
      },
      borderRadius: BorderRadius.circular(8),
      constraints: const BoxConstraints(minHeight: 32),
      children: [
        _buildSegment(
          context,
          icon: Icons.table_chart,
          label: l10n?.viewModeTable ?? "Table",
          tooltip: l10n?.viewModeTableTooltip ?? "Table View",
        ),
        _buildSegment(
          context,
          icon: Icons.view_list,
          label: l10n?.viewModeTimeline ?? "Timeline",
          tooltip: l10n?.viewModeTimelineTooltip ?? "Timeline View",
        ),
        _buildSegment(
          context,
          icon: Icons.difference,
          label: l10n?.viewModeDiff ?? "Diff",
          tooltip: l10n?.viewModeDiffTooltip ?? "Diff View",
        ),
        if (showSchemaView)
          _buildSegment(
            context,
            icon: Icons.data_object,
            label: l10n?.viewModeSchema ?? "Schema",
            tooltip: l10n?.viewModeSchemaTooltip ?? "Schema View",
          ),
      ],
    );
  }

  Widget _buildSegment(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
