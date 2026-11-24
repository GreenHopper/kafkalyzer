import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/theme.dart';

/// Theme colours from FlexColorScheme are wide-gamut; compare by ARGB32.
Matcher _argb(int expected) =>
    isA<Color>().having((c) => c.toARGB32(), 'toARGB32', expected);

void main() {
  group('AppTheme', () {
    test('light pins colours, density, font and input radius', () {
      final theme = AppTheme.light;
      final cs = theme.colorScheme;

      expect(theme.brightness, Brightness.light);
      expect(theme.useMaterial3, isTrue);
      expect(theme.visualDensity, VisualDensity.adaptivePlatformDensity);
      expect(theme.splashFactory, same(NoSplash.splashFactory));
      expect(theme.textTheme.bodyLarge?.fontFamily, 'sans-serif');
      expect(cs.primary, _argb(0xff303f9f));
      expect(cs.onPrimary, _argb(0xffffffff));
      expect(cs.secondary, _argb(0xff512da8));
      expect(cs.surface, _argb(0xfffafafb));
      expect(theme.scaffoldBackgroundColor, _argb(0xffeeeff7));
      expect(
        theme.inputDecorationTheme.border,
        isA<OutlineInputBorder>().having(
          (b) => b.borderRadius,
          'borderRadius',
          BorderRadius.circular(4),
        ),
      );
    });

    test('dark pins colours, density, font and input radius', () {
      final theme = AppTheme.dark;
      final cs = theme.colorScheme;

      expect(theme.brightness, Brightness.dark);
      expect(theme.useMaterial3, isTrue);
      expect(theme.visualDensity, VisualDensity.adaptivePlatformDensity);
      expect(theme.splashFactory, same(NoSplash.splashFactory));
      expect(theme.textTheme.bodyLarge?.fontFamily, 'sans-serif');
      expect(cs.primary, _argb(0xff7986cb));
      expect(cs.onPrimary, _argb(0xffffffff));
      expect(cs.secondary, _argb(0xff9575cd));
      expect(cs.surface, _argb(0xff0b0b0d));
      expect(theme.scaffoldBackgroundColor, _argb(0xff131520));
      expect(
        theme.inputDecorationTheme.border,
        isA<OutlineInputBorder>().having(
          (b) => b.borderRadius,
          'borderRadius',
          BorderRadius.circular(4),
        ),
      );
    });
  });
}
