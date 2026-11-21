import 'package:material_ui/material_ui.dart';
import 'package:kafkalyzer/l10n/app_localizations.dart';
import 'package:kafkalyzer/src/dependency_injection.dart';
import 'package:kafkalyzer/src/services/appearance_settings.dart';
import 'package:kafkalyzer/src/services/time_display_settings.dart';
import 'package:kafkalyzer/src/features/settings/presentation/widgets/section_reset_confirmation.dart';

class SettingsAppearanceSection extends StatelessWidget {
  final AppLocalizations l10n;

  const SettingsAppearanceSection({super.key, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final appearance = getIt.isRegistered<AppearanceSettings>()
        ? getIt<AppearanceSettings>()
        : AppearanceSettings();
    final timeDisplay = getIt.isRegistered<TimeDisplaySettings>()
        ? getIt<TimeDisplaySettings>()
        : TimeDisplaySettings.fallback;

    return AnimatedBuilder(
      animation: Listenable.merge([appearance, timeDisplay]),
      builder: (context, _) {
        final isCustomScale = !AppearanceSettings.textScalePresets.any(
          (p) => (p - appearance.textScale).abs() < 0.001,
        );
        final scaleEntries = <DropdownMenuEntry<double>>[
          for (final preset in AppearanceSettings.textScalePresets)
            DropdownMenuEntry<double>(
              value: preset,
              label: '${(preset * 100).round()}%',
            ),
          if (isCustomScale)
            DropdownMenuEntry<double>(
              value: appearance.textScale,
              label: l10n.textSizeCustom((appearance.textScale * 100).round()),
            ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.appearanceSectionTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  key: const Key('reset_appearance_button'),
                  onPressed: () => confirmSectionReset(
                    context,
                    l10n,
                    l10n.appearanceSectionTitle,
                    () async {
                      await appearance.resetToDefaults();
                      timeDisplay.setMode(TimeDisplayMode.local);
                    },
                  ),
                  child: Text(l10n.resetToDefaults),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 16,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.themeLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<ThemeMode>(
                      key: const Key('appearance_theme_selector'),
                      segments: [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text(l10n.themeSystem),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text(l10n.themeLight),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text(l10n.themeDark),
                        ),
                      ],
                      selected: {appearance.themeMode},
                      onSelectionChanged: (sel) {
                        appearance.setThemeMode(sel.first);
                      },
                    ),
                  ],
                ),
                DropdownMenu<String>(
                  key: const Key('appearance_language_dropdown'),
                  label: Text(l10n.languageLabel),
                  initialSelection: appearance.locale?.languageCode ?? 'system',
                  dropdownMenuEntries: [
                    DropdownMenuEntry(
                      value: 'system',
                      label: l10n.languageSystem,
                    ),
                    DropdownMenuEntry(value: 'en', label: l10n.languageEnglish),
                    DropdownMenuEntry(value: 'de', label: l10n.languageGerman),
                  ],
                  onSelected: (val) {
                    if (val == null || val == 'system') {
                      appearance.setLocale(null);
                    } else {
                      appearance.setLocale(Locale(val));
                    }
                  },
                ),
                DropdownMenu<double>(
                  key: const Key('appearance_text_scale_dropdown'),
                  label: Text(l10n.textSizeLabel),
                  initialSelection: appearance.textScale,
                  dropdownMenuEntries: scaleEntries,
                  onSelected: (val) {
                    if (val != null) {
                      appearance.setTextScale(val);
                    }
                  },
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.timeDisplayLabel,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<TimeDisplayMode>(
                      key: const Key('appearance_time_display_selector'),
                      segments: [
                        ButtonSegment(
                          value: TimeDisplayMode.local,
                          label: Text(l10n.timeDisplayLocal),
                        ),
                        ButtonSegment(
                          value: TimeDisplayMode.utc,
                          label: Text(l10n.timeDisplayUtc),
                        ),
                      ],
                      selected: {timeDisplay.value},
                      onSelectionChanged: (sel) {
                        timeDisplay.setMode(sel.first);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
