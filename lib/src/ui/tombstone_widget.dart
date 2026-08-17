import 'package:material_ui/material_ui.dart';

class TombstoneWidget extends StatelessWidget {
  const TombstoneWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Greyed out styling for Tombstone
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            "TOMBSTONE (Value is NULL)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
