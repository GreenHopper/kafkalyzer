import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/topic/presentation/widgets/analysis/field_value_explorer.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';
import 'package:material_ui/material_ui.dart';

class KeyAndFieldDistributionView extends StatelessWidget {
  final List<KeyOccurrence> topKeys;
  final List<TypeOccurrence> contentTypes;
  final List<FieldOccurrence> fieldFrequencies;

  const KeyAndFieldDistributionView({
    super.key,
    required this.topKeys,
    required this.contentTypes,
    required this.fieldFrequencies,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 750;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 1, child: _TopKeysCard(topKeys: topKeys)),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: _ContentTypesCard(contentTypes: contentTypes),
                  ),
                ],
              ),
            ] else ...[
              _TopKeysCard(topKeys: topKeys),
              const SizedBox(height: 12),
              _ContentTypesCard(contentTypes: contentTypes),
            ],
            const SizedBox(height: 16),
            FieldValueExplorer(fieldFrequencies: fieldFrequencies),
          ],
        );
      },
    );
  }
}

class _TopKeysCard extends StatelessWidget {
  final List<KeyOccurrence> topKeys;

  const _TopKeysCard({required this.topKeys});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();

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
                  Icons.vpn_key_rounded,
                  size: 20,
                  color: colorScheme.tertiary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.topKeys ?? 'Top Message Keys',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (topKeys.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'No keyed messages found',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: topKeys.length.clamp(0, 8),
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final k = topKeys[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  k.key,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: (k.percentage / 100.0).clamp(
                                      0.0,
                                      1.0,
                                    ),
                                    minHeight: 3,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    color: colorScheme.tertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${numberFormat.format(k.count)} '
                            '(${k.percentage.toStringAsFixed(1)}%)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
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
      ),
    );
  }
}

class _ContentTypesCard extends StatelessWidget {
  final List<TypeOccurrence> contentTypes;

  const _ContentTypesCard({required this.contentTypes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final numberFormat = NumberFormat.decimalPattern();

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
                  Icons.data_object_rounded,
                  size: 20,
                  color: colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.contentTypeBreakdown ?? 'Content Types',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (contentTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'No content types recorded',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: contentTypes.map((type) {
                  return Chip(
                    avatar: Icon(
                      _iconForType(type.typeName),
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    label: Text(
                      '${type.typeName}: ${numberFormat.format(type.count)} '
                      '(${type.percentage.toStringAsFixed(1)}%)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    backgroundColor: colorScheme.surfaceContainerHigh,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('json')) return Icons.code_rounded;
    if (lower.contains('tombstone')) return Icons.delete_outline_rounded;
    if (lower.contains('avro') || lower.contains('schema')) {
      return Icons.schema_outlined;
    }
    if (lower.contains('text')) return Icons.text_snippet_outlined;
    return Icons.memory_rounded;
  }
}
