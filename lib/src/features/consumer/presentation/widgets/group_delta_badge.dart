import 'package:material_ui/material_ui.dart';

class GroupDeltaBadge extends StatelessWidget {
  final int? delta;
  final String formattedDelta;

  const GroupDeltaBadge({
    super.key,
    required this.delta,
    required this.formattedDelta,
  });

  @override
  Widget build(BuildContext context) {
    if (delta == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "-",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      );
    }

    final Color color;
    if (delta! > 0) {
      color = Colors.red;
    } else if (delta! < 0) {
      color = Colors.green;
    } else {
      color = Theme.of(context).colorScheme.outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        formattedDelta,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }
}
