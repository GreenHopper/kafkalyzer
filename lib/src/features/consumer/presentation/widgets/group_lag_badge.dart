import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import '../../domain/consumer_lag_calculator.dart';

class GroupLagBadge extends StatelessWidget {
  final int totalLag;
  final bool isLoading;
  final bool isLoaded;
  final bool isFailed;
  final bool hasPreviousValue;
  final String labelText;
  final GroupLagOutcome? outcome;
  final String? errorReason;
  final AppLocalizations? l10n;

  /// Lag in messages at which the badge warns; 0 disables the warning.
  final int warnThreshold;
  final String? warnTooltip;

  const GroupLagBadge({
    super.key,
    required this.totalLag,
    required this.isLoading,
    required this.isLoaded,
    required this.isFailed,
    required this.hasPreviousValue,
    required this.labelText,
    this.outcome,
    this.errorReason,
    this.l10n,
    this.warnThreshold = 0,
    this.warnTooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && !hasPreviousValue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (isFailed || outcome == GroupLagOutcome.unknown) {
      final scheme = Theme.of(context).colorScheme;
      final label = isFailed
          ? (l10n?.lagErrorLabel ?? 'Error')
          : (l10n?.lagUnknown ?? 'Unknown');
      final reason = errorReason ?? label;
      final tooltipMsg = l10n != null ? l10n!.lagErrorTooltip(reason) : reason;

      return Semantics(
        label: tooltipMsg,
        child: Tooltip(
          message: tooltipMsg,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isFailed ? Icons.error_outline : Icons.help_outline,
                  size: 14,
                  color: scheme.onErrorContainer,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (outcome == GroupLagOutcome.noCommittedOffsets && isLoaded) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          labelText,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (!isLoaded && !isLoading && !hasPreviousValue) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          labelText,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    final warned = warnThreshold > 0 && totalLag >= warnThreshold;
    final badgeColor = warned
        ? Theme.of(context).colorScheme.tertiaryContainer
        : totalLag > 0
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.primaryContainer;
    final textColor = warned
        ? Theme.of(context).colorScheme.onTertiaryContainer
        : totalLag > 0
        ? Theme.of(context).colorScheme.onErrorContainer
        : Theme.of(context).colorScheme.onPrimaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (warned) ...[
              Tooltip(
                message: warnTooltip ?? labelText,
                child: const Icon(Icons.warning_amber_rounded, size: 14),
              ),
              const SizedBox(width: 4),
            ],
            Text(
              labelText,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: textColor,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: 4),
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
