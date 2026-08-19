import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

class FieldValueExplorer extends StatefulWidget {
  final List<FieldOccurrence> fieldFrequencies;

  const FieldValueExplorer({super.key, required this.fieldFrequencies});

  @override
  State<FieldValueExplorer> createState() => _FieldValueExplorerState();
}

class _FieldValueExplorerState extends State<FieldValueExplorer> {
  final TextEditingController _searchController = TextEditingController();
  String? _selectedFieldName;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.fieldFrequencies.isNotEmpty) {
      _selectedFieldName = widget.fieldFrequencies.first.fieldName;
    }
  }

  @override
  void didUpdateWidget(covariant FieldValueExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fieldFrequencies.isNotEmpty) {
      final exists = widget.fieldFrequencies.any(
        (f) => f.fieldName == _selectedFieldName,
      );
      if (!exists) {
        setState(() {
          _selectedFieldName = widget.fieldFrequencies.first.fieldName;
        });
      }
    } else {
      setState(() {
        _selectedFieldName = null;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (widget.fieldFrequencies.isEmpty) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Text(
              'No structured fields detected',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }

    final filteredFields = widget.fieldFrequencies.where((f) {
      if (_searchQuery.isEmpty) return true;
      return f.fieldName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    FieldOccurrence? selectedField;
    if (_selectedFieldName != null) {
      selectedField = widget.fieldFrequencies.firstWhere(
        (f) => f.fieldName == _selectedFieldName,
        orElse: () => widget.fieldFrequencies.first,
      );
    } else if (filteredFields.isNotEmpty) {
      selectedField = filteredFields.first;
    }

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.format_list_numbered_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.fieldValueExplorer ??
                      'Field Value Explorer (Top 10 Values)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 650;
                if (isWide) {
                  return SizedBox(
                    height: 380,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: 260,
                          child: _buildFieldListPane(
                            context,
                            theme,
                            colorScheme,
                            l10n,
                            filteredFields,
                            selectedField?.fieldName,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTopValuesPane(
                            context,
                            theme,
                            colorScheme,
                            l10n,
                            selectedField,
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Column(
                    children: [
                      SizedBox(
                        height: 220,
                        child: _buildFieldListPane(
                          context,
                          theme,
                          colorScheme,
                          l10n,
                          filteredFields,
                          selectedField?.fieldName,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 320,
                        child: _buildTopValuesPane(
                          context,
                          theme,
                          colorScheme,
                          l10n,
                          selectedField,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldListPane(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
    List<FieldOccurrence> fields,
    String? currentSelectedName,
  ) {
    final numberFormat = NumberFormat.decimalPattern();

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(6.0),
              child: TextField(
                controller: _searchController,
                style: theme.textTheme.bodySmall,
                decoration: InputDecoration(
                  hintText: l10n?.searchFields ?? 'Search fields...',
                  prefixIcon: const Icon(Icons.search, size: 16),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: fields.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text(
                          l10n?.noMatchingFields(_searchQuery) ??
                              'No matching fields',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: fields.length,
                      separatorBuilder: (context, _) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final field = fields[index];
                        final isSelected =
                            field.fieldName == currentSelectedName;

                        return Material(
                          color: isSelected
                              ? colorScheme.primaryContainer.withValues(
                                  alpha: 0.5,
                                )
                              : Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFieldName = field.fieldName;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10.0,
                                vertical: 6.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      field.fieldName,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            fontFamily: 'monospace',
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? colorScheme.onPrimaryContainer
                                                : null,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${numberFormat.format(field.count)} (${field.percentage.toStringAsFixed(0)}%)',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontSize: 10,
                                      color: isSelected
                                          ? colorScheme.onPrimaryContainer
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopValuesPane(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    AppLocalizations? l10n,
    FieldOccurrence? field,
  ) {
    if (field == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            l10n?.selectFieldToInspect ??
                'Select a field to inspect its Top 10 values',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    final numberFormat = NumberFormat.decimalPattern();
    final topValues = field.topValues;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                l10n?.top10ValuesForField(field.fieldName) ??
                    'Top 10 Values for ${field.fieldName}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                l10n?.fieldOccurrences(
                      numberFormat.format(field.count),
                      field.percentage.toStringAsFixed(1),
                    ) ??
                    'Appears in ${numberFormat.format(field.count)} msgs (${field.percentage.toStringAsFixed(1)}%)',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 4),
          Expanded(
            child: topValues.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No scalar values recorded for this field',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: topValues.length,
                    separatorBuilder: (context, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final v = topValues[index];
                      final rank = index + 1;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: rank <= 3
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '#$rank',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: rank <= 3
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v.value,
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                fontFamily: 'monospace',
                                              ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.copy, size: 13),
                                        tooltip:
                                            l10n?.copyMessage ?? 'Copy value',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 20,
                                          minHeight: 20,
                                        ),
                                        onPressed: () {
                                          Clipboard.setData(
                                            ClipboardData(text: v.value),
                                          );
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                l10n?.valueCopied ??
                                                    'Value copied to clipboard',
                                              ),
                                              duration: const Duration(
                                                seconds: 1,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(2),
                                    child: LinearProgressIndicator(
                                      value: (v.percentage / 100.0).clamp(
                                        0.0,
                                        1.0,
                                      ),
                                      minHeight: 3,
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${numberFormat.format(v.count)} '
                              '(${v.percentage.toStringAsFixed(1)}%)',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
