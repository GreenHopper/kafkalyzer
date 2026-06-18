import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_controller.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';

class ScriptSelector extends StatelessWidget {
  final String? selectedScriptName;
  final ValueChanged<String?> onSelected;
  final String? errorText;
  final bool Function(Script)? filter;

  const ScriptSelector({
    super.key,
    this.selectedScriptName,
    required this.onSelected,
    this.errorText,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final scriptController = getIt<ScriptController>();

    return ListenableBuilder(
      listenable: scriptController,
      builder: (context, _) {
        var scripts = scriptController.scripts;
        if (filter != null) {
          scripts = scripts.where(filter!).toList();
        }

        String? currentValue = selectedScriptName;

        // Ensure the current value exists in the scripts list
        if (currentValue != null &&
            currentValue.isNotEmpty &&
            !scripts.any((s) => s.name == currentValue)) {
          // If not found, try to find "PMXCOR" or take the first one
          final fallback = scripts.any((s) => s.name == "PMXCOR")
              ? "PMXCOR"
              : (scripts.isNotEmpty ? scripts.first.name : "");

          if (fallback.isNotEmpty) {
            currentValue = fallback;
            // Notify parent about the fallback
            WidgetsBinding.instance.addPostFrameCallback((_) {
              onSelected(fallback);
            });
          } else {
            currentValue = null;
          }
        } else if ((currentValue == null || currentValue.isEmpty) &&
            scripts.isNotEmpty) {
          currentValue = scripts.first.name;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSelected(currentValue);
          });
        }

        if (scripts.isEmpty) {
          return const Text("No scripts available");
        }

        return DropdownButtonFormField<String>(
          initialValue: currentValue,
          decoration: InputDecoration(
            labelText: "Script Name",
            border: const OutlineInputBorder(),
            isDense: true,
            errorText: errorText,
          ),
          items: scripts.map((s) {
            return DropdownMenuItem<String>(value: s.name, child: Text(s.name));
          }).toList(),
          onChanged: onSelected,
        );
      },
    );
  }
}
