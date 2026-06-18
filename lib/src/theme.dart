import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:kafkalyzer/src/utils/app_fonts.dart';

class AppTheme {
  static const FlexScheme _scheme = FlexScheme.indigo;

  static ThemeData get light => FlexThemeData.light(
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
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: AppFonts.interFontFamily,
  ).copyWith(splashFactory: NoSplash.splashFactory);

  static ThemeData get dark => FlexThemeData.dark(
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
    visualDensity: VisualDensity.adaptivePlatformDensity,
    fontFamily: AppFonts.interFontFamily,
  ).copyWith(splashFactory: NoSplash.splashFactory);
}
