import 'package:intl/intl.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:material_ui/material_ui.dart';

/// One-line indicator showing how many oldest messages were dropped due to the
/// configured per-view message buffer limit.
class DroppedMessagesIndicator extends StatelessWidget {
  final int droppedCount;
  final int bufferLimit;

  const DroppedMessagesIndicator({
    super.key,
    required this.droppedCount,
    required this.bufferLimit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final fmt = NumberFormat.decimalPattern(locale);
    final droppedText = fmt.format(droppedCount);
    final limitText = fmt.format(bufferLimit);
    final label =
        l10n?.droppedMessagesIndicator(droppedText, limitText) ??
        '$droppedText oldest messages dropped (limit $limitText)';
    final tooltip =
        l10n?.droppedMessagesTooltip ??
        'Oldest messages are evicted once the buffer limit is reached. You can adjust this limit in Settings → General.';
    final color = Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontSize: 11, color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
