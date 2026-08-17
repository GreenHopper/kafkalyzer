import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:group_button/group_button.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/start_condition_configuration.dart';
import 'package:kafkalyzer/src/features/search/presentation/widgets/end_condition_configuration.dart';

class SearchStreamConfiguration extends StatelessWidget {
  // Filter Options
  final FilterType filterType;
  final ValueChanged<FilterType> onFilterTypeChanged;
  final SearchScope searchScope;
  final ValueChanged<SearchScope> onSearchScopeChanged;
  final Widget? filterInput;

  // Fast Trace & Limit
  final bool fastTraceEnabled;
  final ValueChanged<bool> onFastTraceChanged;
  final bool limitResults;
  final ValueChanged<bool> onLimitResultsChanged;
  final TextEditingController maxResultsController;
  final TextEditingController partitionController;

  // Start Strategy
  final MultiSearchStartStrategy startStrategy;
  final ValueChanged<MultiSearchStartStrategy> onStartStrategyChanged;
  final TextEditingController startOffsetController;
  final TextEditingController startTimestampController;

  // Stop Strategy
  final MultiSearchEndStrategy endStrategy;
  final ValueChanged<MultiSearchEndStrategy> onEndStrategyChanged;
  final TextEditingController endOffsetController;
  final TextEditingController endTimestampController;

  final Widget? Function(TextEditingController)? variableSuffixBuilder;

  const SearchStreamConfiguration({
    super.key,
    required this.filterType,
    required this.onFilterTypeChanged,
    required this.searchScope,
    required this.onSearchScopeChanged,
    this.filterInput,
    required this.fastTraceEnabled,
    required this.onFastTraceChanged,
    required this.limitResults,
    required this.onLimitResultsChanged,
    required this.maxResultsController,
    required this.partitionController,
    required this.startStrategy,
    required this.onStartStrategyChanged,
    required this.startOffsetController,
    required this.startTimestampController,
    required this.endStrategy,
    required this.onEndStrategyChanged,
    required this.endOffsetController,
    required this.endTimestampController,
    this.variableSuffixBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (filterInput != null) ...[filterInput!, const SizedBox(height: 12)],
        _buildFilterOptions(context, l10n),
        const SizedBox(height: 12),
        _buildFastTraceToggle(l10n),
        const SizedBox(height: 8),
        _buildLimitAndPartition(l10n),
        const SizedBox(height: 16),
        _buildConditions(),
      ],
    );
  }

  Widget _buildFilterOptions(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.type, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) =>
              onFilterTypeChanged(FilterType.values[i]),
          buttons: [l10n.contains, l10n.regex, l10n.exact],
          controller: GroupButtonController(selectedIndex: filterType.index),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 28,
            selectedColor: Theme.of(context).colorScheme.secondaryContainer,
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontSize: 11,
            ),
            unselectedColor: Theme.of(context).colorScheme.surface,
            unselectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
        const SizedBox(height: 12),
        Text(l10n.scope, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 4),
        GroupButton(
          isRadio: true,
          onSelected: (val, i, selected) =>
              onSearchScopeChanged(SearchScope.values[i]),
          buttons: [l10n.key, l10n.value, l10n.both],
          controller: GroupButtonController(selectedIndex: searchScope.index),
          options: GroupButtonOptions(
            borderRadius: BorderRadius.circular(8),
            buttonHeight: 28,
            selectedColor: Theme.of(context).colorScheme.tertiaryContainer,
            selectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onTertiaryContainer,
              fontSize: 11,
            ),
            unselectedColor: Theme.of(context).colorScheme.surface,
            unselectedTextStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
            ),
            mainGroupAlignment: MainGroupAlignment.start,
          ),
        ),
      ],
    );
  }

  Widget _buildFastTraceToggle(AppLocalizations l10n) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l10n.fastTrace, style: const TextStyle(fontSize: 13)),
        value: fastTraceEnabled,
        onChanged: onFastTraceChanged,
        dense: true,
      ),
    );
  }

  Widget _buildLimitAndPartition(AppLocalizations l10n) {
    return Row(
      children: [
        SizedBox(
          width: 140,
          child: TextField(
            controller: maxResultsController,
            enabled: limitResults,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.limit,
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: limitResults,
                  onChanged: (v) => onLimitResultsChanged(v!),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              suffixIcon: variableSuffixBuilder?.call(maxResultsController),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: partitionController,
            enabled: !fastTraceEnabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.partitionOptional,
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: variableSuffixBuilder?.call(partitionController),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConditions() {
    return Column(
      children: [
        StartConditionConfiguration(
          startStrategy: startStrategy,
          onStartStrategyChanged: onStartStrategyChanged,
          startOffsetController: startOffsetController,
          startTimestampController: startTimestampController,
          variableSuffixBuilder: variableSuffixBuilder,
        ),
        const SizedBox(height: 16),
        EndConditionConfiguration(
          endStrategy: endStrategy,
          onEndStrategyChanged: onEndStrategyChanged,
          endOffsetController: endOffsetController,
          endTimestampController: endTimestampController,
          variableSuffixBuilder: variableSuffixBuilder,
        ),
      ],
    );
  }
}
