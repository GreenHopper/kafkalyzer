import 'package:flutter/material.dart';

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
      constraints: const BoxConstraints(minWidth: 40, minHeight: 36),
      children: [
        Tooltip(
          message: "Table View",
          child: Icon(Icons.table_chart, size: 20),
        ),
        Tooltip(
          message: "Timeline View",
          child: Icon(Icons.view_list, size: 20),
        ),
        Tooltip(message: "Diff View", child: Icon(Icons.difference, size: 20)),
        if (showSchemaView)
          Tooltip(
            message: "Schema View",
            child: Icon(Icons.data_object, size: 20),
          ),
      ],
    );
  }
}
