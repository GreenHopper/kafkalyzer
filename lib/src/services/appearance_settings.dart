import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds and persists appearance preferences: theme mode, UI language, and text scale.
///
/// Loaded once before `runApp` so the first rendered frame matches stored settings
/// without a light/dark flash.
class AppearanceSettings extends ChangeNotifier {
  static const String themeModeKey = 'appearance_theme_mode';
  static const String localeKey = 'appearance_locale';
  static const String textScaleKey = 'appearance_text_scale';
  static const String legacyThemeKey = 'theme_mode';

  static const double minTextScale = 0.8;
  static const double maxTextScale = 1.5;
  static const double defaultTextScale = 1.0;

  static const List<double> textScalePresets = [0.8, 0.9, 1.0, 1.1, 1.25, 1.5];

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  double _textScale = defaultTextScale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  double get textScale => _textScale;

  /// Loads appearance settings from [SharedPreferences], falling back to defaults
  /// on missing, wrong-type, or out-of-range values without rewriting storage.
  Future<void> load([SharedPreferences? prefsOverride]) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();

    _themeMode = _readThemeMode(prefs);
    _locale = _readLocale(prefs);
    _textScale = _readTextScale(prefs);

    notifyListeners();
  }

  ThemeMode _readThemeMode(SharedPreferences prefs) {
    final raw = prefs.get(themeModeKey);
    if (raw is String) {
      switch (raw) {
        case 'system':
          return ThemeMode.system;
        case 'light':
          return ThemeMode.light;
        case 'dark':
          return ThemeMode.dark;
        default:
          return ThemeMode.system;
      }
    }
    if (raw != null) {
      return ThemeMode.system;
    }

    // Legacy boolean key fallback (read-only; never written or deleted)
    final legacy = prefs.get(legacyThemeKey);
    if (legacy is bool) {
      return legacy ? ThemeMode.dark : ThemeMode.light;
    }
    return ThemeMode.system;
  }

  Locale? _readLocale(SharedPreferences prefs) {
    final raw = prefs.get(localeKey);
    if (raw is String) {
      switch (raw) {
        case 'en':
          return const Locale('en');
        case 'de':
          return const Locale('de');
        case 'system':
        default:
          return null;
      }
    }
    return null;
  }

  double _readTextScale(SharedPreferences prefs) {
    final raw = prefs.get(textScaleKey);
    if (raw is num) {
      final val = raw.toDouble();
      if (val.isFinite && val >= minTextScale && val <= maxTextScale) {
        return val;
      }
    }
    return defaultTextScale;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode.name);
  }

  Future<void> setLocale(Locale? locale) async {
    final normalized =
        (locale?.languageCode == 'en' || locale?.languageCode == 'de')
        ? Locale(locale!.languageCode)
        : null;
    _locale = normalized;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(localeKey, normalized?.languageCode ?? 'system');
  }

  Future<void> setTextScale(double scale) async {
    final valid =
        scale.isFinite && scale >= minTextScale && scale <= maxTextScale
        ? scale
        : defaultTextScale;
    _textScale = valid;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(textScaleKey, valid);
  }

  Future<void> toggleBrightness(Brightness shownBrightness) async {
    final next = shownBrightness == Brightness.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    await setThemeMode(next);
  }

  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _locale = null;
    _textScale = defaultTextScale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, ThemeMode.system.name);
    await prefs.setString(localeKey, 'system');
    await prefs.setDouble(textScaleKey, defaultTextScale);
  }
}
