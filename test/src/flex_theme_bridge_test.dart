import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/flex_theme_bridge.dart';
import 'package:kafkalyzer/src/theme.dart';

void main() {
  group('flexThemeToModern', () {
    test('maps core theme values', () {
      final legacyTheme = FlexThemeData.light(
        scheme: FlexScheme.indigo,
        useMaterial3: true,
        visualDensity: legacy.VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
      );
      final modernTheme = flexThemeToModern(legacyTheme);

      expect(modernTheme.colorScheme, isA<ColorScheme>());
      // fontFamily is applied to the default text themes.
      expect(modernTheme.textTheme.bodyLarge?.fontFamily, 'Inter');
      expect(modernTheme.useMaterial3, isTrue);
      expect(modernTheme.visualDensity, VisualDensity.adaptivePlatformDensity);
      expect(modernTheme.colorScheme.primary, legacyTheme.colorScheme.primary);
    });

    test('maps sub-themes', () {
      final modernTheme = flexThemeToModern(
        FlexThemeData.light(
          scheme: FlexScheme.indigo,
          useMaterial3: true,
          subThemesData: const FlexSubThemesData(
            defaultRadius: 12.0,
            inputDecoratorBorderType: FlexInputBorderType.outline,
            inputDecoratorRadius: 12.0,
          ),
        ),
      );

      expect(modernTheme.cardTheme, isA<CardThemeData>());
      expect(modernTheme.textTheme, isA<TextTheme>());
      expect(modernTheme.primaryTextTheme, isA<TextTheme>());
      expect(modernTheme.inputDecorationTheme, isA<InputDecorationThemeData>());
    });

    test('preserves NoSplash splash factory', () {
      final modernTheme = flexThemeToModern(
        FlexThemeData.light(
          scheme: FlexScheme.indigo,
        ).copyWith(splashFactory: legacy.NoSplash.splashFactory),
      );
      // splashFactory is a factory; the NoSplash const factory is passed by
      // identity.
      expect(modernTheme.splashFactory, same(NoSplash.splashFactory));
    });
  });

  group('AppTheme', () {
    test('light and dark themes are valid modern material_ui themes', () {
      expect(AppTheme.light, isA<ThemeData>());
      expect(AppTheme.dark, isA<ThemeData>());
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
      expect(AppTheme.light.splashFactory, same(NoSplash.splashFactory));
      expect(AppTheme.dark.splashFactory, same(NoSplash.splashFactory));
    });
  });
}
