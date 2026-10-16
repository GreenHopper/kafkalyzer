import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWidescreen = constraints.maxWidth >= 900;
        if (isWidescreen) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: _buildParametersCard(),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: _buildPipelinePreview(),
                ),
              ],
            ),
          );
        } else {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildParametersCard(),
                const SizedBox(height: 24),
                _buildPipelinePreview(),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildParametersCard() {
    final l10n = AppLocalizations.of(context);
    final stepsCount = widget.script.steps.length;
    final runButtonText = l10n?.runScriptWithSteps(stepsCount) ??
        "Run Script ($stepsCount ${stepsCount == 1 ? 'step' : 'steps'})";

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n?.parametersAndExecution ?? "Parameters & Execution",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildClusterSelection(),
            const SizedBox(height: 16),
            _buildVariableInputs(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _runScript,
              icon: const Icon(Icons.play_arrow),
              label: Text(runButtonText),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClusterSelection() {
    final l10n = AppLocalizations.of(context);
    final clusters = getIt<ClusterListController>().clusters;
    if (clusters.isEmpty) return const SizedBox.shrink();

    return ClusterDropdown(
      value: _selectedCluster,
      labelText: l10n?.targetCluster ?? "Target Cluster",
      onChanged: (v) {
        setState(() => _selectedCluster = v);
      },
    );
  }

  Widget _buildVariableInputs() {
    final l10n = AppLocalizations.of(context);
    if (widget.script.variables.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          l10n?.noVariablesRequired ?? "No variables required.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Column(
      children: widget.script.variables.map((v) {
        if (v.type == ScriptVariableType.timestamp) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TimestampPickerField(
              controller: _controllers[v.name]!,
              label: v.name,
              showInlineChips: true,
            ),
          );
        }

        final isNumeric = v.type == ScriptVariableType.numeric;
        final typeLabel = isNumeric
            ? (l10n?.variableTypeNumeric ?? "Numeric")
            : (l10n?.variableTypeText ?? "Text");
        final icon = isNumeric ? Icons.numbers : Icons.short_text;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: TextField(
            controller: _controllers[v.name],
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            decoration: InputDecoration(
              labelText: v.name,
              prefixIcon: Icon(icon, size: 20),
              suffix: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPipelinePreview() {
    final l10n = AppLocalizations.of(context);
    final steps = widget.script.steps;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n?.pipelinePreview ?? "Pipeline Preview",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n?.pipelineStepsCount(steps.length) ??
                        "${steps.length} Steps",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (steps.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(
                  child: Text(
                    l10n?.noStepsInPipeline ??
                        "No execution steps configured. Use the Edit tab to add steps.",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: steps.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildPipelineStepItem(index, steps[index]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineStepItem(int index, ScriptStep step) {
    final l10n = AppLocalizations.of(context);
    final stepTitle = step.name.isNotEmpty
        ? step.name
        : (l10n?.stepNumber(index + 1) ?? "Step ${index + 1}");

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.4),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stepTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          if (step.topicNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: step.topicNames.map((topic) {
                return Chip(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  label: Text(topic, style: const TextStyle(fontSize: 12)),
                  backgroundColor: Theme.of(context).colorScheme.surface,
                );
              }).toList(),
            ),
          ],
          if (step.filterTemplate != null &&
              step.filterTemplate!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      "${l10n?.filter ?? 'Filter'}: ${step.filterTemplate!}",
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (step.extractions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: step.extractions
                  .where((e) => e.variableName.isNotEmpty)
                  .map((e) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "${l10n?.extractedVariables ?? 'Extracted'}: ${e.variableName}",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ],
      ),
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
                overrideClusterName: _selectedCluster?.name,
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
