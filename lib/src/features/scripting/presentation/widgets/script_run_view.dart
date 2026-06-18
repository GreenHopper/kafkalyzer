import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/controllers/script_runner.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/controllers/cluster_list_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/cluster/presentation/widgets/cluster_dropdown.dart';
import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';
import 'package:kafkalyzer/src/ui/script_progress_widget.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_run.dart';

class ScriptRunView extends StatefulWidget {
  final Script script;
  final Map<String, String>? initialValues;
  final void Function(ScriptRun)? onRunFinished;

  const ScriptRunView({
    super.key,
    required this.script,
    this.initialValues,
    this.onRunFinished,
  });

  @override
  State<ScriptRunView> createState() => _ScriptRunViewState();
}

class _ScriptRunViewState extends State<ScriptRunView> {
  final Map<String, TextEditingController> _controllers = {};
  bool _isMonitoring = false;
  ClusterProfile? _selectedCluster;

  @override
  void initState() {
    super.initState();
    for (var v in widget.script.variables) {
      final initialVal = widget.initialValues?[v.name] ?? "";
      _controllers[v.name] = TextEditingController(text: initialVal);
    }
    // Default cluster selection logic
    final clusters = getIt<ClusterListController>().clusters;
    if (clusters.isNotEmpty) {
      // Try to find the one used in the first step as default, or just the first one
      final defaultName = widget.script.steps.isNotEmpty
          ? widget.script.steps.first.clusterName
          : null;
      _selectedCluster = clusters.cast<ClusterProfile?>().firstWhere(
        (c) => c?.name == defaultName,
        orElse: () => clusters.first,
      );
    }

    // Check if valid run is already in progress
    final runner = getIt<ScriptRunner>();
    if (runner.isRunning &&
        runner.currentRun?.scriptName == widget.script.name) {
      _isMonitoring = true;
      // Restore values
      if (runner.currentRun?.parameters != null) {
        for (var entry in runner.currentRun!.parameters.entries) {
          if (_controllers.containsKey(entry.key)) {
            _controllers[entry.key]!.text = entry.value;
          }
        }
      }
      // Restore cluster
      if (runner.currentRun?.clusterName != null) {
        try {
          _selectedCluster = clusters.cast<ClusterProfile?>().firstWhere(
            (c) => c?.name == runner.currentRun!.clusterName,
          );
        } catch (_) {}
      }
    }

    runner.addListener(_onRunnerChanged);
  }

  @override
  void dispose() {
    getIt<ScriptRunner>().removeListener(_onRunnerChanged);
    for (var c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onRunnerChanged() {
    final runner = getIt<ScriptRunner>();
    if (_isMonitoring && !runner.isRunning) {
      // Run finished
      if (mounted &&
          widget.onRunFinished != null &&
          runner.currentRun != null &&
          runner.currentRun!.scriptName == widget.script.name) {
        widget.onRunFinished!(runner.currentRun!);
      }
    }
  }

  Future<void> _runScript() async {
    final values = <String, String>{};
    for (var entry in _controllers.entries) {
      values[entry.key] = entry.value.text;
    }

    setState(() {
      _isMonitoring = true;
    });

    final run = await getIt<ScriptRunner>().runScript(
      widget.script,
      values,
      overrideCluster: _selectedCluster,
    );

    if (run != null && widget.onRunFinished != null) {
      widget.onRunFinished!(run);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isMonitoring) {
      return _buildMonitor();
    }
    return _buildForm();
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Configuration",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              FilledButton.icon(
                onPressed: _runScript,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Run"),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cluster Selection
          _buildClusterSelection(),
          const SizedBox(height: 16),

          Expanded(child: SingleChildScrollView(child: _buildVariableInputs())),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildClusterSelection() {
    final clusters = getIt<ClusterListController>().clusters;
    if (clusters.isEmpty) return const SizedBox.shrink();

    return ClusterDropdown(
      value: _selectedCluster,
      labelText: "Target Cluster",
      onChanged: (v) {
        setState(() => _selectedCluster = v);
      },
    );
  }

  Widget _buildVariableInputs() {
    return Column(
      children: [
        if (widget.script.variables.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("No variables required."),
          ),

        ...widget.script.variables.map(
          (v) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: v.type == ScriptVariableType.timestamp
                ? TimestampPickerField(
                    controller: _controllers[v.name]!,
                    label: "${v.name} (${v.type.name})",
                    showInlineChips: true,
                  )
                : TextField(
                    controller: _controllers[v.name],
                    decoration: InputDecoration(
                      labelText: "${v.name} (${v.type.name})",
                      border: const OutlineInputBorder(),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonitor() {
    final runner = getIt<ScriptRunner>();
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: ScriptProgressWidget(
                script: widget.script,
                runner: runner,
                title: "Execution Progress",
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: runner,
            builder: (context, _) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (runner.isRunning)
                    OutlinedButton(
                      onPressed: () {
                        runner.cancelScript();
                      },
                      child: const Text(
                        "Stop",
                        style: TextStyle(color: Colors.red),
                      ),
                    )
                  else
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _isMonitoring = false;
                        });
                      },
                      child: const Text("New Run"),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
