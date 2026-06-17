import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/features/scripting/presentation/widgets/script_selector.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class SearchDiscoverySidebar extends StatelessWidget {
  final String? selectedCluster;
  final ValueChanged<String?> onClusterChanged;
  final List<String> clusters;

  final String selectedScriptName;
  final ValueChanged<String?> onScriptSelected;
  final bool isScriptMissing;

  final TextEditingController idController;
  final bool idFilterActive;

  final bool limitEnabled;
  final ValueChanged<bool> onLimitEnabledChanged;
  final int maxResults;
  final ValueChanged<int> onMaxResultsChanged;

  final MultiSearchStartStrategy startStrategy;
  final ValueChanged<MultiSearchStartStrategy> onStartStrategyChanged;
  final TextEditingController startOffsetController;
  final TextEditingController startTimestampController;
  final String? startPresetLabel;
  final ValueChanged<String?> onStartPresetLabelChanged;

  final MultiSearchEndStrategy endStrategy;
  final ValueChanged<MultiSearchEndStrategy> onEndStrategyChanged;
  final TextEditingController endOffsetController;
  final TextEditingController endTimestampController;

  final VoidCallback onLoad;
  final VoidCallback? onCancel;
  final bool isLoading;

  const SearchDiscoverySidebar({
    super.key,
    required this.selectedCluster,
    required this.onClusterChanged,
    required this.clusters,
    required this.selectedScriptName,
    required this.onScriptSelected,
    required this.isScriptMissing,
    required this.idController,
    required this.idFilterActive,
    required this.limitEnabled,
    required this.onLimitEnabledChanged,
    required this.maxResults,
    required this.onMaxResultsChanged,
    required this.startStrategy,
    required this.onStartStrategyChanged,
    required this.startOffsetController,
    required this.startTimestampController,
    required this.startPresetLabel,
    required this.onStartPresetLabelChanged,
    required this.endStrategy,
    required this.onEndStrategyChanged,
    required this.endOffsetController,
    required this.endTimestampController,
    required this.onLoad,
    this.onCancel,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildClusterSelection(l10n),
        const SizedBox(height: 16),
        _buildScriptSelector(l10n),
        const SizedBox(height: 16),
        _buildIdSearch(l10n),
        const SizedBox(height: 16),
        _buildLimitToggle(l10n),
        _buildMaxResults(l10n),
        const SizedBox(height: 16),
        _buildStartCondition(),
        const SizedBox(height: 16),
        _buildEndCondition(),
        const SizedBox(height: 24),
        _buildActionButton(context, l10n),
      ],
    );
  }

  Widget _buildClusterSelection(AppLocalizations l10n) {
    if (clusters.isEmpty) {
      return Text(l10n.noClustersAvailable);
    }
    return DropdownButtonFormField<String>(
      initialValue: selectedCluster,
      decoration: InputDecoration(labelText: l10n.cluster, border: const OutlineInputBorder(), isDense: true),
      items: clusters.map((c) => DropdownMenuItem<String>(value: c, child: Text(c))).toList(),
      onChanged: onClusterChanged,
    );
  }

  Widget _buildScriptSelector(AppLocalizations l10n) {
    return ScriptSelector(
      selectedScriptName: selectedScriptName,
      errorText: isScriptMissing ? l10n.scriptNotFound(selectedScriptName) : null,
      filter: idFilterActive ? (script) => script.variables.any((v) => v.name == 'id') : null,
      onSelected: onScriptSelected,
    );
  }

  Widget _buildIdSearch(AppLocalizations l10n) {
    return TextFormField(
      controller: idController,
      decoration: InputDecoration(
        labelText: l10n.searchById,
        hintText: "Optional",
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildLimitToggle(AppLocalizations l10n) {
    return Row(
      children: [
        Checkbox(value: limitEnabled, onChanged: (v) => onLimitEnabledChanged(v ?? true)),
        Expanded(child: Text(l10n.limitResults)),
      ],
    );
  }

  Widget _buildMaxResults(AppLocalizations l10n) {
    return TextFormField(
      initialValue: maxResults.toString(),
      enabled: limitEnabled,
      decoration: InputDecoration(labelText: l10n.maxResults, border: const OutlineInputBorder(), isDense: true),
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final val = int.tryParse(value);
        if (val != null) onMaxResultsChanged(val);
      },
    );
  }

  Widget _buildStartCondition() {
    return StartConditionConfiguration(
      startStrategy: startStrategy,
      onStartStrategyChanged: onStartStrategyChanged,
      startOffsetController: startOffsetController,
      startTimestampController: startTimestampController,
      selectedTimestampLabel: startPresetLabel,
      onTimestampLabelChanged: onStartPresetLabelChanged,
    );
  }

  Widget _buildEndCondition() {
    return EndConditionConfiguration(
      endStrategy: endStrategy,
      onEndStrategyChanged: onEndStrategyChanged,
      endOffsetController: endOffsetController,
      endTimestampController: endTimestampController,
    );
  }

  Widget _buildActionButton(BuildContext context, AppLocalizations l10n) {
    if (isLoading && onCancel != null) {
      return FilledButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.stop),
        label: Text(l10n.cancel), // Using default cancel translation, or we could add stop
        style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
    return FilledButton.icon(
      onPressed: isLoading ? null : onLoad,
      icon: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.refresh),
      label: Text(l10n.load),
    );
  }
}
