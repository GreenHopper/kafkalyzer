import 'package:material_ui/material_ui.dart';
import 'package:group_button/group_button.dart';
import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class StartConditionConfiguration extends StatelessWidget {
  final MultiSearchStartStrategy startStrategy;
  final ValueChanged<MultiSearchStartStrategy> onStartStrategyChanged;
  final TextEditingController startOffsetController;
  final TextEditingController startTimestampController;
  final Widget? Function(TextEditingController)? variableSuffixBuilder;
  final String? selectedTimestampLabel;
  final ValueChanged<String?>? onTimestampLabelChanged;

  const StartConditionConfiguration({
    super.key,
    required this.startStrategy,
    required this.onStartStrategyChanged,
    required this.startOffsetController,
    required this.startTimestampController,
    this.variableSuffixBuilder,
    this.selectedTimestampLabel,
    this.onTimestampLabelChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.startCondition,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStrategySelector(l10n, context),
              const SizedBox(height: 8),
              Text(
                _getStrategyDescription(l10n),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                  fontSize: 11,
                ),
              ),
              _buildOffsetOrTimestampFields(l10n),
            ],
          ),
        ),
      ],
    );
  }

  String _getStrategyDescription(AppLocalizations l10n) {
    switch (startStrategy) {
      case MultiSearchStartStrategy.latest:
        return l10n.startConditionLatestTooltip;
      case MultiSearchStartStrategy.earliest:
        return l10n.startConditionEarliestTooltip;
      case MultiSearchStartStrategy.customOffset:
        return l10n.startConditionOffsetTooltip;
      case MultiSearchStartStrategy.customTimestamp:
        return l10n.startConditionTimestampTooltip;
    }
  }

  Widget _buildStrategySelector(AppLocalizations l10n, BuildContext context) {
    return GroupButton(
      isRadio: true,
      onSelected: (val, i, selected) =>
          onStartStrategyChanged(MultiSearchStartStrategy.values[i]),
      buttons: [l10n.latest, l10n.earliest, l10n.offset, l10n.timestamp],
      controller: GroupButtonController(selectedIndex: startStrategy.index),
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
        spacing: 8,
        runSpacing: 8,
      ),
    );
  }

  Widget _buildOffsetOrTimestampFields(AppLocalizations l10n) {
    if (startStrategy == MultiSearchStartStrategy.customOffset) {
      return Column(
        children: [
          const SizedBox(height: 16),
          TextField(
            controller: startOffsetController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.startOffset,
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: variableSuffixBuilder?.call(startOffsetController),
            ),
          ),
        ],
      );
    }
    if (startStrategy == MultiSearchStartStrategy.customTimestamp) {
      return Column(
        children: [
          const SizedBox(height: 16),
          TimestampPickerField(
            controller: startTimestampController,
            label: l10n.startTimestamp,
            showInlineChips: true,
            selectedLabel: selectedTimestampLabel,
            onLabelChanged: onTimestampLabelChanged,
            suffixIcon: variableSuffixBuilder?.call(startTimestampController),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
