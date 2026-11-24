import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/rust/api/kafka_consumer.dart';
import 'package:kafkalyzer/src/ui/highlight_text_utils.dart';
import 'package:kafkalyzer/src/ui/text_preview_utils.dart';
import 'package:kafkalyzer/src/ui/tombstone_widget.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

class TimelineMessageCard extends StatelessWidget {
  final KafkaMessage message;
  final String? searchPhrase;
  final VoidCallback onTap;
  final Widget? customContent;
  final List<MapEntry<String, String>>? extractedValues;
  final bool showPayloadPreview;
  final bool isSelected;

  const TimelineMessageCard({
    super.key,
    required this.message,
    required this.onTap,
    this.searchPhrase,
    this.customContent,
    this.extractedValues,
    this.showPayloadPreview = true,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: isSelected ? 2 : 0,
      color: isSelected
          ? colorScheme.primaryContainer.withValues(
              alpha: Theme.of(context).brightness == Brightness.dark
                  ? 0.45
                  : 0.65,
            )
          : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isSelected
              ? colorScheme.primary
              : Theme.of(context).dividerColor,
          width: isSelected ? 2.5 : 1.0,
        ),
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

  Color _effectiveCardBackground(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final baseSurface =
        theme.cardTheme.color ?? colorScheme.surfaceContainerLow;
    if (!isSelected) return baseSurface;
    final overlay = colorScheme.primaryContainer.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.45 : 0.65,
    );
    return Color.alphaBlend(overlay, baseSurface);
  }

  Widget _buildKey(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardBg = _effectiveCardBackground(context);
    final fallback = isSelected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final keyColor = TextPreviewUtils.ensureContrast(
      colorScheme.primary,
      cardBg,
      fallback,
    );
    final baseFontSize = theme.textTheme.titleSmall?.fontSize ?? 14.0;
    final keyStyle = AppFonts.robotoMono(
      fontSize: baseFontSize,
      height: 1.4,
      fontWeight: FontWeight.bold,
      color: keyColor,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.vpn_key, size: 16, color: keyColor),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: keyStyle,
              children: HighlightTextUtils.buildHighlightedSpans(
                message.key!,
                searchPhrase ?? "",
                keyStyle,
                keyStyle.copyWith(
                  backgroundColor: isSelected
                      ? colorScheme.tertiaryContainer
                      : colorScheme.primaryContainer,
                  color: isSelected
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onPrimaryContainer,
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final payloadPreview = TextPreviewUtils.getPayloadPreview(message.payload);
    final baseFontSize = theme.textTheme.bodyMedium?.fontSize ?? 13.0;
    final baseStyle = AppFonts.robotoMono(
      fontSize: baseFontSize,
      height: 1.4,
      color: isSelected
          ? colorScheme.onPrimaryContainer
          : colorScheme.onSurface,
    );
    final cardBg = _effectiveCardBackground(context);

    return RichText(
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      textScaler: MediaQuery.textScalerOf(context),
      text: TextSpan(
        style: baseStyle,
        children: TextPreviewUtils.buildSyntaxHighlightedPreviewSpans(
          preview: payloadPreview,
          searchPhrase: searchPhrase ?? "",
          baseStyle: baseStyle,
          colorScheme: colorScheme,
          backgroundColor: cardBg,
          isSelected: isSelected,
        ),
      ),
    );
  }
}
