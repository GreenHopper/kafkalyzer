import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/highlight_text_utils.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';
import 'package:kafkalyzer/src/ui/tombstone_widget.dart';

class TimelineMessageCard extends StatelessWidget {
  final KafkaMessage message;
  final String? searchPhrase;
  final VoidCallback onTap;
  final Widget? customContent;
  final List<MapEntry<String, String>>? extractedValues;
  final bool showPayloadPreview;

  const TimelineMessageCard({
    super.key,
    required this.message,
    required this.onTap,
    this.searchPhrase,
    this.customContent,
    this.extractedValues,
    this.showPayloadPreview = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (extractedValues != null && extractedValues!.isNotEmpty)
                _buildExtractedValues(context),
              if (message.key != null) ...[
                _buildKey(context),
                if (customContent != null || showPayloadPreview)
                  const SizedBox(height: 8),
              ],
              if (customContent != null)
                customContent!
              else if (showPayloadPreview)
                if (message.payload == null)
                  const TombstoneWidget()
                else
                  _buildPayloadPreview(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKey(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.vpn_key,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
              children: HighlightTextUtils.buildHighlightedSpans(
                message.key!,
                searchPhrase ?? "",
                Theme.of(context).textTheme.titleSmall!.copyWith(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
                TextStyle(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExtractedValues(BuildContext context) {
    if (extractedValues == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: extractedValues!.map((e) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                  children: [
                    TextSpan(
                      text: "${e.key}: ",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: e.value),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildPayloadPreview(BuildContext context) {
    final payloadPreview = TextPreviewUtils.getPayloadPreview(message.payload);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
        children: HighlightTextUtils.buildHighlightedSpans(
          payloadPreview,
          searchPhrase ?? "",
          Theme.of(
            context,
          ).textTheme.bodyMedium!.copyWith(fontFamily: 'monospace'),
          TextStyle(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}
