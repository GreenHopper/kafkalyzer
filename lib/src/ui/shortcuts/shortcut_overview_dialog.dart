import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';
import 'app_shortcuts.dart';

/// Modal dialog listing every [ShortcutEntry] in [AppShortcuts.all] grouped
/// by [ShortcutContext], with platform-aware modifier labels.
class ShortcutOverviewDialog extends StatelessWidget {
  const ShortcutOverviewDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ShortcutOverviewDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final platform = theme.platform;

    final grouped = <ShortcutContext, List<ShortcutEntry>>{};
    for (final entry in AppShortcuts.all) {
      grouped.putIfAbsent(entry.context, () => []).add(entry);
    }

    return AlertDialog(
      title: Text(l10n.shortcutOverviewTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final ctx in ShortcutContext.values)
                if (grouped.containsKey(ctx)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      ctx.label(l10n),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  for (final entry in grouped[ctx]!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(entry.description(l10n))),
                          const SizedBox(width: 16),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (final key in entry.keys)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: theme.colorScheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    key.format(l10n, platform),
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
