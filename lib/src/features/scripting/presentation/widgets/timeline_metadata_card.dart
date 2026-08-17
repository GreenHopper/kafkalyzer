import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/features/scripting/domain/script_result_message.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/date_format_utils.dart';
import 'package:kafkalyzer/src/ui/color_utils.dart';

class TimelineMetadataCard extends StatelessWidget {
  final KafkaMessage message;
  final KafkaMessage? prevMessage;

  const TimelineMetadataCard({
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
      elevation: 1,
      // Use a distinct but neutral color, avoiding transparency for visibility
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
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
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Time & Duration
            Text(
              durationStr,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[700],
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
                style: const TextStyle(fontSize: 10, color: Colors.black87),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: 4),

            // Technical Details
            Text(
              "P: ${message.partition} | O: ${message.offset}",
              style: const TextStyle(fontSize: 10, color: Colors.grey),
              textAlign: TextAlign.right,
            ),
          ],
        ),
      ),
    );
  }
}
