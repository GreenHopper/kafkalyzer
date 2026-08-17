import 'package:flex_color_scheme/flex_color_scheme.dart';
// flex_color_scheme (as of 8.4.0) still targets the legacy
// package:flutter/material, which in Flutter 3.47+ is a separate type system
// from the official package:material_ui. `legacy` is used only to name types
// of the legacy theme that FlexThemeData consumes.
// See https://github.com/rydmike/flex_color_scheme/issues/310
import 'package:flutter/material.dart' as legacy;
import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/src/flex_theme_bridge.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

class AppTheme {
  static const FlexScheme _scheme = FlexScheme.indigo;

  static ThemeData get light => flexThemeToModern(
    FlexThemeData.light(
      scheme: _scheme,
      useMaterial3: true,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 7,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 10,
        blendOnColors: false,
        useM2StyleDividerInM3: true,
        defaultRadius: 12.0,
        thinBorderWidth: 1.0,
        thickBorderWidth: 2.0,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 12.0,
      ),
      visualDensity: legacy.VisualDensity.adaptivePlatformDensity,
      fontFamily: AppFonts.interFontFamily,
    ).copyWith(splashFactory: legacy.NoSplash.splashFactory),
  );

  static ThemeData get dark => flexThemeToModern(
    FlexThemeData.dark(
      scheme: _scheme,
      useMaterial3: true,
      surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
      blendLevel: 13,
      subThemesData: const FlexSubThemesData(
        blendOnLevel: 20,
        useM2StyleDividerInM3: true,
        defaultRadius: 12.0,
        thinBorderWidth: 1.0,
        thickBorderWidth: 2.0,
        inputDecoratorBorderType: FlexInputBorderType.outline,
        inputDecoratorRadius: 12.0,
      ),
      visualDensity: legacy.VisualDensity.adaptivePlatformDensity,
      fontFamily: AppFonts.interFontFamily,
    ).copyWith(splashFactory: legacy.NoSplash.splashFactory),
  );
}
