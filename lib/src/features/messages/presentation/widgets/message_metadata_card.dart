import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/features/messages/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/color_utils.dart';

class MessageMetadataCard extends StatelessWidget {
  final KafkaMessage message;
  final KafkaMessage? prevMessage;

  const MessageMetadataCard({
    super.key,
    required this.message,
    this.prevMessage,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(message.timestamp.toInt());
    final dateStr = DateFormatUtils.formatDateTime(
      context,
      date,
      withMilliseconds: true,
    );

    String durationStr = "";
    if (prevMessage != null) {
      final diff = message.timestamp - prevMessage!.timestamp;
      final absDiff = diff.abs();
      if (absDiff < 1000) {
        durationStr = "+${absDiff}ms";
      } else if (absDiff < 60000) {
        durationStr = "+${(absDiff / 1000).toStringAsFixed(1)}s";
      } else {
        durationStr = "+${(absDiff / 60000).toStringAsFixed(1)}m";
      }
    } else {
      durationStr = "Start";
    }

    String? stepName;
    if (message is ScriptResultMessage) {
      stepName = (message as ScriptResultMessage).stepName;
    }

    final topicColor = ColorUtils.getColorForString(message.topic);

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Time & Duration
            Text(
              durationStr,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.right,
            ),
            Text(
              dateStr,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 4),

            // Topic & Step
            Text(
              message.topic,
              style: TextStyle(
                fontSize: 11,
                color: topicColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (stepName != null)
              Text(
                stepName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 4),

            // Technical Details
            Text(
              "P: ${message.partition} | O: ${message.offset}",
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.right,
            ),
            ?_buildCompactSchemaIndicator(context),
          ],
        ),
      ),
    );
  }

  /// Compact schema provenance indicator. Only rendered when at least one side
  /// carries a registry schema, without repeating redundant topic names or
  /// rendering negative "no schema" placeholders.
  Widget? _buildCompactSchemaIndicator(BuildContext context) {
    final keySchema = message.keySchema;
    final valueSchema = message.valueSchema;
    final keyLocal = message.keyLocalSchema;
    final valueLocal = message.valueLocalSchema;
    if (keySchema == null &&
        valueSchema == null &&
        keyLocal == null &&
        valueLocal == null) {
      return null;
    }

    final l10n = AppLocalizations.of(context);
    final parts = <Widget>[];

    String formatSchema(MessageSchema s) {
      if (s.version != null) {
        return 'v${s.version} (#${s.schemaId})';
      }
      return '#${s.schemaId}';
    }

    if (keyLocal != null) {
      final hasErr = keyLocal.error != null;
      final label = hasErr
          ? (l10n?.localSchemaCardBadgeKeyError ?? 'K: local !')
          : (l10n?.localSchemaCardBadgeKey ?? 'K: local');
      parts.add(
        Text(
          label,
          key: const Key('metadata_card_local_schema_key'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: hasErr
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.right,
        ),
      );
    } else if (keySchema != null) {
      parts.add(
        Text(
          'K: ${formatSchema(keySchema)}',
          key: const Key('metadata_card_schema_key'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.right,
        ),
      );
    }

    if (valueLocal != null) {
      final hasErr = valueLocal.error != null;
      final label = hasErr
          ? (l10n?.localSchemaCardBadgeValueError ?? 'V: local !')
          : (l10n?.localSchemaCardBadgeValue ?? 'V: local');
      parts.add(
        Text(
          label,
          key: const Key('metadata_card_local_schema_value'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: hasErr
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.right,
        ),
      );
    } else if (valueSchema != null) {
      parts.add(
        Text(
          (keySchema != null || keyLocal != null)
              ? 'V: ${formatSchema(valueSchema)}'
              : formatSchema(valueSchema),
          key: const Key('metadata_card_schema_value'),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.right,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Wrap(alignment: WrapAlignment.end, spacing: 6, children: parts),
    );
  }
}
