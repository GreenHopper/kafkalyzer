import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kafkalyzer/l10n/app_localizations_de.dart';
import 'package:kafkalyzer/l10n/app_localizations_en.dart';
import 'package:kafkalyzer/src/ui/shortcuts/app_shortcuts.dart';

void main() {
  final l10ns = [AppLocalizationsEn(), AppLocalizationsDe()];

  test(
    'catalogue has unique ids, no collisions, and non-empty en/de labels',
    () {
      final errors = validateShortcutCatalogue(AppShortcuts.all, l10ns);
      expect(errors, isEmpty);
      expect(AppShortcuts.all.length, greaterThanOrEqualTo(11));
    },
  );

  test(
    'validateShortcutCatalogue rejects duplicate activator in same context',
    () {
      final conflicting = [
        ...AppShortcuts.all,
        ShortcutEntry(
          id: 'explorer.duplicate_b',
          context: ShortcutContext.explorer,
          keys: const [
            ShortcutKey(LogicalKeyboardKey.keyB, primaryModifier: true),
          ],
          description: (l10n) => l10n.shortcutToggleSidebar,
        ),
      ];

      final errors = validateShortcutCatalogue(conflicting, l10ns);
      expect(errors, isNotEmpty);
      expect(errors.first, contains('explorer.duplicate_b'));
      expect(errors.first, contains('explorer.toggle_sidebar'));
    },
  );

  test('validateShortcutCatalogue rejects collision with global context', () {
    final conflicting = [
      ...AppShortcuts.all,
      ShortcutEntry(
        id: 'messages.conflict_f1',
        context: ShortcutContext.messages,
        keys: const [ShortcutKey(LogicalKeyboardKey.f1)],
        description: (l10n) => l10n.shortcutShowOverview,
      ),
    ];

    final errors = validateShortcutCatalogue(conflicting, l10ns);
    expect(errors, isNotEmpty);
    expect(errors.first, contains('messages.conflict_f1'));
    expect(errors.first, contains('global.show_overview'));
  });

  test('ShortcutKey.format renders macOS vs Linux modifiers', () {
    const key = ShortcutKey(LogicalKeyboardKey.keyB, primaryModifier: true);
    final en = AppLocalizationsEn();
    expect(key.format(en, TargetPlatform.macOS), '⌘B');
    expect(key.format(en, TargetPlatform.linux), 'Ctrl+B');
  });
}
