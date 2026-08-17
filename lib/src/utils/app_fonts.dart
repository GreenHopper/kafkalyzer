import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

final bool isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class AppFonts {
  static TextStyle robotoMono({
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextBaseline? textBaseline,
  }) {
    if (isTest) {
      return TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        color: color,
        backgroundColor: backgroundColor,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
        textBaseline: textBaseline,
      );
    }
    return GoogleFonts.robotoMono(
      fontSize: fontSize,
      color: color,
      backgroundColor: backgroundColor,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      textBaseline: textBaseline,
    );
  }

  static TextStyle roboto({
    double? fontSize,
    Color? color,
    Color? backgroundColor,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? height,
    TextBaseline? textBaseline,
  }) {
    if (isTest) {
      return TextStyle(
        fontFamily: 'sans-serif',
        fontSize: fontSize,
        color: color,
        backgroundColor: backgroundColor,
        fontWeight: fontWeight,
        fontStyle: fontStyle,
        letterSpacing: letterSpacing,
        height: height,
        textBaseline: textBaseline,
      );
    }
    return GoogleFonts.roboto(
      fontSize: fontSize,
      color: color,
      backgroundColor: backgroundColor,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      letterSpacing: letterSpacing,
      height: height,
      textBaseline: textBaseline,
    );
  }

  static String? get interFontFamily {
    if (isTest) return 'sans-serif';
    return GoogleFonts.inter().fontFamily;
  }
}
