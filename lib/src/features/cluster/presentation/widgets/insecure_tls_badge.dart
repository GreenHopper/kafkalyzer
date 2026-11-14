import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';

class InsecureTlsBadge extends StatelessWidget {
  final bool compact;

  const InsecureTlsBadge({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: l10n.insecureTlsBadgeTooltip,
      child: Tooltip(
        message: l10n.insecureTlsBadgeTooltip,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 6 : 8,
            vertical: compact ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: colorScheme.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.gpp_bad_outlined,
                size: compact ? 12 : 14,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.insecureTlsBadgeLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
