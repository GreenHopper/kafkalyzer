import 'dart:math' as math;
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

/// Control button or active chip to configure a [FieldValueFilter].
class ValueFilterControl extends StatelessWidget {
  final FieldValueFilter? activeFilter;
  final bool isAnalyzing;
  final List<String> availableFieldPaths;
  final ValueChanged<FieldValueFilter?> onFilterChanged;

  const ValueFilterControl({
    super.key,
    required this.activeFilter,
    required this.isAnalyzing,
    required this.availableFieldPaths,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    if (activeFilter != null) {
      return InputChip(
        avatar: Icon(
          Icons.filter_alt,
          size: 16,
          color: colorScheme.onSecondaryContainer,
        ),
        label: Text(
          l10n.valueFilterActive(activeFilter!.fieldPath, activeFilter!.value),
        ),
        onDeleted: isAnalyzing ? null : () => onFilterChanged(null),
        onPressed: isAnalyzing ? null : () => _showFilterDialog(context),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.filter_alt_outlined, size: 18),
      label: Text(l10n.valueFilterButton),
      onPressed: isAnalyzing ? null : () => _showFilterDialog(context),
    );
  }

  Future<void> _showFilterDialog(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;

    final pathController = TextEditingController(
      text: activeFilter?.fieldPath ?? '',
    );
    final valueController = TextEditingController(
      text: activeFilter?.value ?? '',
    );

    String? validationError;

    final filter = await showDialog<FieldValueFilter>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(l10n.valueFilterDialogTitle),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: pathController.text),
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return availableFieldPaths;
                        }
                        return availableFieldPaths.where(
                          (p) => p.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (selection) {
                        pathController.text = selection;
                      },
                      fieldViewBuilder:
                          (
                            context,
                            fieldTextEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            fieldTextEditingController.addListener(() {
                              pathController.text =
                                  fieldTextEditingController.text;
                            });
                            return TextField(
                              controller: fieldTextEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: l10n.valueFilterDialogFieldPath,
                                errorText: validationError,
                                isDense: true,
                              ),
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: valueController,
                      decoration: InputDecoration(
                        labelText: l10n.valueFilterDialogValue,
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(
                    MaterialLocalizations.of(dialogCtx).cancelButtonLabel,
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    final path = pathController.text.trim();
                    if (path.isEmpty) {
                      setDialogState(() {
                        validationError = l10n.valueFilterValidationEmpty;
                      });
                      return;
                    }
                    Navigator.of(dialogCtx).pop(
                      FieldValueFilter(
                        fieldPath: path,
                        value: valueController.text,
                      ),
                    );
                  },
                  child: Text(l10n.valueFilterApply),
                ),
              ],
            );
          },
        );
      },
    );

    if (filter != null) {
      onFilterChanged(filter);
    }
  }
}

/// Renders match metrics and shares when a [ValueFilterResult] is present.
class ValueFilterMatchCard extends StatelessWidget {
  final ValueFilterResult result;
  final int totalMessages;

  const ValueFilterMatchCard({
    super.key,
    required this.result,
    required this.totalMessages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final numberFormat = NumberFormat.decimalPattern();

    final shareOfAll = totalMessages > 0
        ? (result.matchedMessages / totalMessages) * 100.0
        : 0.0;
    final shareOfField = result.messagesWithField > 0
        ? (result.matchedMessages / result.messagesWithField) * 100.0
        : 0.0;
    final remainder = math.max(0, totalMessages - result.matchedMessages);

    return Card(
      elevation: 0,
      color: colorScheme.secondaryContainer.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.secondary.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.filter_alt_rounded,
                  size: 20,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.valueFilterMatchCardTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${result.fieldPath} = "${result.value}"',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                _StatColumn(
                  title: l10n.valueFilterMatchCount(
                    numberFormat.format(result.matchedMessages),
                  ),
                  subtitle: l10n.valueFilterShareOfTotal(
                    shareOfAll.toStringAsFixed(2),
                  ),
                  color: colorScheme.secondary,
                ),
                _StatColumn(
                  title: '${shareOfField.toStringAsFixed(2)}%',
                  subtitle: l10n.valueFilterShareOfField(
                    shareOfField.toStringAsFixed(2),
                  ),
                  color: colorScheme.primary,
                ),
                _StatColumn(
                  title: numberFormat.format(remainder),
                  subtitle: l10n.valueFilterRemainder(
                    numberFormat.format(remainder),
                  ),
                  color: colorScheme.outline,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;

  const _StatColumn({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
