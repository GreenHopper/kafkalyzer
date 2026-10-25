import 'package:material_ui/material_ui.dart';

class GroupLagBadge extends StatelessWidget {
  final int totalLag;
  final bool isLoading;
  final bool isLoaded;
  final bool isFailed;
  final bool hasPreviousValue;
  final String labelText;

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

    if (isFailed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "Error",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Theme.of(context).colorScheme.onErrorContainer,
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
