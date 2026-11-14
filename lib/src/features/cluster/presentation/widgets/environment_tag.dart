import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/rust/api/kafka_types.dart';

/// Fixed environment tag colour palette adapting to light and dark themes.
class EnvironmentPalette {
  const EnvironmentPalette._();

  static const List<String> keys = [
    'red',
    'orange',
    'yellow',
    'green',
    'blue',
    'purple',
    'grey',
  ];

  static const Map<String, String> suggestedColors = {
    'DEV': 'green',
    'TEST': 'blue',
    'STAGE': 'orange',
    'PROD': 'red',
  };

  static bool isKnownKey(String? key) => key != null && keys.contains(key);

  static String? suggestedColorForLabel(String label) =>
      suggestedColors[label.trim().toUpperCase()];

  static ({Color container, Color onContainer}) resolve(
    BuildContext context,
    String? colorKey,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    switch (colorKey) {
      case 'red':
        return (container: cs.errorContainer, onContainer: cs.onErrorContainer);
      case 'orange':
        return isDark
            ? (
                container: const Color(0xFF5A3208),
                onContainer: const Color(0xFFFFDCC2),
              )
            : (
                container: const Color(0xFFFFE5CC),
                onContainer: const Color(0xFF5A2A00),
              );
      case 'yellow':
        return isDark
            ? (
                container: const Color(0xFF4D4208),
                onContainer: const Color(0xFFFFF0B3),
              )
            : (
                container: const Color(0xFFFFF4C2),
                onContainer: const Color(0xFF4A3B00),
              );
      case 'green':
        return isDark
            ? (
                container: const Color(0xFF144726),
                onContainer: const Color(0xFFC2F0CE),
              )
            : (
                container: const Color(0xFFD7F5DF),
                onContainer: const Color(0xFF0E3E1E),
              );
      case 'blue':
        return isDark
            ? (
                container: const Color(0xFF143C5E),
                onContainer: const Color(0xFFC7E4FF),
              )
            : (
                container: const Color(0xFFD8ECFF),
                onContainer: const Color(0xFF0D3354),
              );
      case 'purple':
        return isDark
            ? (
                container: const Color(0xFF3E2259),
                onContainer: const Color(0xFFEBD6FF),
              )
            : (
                container: const Color(0xFFEFDFFF),
                onContainer: const Color(0xFF3A1859),
              );
      case 'grey':
      default:
        return (
          container: cs.surfaceContainerHighest,
          onContainer: cs.onSurfaceVariant,
        );
    }
  }

  static String localizedName(AppLocalizations l10n, String key) {
    switch (key) {
      case 'red':
        return l10n.environmentColorRed;
      case 'orange':
        return l10n.environmentColorOrange;
      case 'yellow':
        return l10n.environmentColorYellow;
      case 'green':
        return l10n.environmentColorGreen;
      case 'blue':
        return l10n.environmentColorBlue;
      case 'purple':
        return l10n.environmentColorPurple;
      case 'grey':
      default:
        return l10n.environmentColorGrey;
    }
  }
}

/// Compact environment tag chip shown next to cluster names.
class EnvironmentTagChip extends StatelessWidget {
  const EnvironmentTagChip({
    super.key,
    required this.profile,
    this.compact = false,
  });

  final ClusterProfile profile;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = profile.environmentLabel?.trim();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = EnvironmentPalette.resolve(
      context,
      profile.environmentColor,
    );

    return Semantics(
      label: l10n.environmentSemanticsLabel(label),
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 1 : 2,
        ),
        decoration: BoxDecoration(
          color: colors.container,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors.onContainer,
            fontSize: compact ? 10 : 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Explorer header banner for an active cluster with an environment tag.
class EnvironmentBanner extends StatelessWidget {
  const EnvironmentBanner({super.key, required this.profile});

  final ClusterProfile profile;

  @override
  Widget build(BuildContext context) {
    final label = profile.environmentLabel?.trim();
    if (label == null || label.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final colors = EnvironmentPalette.resolve(
      context,
      profile.environmentColor,
    );

    return Semantics(
      label: l10n.environmentSemanticsLabel(label),
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        color: colors.container,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.onContainer.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: colors.onContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                profile.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Search/filter field shared between Settings and Explorer cluster lists.
class ClusterFilterField extends StatelessWidget {
  const ClusterFilterField({
    super.key,
    required this.controller,
    required this.onChanged,
    this.dense = false,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense: dense,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: l10n.clusterFilterHint,
            border: const OutlineInputBorder(),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    tooltip: l10n.clusterFilterClear,
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        );
      },
    );
  }
}
