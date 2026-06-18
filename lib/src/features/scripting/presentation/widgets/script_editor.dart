import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_step_editor.dart';
import 'package:uuid/uuid.dart';

class _VariableUsageInfo {
  final String name;
  final ScriptVariableType type;
  final String source;
  final List<String> usedInSteps;
  final bool isGlobal;
  final ScriptVariable? originalVar;

  _VariableUsageInfo({
    required this.name,
    required this.type,
    required this.source,
    required this.usedInSteps,
    required this.isGlobal,
    this.originalVar,
  });
}

class ScriptEditor extends StatefulWidget {
  final Script script;
  final Function(Script) onSave;

  const ScriptEditor({super.key, required this.script, required this.onSave});

  @override
  State<ScriptEditor> createState() => _ScriptEditorState();
}

class _ScriptEditorState extends State<ScriptEditor> {
  late TextEditingController _nameController;
  late TextEditingController _concurrencyController;
  late TextEditingController _variableController;
  ScriptVariableType _newVariableType = ScriptVariableType.string;

  late List<ScriptVariable> _variables;
  late List<ScriptStep> _steps;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.script.name);
    _concurrencyController = TextEditingController(
      text: widget.script.concurrencyLimit.toString(),
    );
    _variableController = TextEditingController();

    _variables = List.from(widget.script.variables);
    _steps = List.from(widget.script.steps);
  }

  @override
  void didUpdateWidget(covariant ScriptEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.script != widget.script) {
      if (_nameController.text != widget.script.name) {
        _nameController.text = widget.script.name;
      }
      if (_concurrencyController.text !=
          widget.script.concurrencyLimit.toString()) {
        _concurrencyController.text = widget.script.concurrencyLimit.toString();
      }

      _variables = List.from(widget.script.variables);
      _steps = List.from(widget.script.steps);
      setState(() {});
    }
  }

  void _save() {
    final updated = widget.script.copyWith(
      name: _nameController.text,
      concurrencyLimit: int.tryParse(_concurrencyController.text) ?? 2,
      outputDirectory: widget.script.outputDirectory,
      variables: _variables,
      steps: _steps,
    );
    widget.onSave(updated);
  }

  List<ScriptVariable> _getVariablesForStep(int stepIndex) {
    final allVars = <ScriptVariable>[..._variables];
    final existingNames = _variables.map((v) => v.name).toSet();

    // If stepIndex is naturally out of bounds (e.g. adding new step), uses all steps
    final limit = stepIndex.clamp(0, _steps.length);

    for (int i = 0; i < limit; i++) {
      for (final extraction in _steps[i].extractions) {
        if (extraction.variableName.isNotEmpty &&
            !existingNames.contains(extraction.variableName)) {
          allVars.add(
            ScriptVariable(
              name: extraction.variableName,
              type: ScriptVariableType.string,
            ),
          );
          existingNames.add(extraction.variableName);
        }
      }
    }
    return allVars;
  }

  List<_VariableUsageInfo> _analyzeVariables() {
    final usageList = _collectVariables();
    _calculateVariableUsages(usageList);
    return usageList;
  }

  List<_VariableUsageInfo> _collectVariables() {
    final usageList = <_VariableUsageInfo>[];
    final globalNames = _variables.map((v) => v.name).toSet();

    // 1. Add Global Variables
    for (final v in _variables) {
      usageList.add(
        _VariableUsageInfo(
          name: v.name,
          type: v.type,
          source: "Global",
          usedInSteps: [],
          isGlobal: true,
          originalVar: v,
        ),
      );
    }

    // 2. Add Extracted Variables
    for (int i = 0; i < _steps.length; i++) {
      final step = _steps[i];
      for (final extraction in step.extractions) {
        if (extraction.variableName.isNotEmpty &&
            !globalNames.contains(extraction.variableName)) {
          if (!usageList.any((u) => u.name == extraction.variableName)) {
            usageList.add(
              _VariableUsageInfo(
                name: extraction.variableName,
                type: ScriptVariableType.string,
                source: "Step ${i + 1}: ${step.name}",
                usedInSteps: [],
                isGlobal: false,
              ),
            );
          }
        }
      }
    }
    return usageList;
  }

  void _calculateVariableUsages(List<_VariableUsageInfo> usageList) {
    for (final usage in usageList) {
      final pattern = "{{${usage.name}}}";
      for (int i = 0; i < _steps.length; i++) {
        final step = _steps[i];
        bool used = false;

        final fields = [
          step.filterTemplate,
          step.startOffset,
          step.startTimestamp,
          step.startPartition,
          step.endOffset,
          step.endTimestamp,
          step.maxResults,
        ];

        for (final f in fields) {
          if (f != null && f.contains(pattern)) {
            used = true;
            break;
          }
        }

        if (used) {
          usage.usedInSteps.add("Step ${i + 1}");
        }
      }
    }
  }

  Map<String, List<String>> _getStepInfo(int stepIndex, ScriptStep step) {
    final extracted = <String>[];
    final used = <String>[];

    // Extracted
    for (final extraction in step.extractions) {
      if (extraction.variableName.isNotEmpty) {
        extracted.add(extraction.variableName);
      }
    }

    // Used
    // We need to check patterns for ALL variables (Global + Extracted from previous steps)
    // But efficiently, we can just check patterns present in the step against known variables.
    // Or simpler: Just regex match {{([a-zA-Z0-9_]+)}} in the step fields.

    final pattern = RegExp(r"\{\{([a-zA-Z0-9_]+)\}\}");
    final fields = [
      step.filterTemplate,
      step.startOffset,
      step.startTimestamp,
      step.startPartition,
      step.endOffset,
      step.endTimestamp,
      step.maxResults,
    ];

    for (final f in fields) {
      if (f != null) {
        final matches = pattern.allMatches(f);
        for (final m in matches) {
          if (m.groupCount >= 1) {
            used.add(m.group(1)!);
          }
        }
      }
    }

    return {
      "extracted": extracted,
      "used": used.toSet().toList(), // deduplicate
    };
  }

  void _addStep() {
    // Open step editor with new step
    ScriptStep newStep;
    if (_steps.isNotEmpty) {
      final last = _steps.last;
      newStep = ScriptStep(
        id: const Uuid().v4(),
        name: "Step ${_steps.length + 1}",
        clusterName: last.clusterName,
        topicNames: [],
        startStrategy: last.startStrategy,
        startOffset: last.startOffset,
        startTimestamp: last.startTimestamp,
        startPartition: last.startPartition,
        fastTraceEnabled: last.fastTraceEnabled,
        endStrategy: last.endStrategy,
        endOffset: last.endOffset,
        endTimestamp: last.endTimestamp,
        maxResults: last.maxResults,
        scope: last.scope,
      );
    } else {
      newStep = ScriptStep(
        id: const Uuid().v4(),
        name: "Step ${_steps.length + 1}",
        clusterName: "",
        topicNames: [],
      );
    }

    showDialog<ScriptStep>(
      context: context,
      builder: (c) => Dialog(
        child: SizedBox(
          width: 600,
          child: ScriptStepEditor(
            step: newStep,
            variables: _getVariablesForStep(_steps.length),
            onSave: (s) {
              Navigator.pop(context, s);
            },
          ),
        ),
      ),
    ).then((val) {
      if (val != null) {
        setState(() {
          _steps.add(val);
        });
        _save();
      }
    });
  }

  void _editStep(int index) {
    final oldExtractions = _steps[index].extractions.toList();

    showDialog<ScriptStep>(
      context: context,
      builder: (c) => Dialog(
        child: SizedBox(
          width: 600,
          child: ScriptStepEditor(
            step: _steps[index],
            variables: _getVariablesForStep(index),
            onSave: (s) {
              Navigator.pop(context, s);
            },
          ),
        ),
      ),
    ).then((val) {
      if (val != null) {
        setState(() {
          _steps[index] = val;

          // Check for renamed extractions
          if (oldExtractions.length == val.extractions.length) {
            for (int i = 0; i < oldExtractions.length; i++) {
              final oldName = oldExtractions[i].variableName;
              final newName = val.extractions[i].variableName;
              if (oldName != newName &&
                  oldName.isNotEmpty &&
                  newName.isNotEmpty) {
                // Update all downstream steps (and the current one if it somehow references itself)
                for (int j = 0; j < _steps.length; j++) {
                  _steps[j] = _steps[j].replaceVariable(oldName, newName);
                }
              }
            }
          }
        });
        _save();
      }
    });
  }

  void _editVariable(ScriptVariable variable) {
    ScriptVariableType selectedType = variable.type;
    final nameCtrl = TextEditingController(text: variable.name);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Edit Variable"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: "Name"),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<ScriptVariableType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: "Type"),
                  items: ScriptVariableType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (val) => setDialogState(() => selectedType = val!),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () {
                  final index = _variables.indexOf(variable);
                  if (index != -1) {
                    final oldName = variable.name;
                    final newName = nameCtrl.text;
                    setState(() {
                      _variables[index] = variable.copyWith(
                        name: newName,
                        type: selectedType,
                      );
                      if (oldName != newName &&
                          oldName.isNotEmpty &&
                          newName.isNotEmpty) {
                        for (int i = 0; i < _steps.length; i++) {
                          _steps[i] = _steps[i].replaceVariable(
                            oldName,
                            newName,
                          );
                        }
                      }
                    });
                    _save();
                  }
                  Navigator.pop(context);
                },
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(context),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingsCard(context),
                const SizedBox(height: 16),
                _buildVariablesCard(context),
                const SizedBox(height: 16),
                _buildStepsList(context),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Script Name",
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _save(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Settings", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: _concurrencyController,
                    decoration: const InputDecoration(
                      labelText: "Concurrency Limit",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _save(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVariablesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Variables", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildVariablesTable(),
            const SizedBox(height: 8),
            _buildAddVariableRow(),
          ],
        ),
      ),
    );
  }

  Widget _buildVariablesTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: const [
          DataColumn(label: Text("Name")),
          DataColumn(label: Text("Type")),
          DataColumn(label: Text("Source")),
          DataColumn(label: Text("Used In")),
          DataColumn(label: Text("Actions")),
        ],
        rows: _analyzeVariables().map((info) {
          return DataRow(
            cells: [
              DataCell(
                Text(
                  info.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(Text(info.type.name)),
              DataCell(Text(info.source)),
              DataCell(
                Text(
                  info.usedInSteps.isEmpty ? "-" : info.usedInSteps.join(", "),
                ),
              ),
              DataCell(
                info.isGlobal
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18),
                            onPressed: () => _editVariable(info.originalVar!),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              setState(
                                () => _variables.remove(info.originalVar),
                              );
                              _save();
                            },
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAddVariableRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _variableController,
            decoration: const InputDecoration(
              labelText: "New Variable Name",
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onSubmitted: _addNewVariable,
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<ScriptVariableType>(
          value: _newVariableType,
          onChanged: (val) {
            if (val != null) {
              setState(() => _newVariableType = val);
            }
          },
          items: ScriptVariableType.values
              .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
              .toList(),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: () => _addNewVariable(_variableController.text),
        ),
      ],
    );
  }

  void _addNewVariable(String val) {
    if (val.isNotEmpty && !_variables.any((v) => v.name == val)) {
      setState(
        () => _variables.add(ScriptVariable(name: val, type: _newVariableType)),
      );
      _variableController.clear();
      _save();
    }
  }

  Widget _buildStepsList(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Steps", style: Theme.of(context).textTheme.titleLarge),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("Add Step"),
              onPressed: _addStep,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildStepsListView(),
      ],
    );
  }

  Widget _buildStepsListView() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: true,
      itemCount: _steps.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _steps.removeAt(oldIndex);
          _steps.insert(newIndex, item);
        });
        _save();
      },
      itemBuilder: (context, index) {
        final step = _steps[index];
        return Card(
          key: ValueKey(step.id),
          child: ListTile(
            leading: CircleAvatar(child: Text("${index + 1}")),
            title: Text(step.name.isEmpty ? "Unnamed Step" : step.name),
            subtitle: _buildStepSubtitle(index, step),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editStep(index),
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() => _steps.removeAt(index));
                    _save();
                  },
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(Icons.drag_handle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStepSubtitle(int index, ScriptStep step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("${step.clusterName} / ${step.topicNames.join(', ')}"),
        const SizedBox(height: 4),
        Builder(
          builder: (context) {
            final info = _getStepInfo(index, step);
            final extracted = info["extracted"]!;
            final used = info["used"]!;

            if (extracted.isEmpty && used.isEmpty) {
              return const SizedBox.shrink();
            }

            return Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (extracted.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.download, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        "Extracted: ${extracted.join(', ')}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                if (used.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.input, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        "Used: ${used.join(', ')}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
