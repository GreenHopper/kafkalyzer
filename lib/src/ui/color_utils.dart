import 'package:material_ui/material_ui.dart';

class ColorUtils {
  // Enforce static access
  ColorUtils._();

  /// Generates a consistent color for a given string (e.g. topic name).
  /// Uses HSL to ensure colors are visible and visually distinct.
  static Color getColorForString(String input) {
    final hash = input.hashCode;
    // Use HSL to ensure visible colors (not too dark/light)
    // Hue: 0-360 based on hash
    // Saturation: 0.7 (vibrant)
    // Lightness: 0.45 (readable against white/light backgrounds)
    final hsl = HSLColor.fromAHSL(1.0, (hash % 360).toDouble(), 0.7, 0.45);
    return hsl.toColor();
  }
}
