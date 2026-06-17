import 'package:kafkalyzer/src/ui/color_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ColorUtils', () {
    test('getColorForString returns consistent color for same input', () {
      final color1 = ColorUtils.getColorForString('topic-a');
      final color2 = ColorUtils.getColorForString('topic-a');
      expect(color1, equals(color2));
    });

    test('getColorForString returns different colors for different inputs', () {
      final color1 = ColorUtils.getColorForString('topic-a');
      final color2 = ColorUtils.getColorForString('topic-b');
      expect(color1, isNot(equals(color2)));
    });

    test('getColorForString returns fully opaque color', () {
      final color = ColorUtils.getColorForString('test');
      expect(color.a, 1.0);
    });
  });
}
