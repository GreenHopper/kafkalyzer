import 'package:flutter/material.dart';
import 'package:group_button/group_button.dart';
import 'package:kafkalyzer/src/ui/timestamp_picker_field.dart';
import 'package:kafkalyzer/src/features/search/presentation/controllers/multi_search_controller.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class EndConditionConfiguration extends StatelessWidget {
  final MultiSearchEndStrategy endStrategy;
  final ValueChanged<MultiSearchEndStrategy> onEndStrategyChanged;
  final TextEditingController endOffsetController;
  final TextEditingController endTimestampController;
  final Widget? Function(TextEditingController)? variableSuffixBuilder;

  const EndConditionConfiguration({
    super.key,
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
        Text(
          l10n.stopCondition,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
              GroupButton(
                isRadio: true,
                onSelected: (val, i, selected) => onEndStrategyChanged(MultiSearchEndStrategy.values[i]),
                buttons: [l10n.stream, l10n.end, l10n.offset, l10n.timestamp],
                controller: GroupButtonController(selectedIndex: endStrategy.index),
                options: GroupButtonOptions(
                  borderRadius: BorderRadius.circular(8),
                  buttonHeight: 28,
                  selectedColor: Theme.of(context).colorScheme.tertiaryContainer,
                  selectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontSize: 11),
                  unselectedColor: Theme.of(context).colorScheme.surface,
                  unselectedTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11),
                  mainGroupAlignment: MainGroupAlignment.start,
                  spacing: 8,
                  runSpacing: 8,
                ),
              ),
              if (endStrategy == MultiSearchEndStrategy.customOffset) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: endOffsetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.endOffset,
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: variableSuffixBuilder?.call(endOffsetController),
                  ),
                ),
              ],
              if (endStrategy == MultiSearchEndStrategy.customTimestamp) ...[
                const SizedBox(height: 16),
                TimestampPickerField(
                  controller: endTimestampController,
                  label: l10n.endTimestamp,
                  showInlineChips: true,
                  suffixIcon: variableSuffixBuilder?.call(endTimestampController),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
