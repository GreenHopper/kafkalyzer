import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AppearanceSettings', () {
    test('defaults to system theme, null locale, and 1.0 text scale', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppearanceSettings();
      await settings.load();

      expect(settings.themeMode, ThemeMode.system);
      expect(settings.locale, isNull);
      expect(settings.textScale, 1.0);
    });

    test(
      'reads legacy theme_mode bool when appearance_theme_mode is absent',
      () async {
        SharedPreferences.setMockInitialValues({'theme_mode': true});
        var settings = AppearanceSettings();
        await settings.load();
        expect(settings.themeMode, ThemeMode.dark);

        SharedPreferences.setMockInitialValues({'theme_mode': false});
        settings = AppearanceSettings();
        await settings.load();
        expect(settings.themeMode, ThemeMode.light);

        // Legacy key is not deleted or overwritten
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('theme_mode'), isFalse);
        expect(prefs.getString(AppearanceSettings.themeModeKey), isNull);
      },
    );

    test(
      'ignores wrong types, unknown locale, and out-of-range text scale without rewriting',
      () async {
        SharedPreferences.setMockInitialValues({
          AppearanceSettings.themeModeKey: 123,
          AppearanceSettings.localeKey: 'fr',
          AppearanceSettings.textScaleKey: 7.0,
        });
        final settings = AppearanceSettings();
        await settings.load();

        expect(settings.themeMode, ThemeMode.system);
        expect(settings.locale, isNull);
        expect(settings.textScale, 1.0);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.get(AppearanceSettings.themeModeKey), 123);
        expect(prefs.get(AppearanceSettings.localeKey), 'fr');
        expect(prefs.get(AppearanceSettings.textScaleKey), 7.0);
      },
    );

    test('persists round trip and resets to defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = AppearanceSettings();
      await settings.load();

      await settings.setThemeMode(ThemeMode.dark);
      await settings.setLocale(const Locale('de'));
      await settings.setTextScale(1.25);

      final reloaded = AppearanceSettings();
      await reloaded.load();
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.locale, const Locale('de'));
      expect(reloaded.textScale, 1.25);

      await reloaded.resetToDefaults();
      expect(reloaded.themeMode, ThemeMode.system);
      expect(reloaded.locale, isNull);
      expect(reloaded.textScale, 1.0);
    });
  });
}
