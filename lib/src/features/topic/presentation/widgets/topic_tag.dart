import 'package:flutter/material.dart';

class TopicTag extends StatelessWidget {
  final String text;
  final bool isConfig;
  final bool isSchema;
  final VoidCallback? onTap;

  const TopicTag(
    this.text, {
    super.key,
    this.isConfig = false,
    this.isSchema = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _getColors(context);

    final widget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: widget,
      );
    }
    return widget;
  }

  ({Color backgroundColor, Color textColor}) _getColors(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    Color bgColor = colorScheme.surfaceContainerHigh;
    Color textColor = colorScheme.onSurfaceVariant;

    if (isSchema) {
      // Make Avro distinct
      // In Dark Mode, Secondary and Tertiary can be similar. Switch Avro to Primary in dark mode to distinguish from Compact (Tertiary).
      final isDark = Theme.of(context).brightness == Brightness.dark;
      if (isDark) {
        bgColor = colorScheme.primaryContainer;
        textColor = colorScheme.onPrimaryContainer;
      } else {
        bgColor = colorScheme.secondaryContainer;
        textColor = colorScheme.onSecondaryContainer;
      }
    } else if (isConfig) {
      // Differentiate cleanup policies
      if (text.contains("delete") && text.contains("compact")) {
        // Combined policy
        if (Theme.of(context).brightness == Brightness.dark) {
          // Use Orange to differentiate from Compact (Tertiary) and Avro (Primary)
          // Secondary/Tertiary seem close in this theme, so we step outside the scheme for distinctiveness.
          bgColor = Colors.orange.withValues(alpha: 0.2);
          textColor = Colors.orange.shade200;
        } else {
          // Light mode: Primary (Blue) - user liked this.
          bgColor = colorScheme.primaryContainer;
          textColor = colorScheme.onPrimaryContainer;
        }
      } else if (text == "delete") {
        bgColor = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
      } else if (text == "compact") {
        bgColor = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
      } else {
        // Default config (retention, etc.)
        bgColor = colorScheme.surfaceContainerHighest;
        textColor = colorScheme.onSurfaceVariant;
      }
    }
    return (backgroundColor: bgColor, textColor: textColor);
  }
}
