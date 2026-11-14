import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../l10n/app_localizations.dart';

/// UI scope in which a [ShortcutEntry] is active.
enum ShortcutContext {
  global,
  explorer,
  scripts,
  messages,
  inspector,
  inspectorSearch,
}

extension ShortcutContextL10n on ShortcutContext {
  String label(AppLocalizations l10n) => switch (this) {
    ShortcutContext.global => l10n.shortcutContextGlobal,
    ShortcutContext.explorer => l10n.shortcutContextExplorer,
    ShortcutContext.scripts => l10n.shortcutContextScripts,
    ShortcutContext.messages => l10n.shortcutContextMessages,
    ShortcutContext.inspector => l10n.shortcutContextInspector,
    ShortcutContext.inspectorSearch => l10n.shortcutContextInspectorSearch,
  };
}

/// Platform-independent key combination used by [ShortcutEntry].
///
/// Set [primaryModifier] to represent `⌘` on macOS and `Ctrl` on Linux/Windows.
/// [toActivators] expands [primaryModifier] into both `control: true` and
/// `meta: true` [SingleActivator]s so bindings work uniformly across platforms,
/// matching the existing `CallbackShortcuts` behaviour in the app.
@immutable
class ShortcutKey {
  const ShortcutKey(
    this.key, {
    this.primaryModifier = false,
    this.shift = false,
    this.alt = false,
    this.displayLabel,
  });

  final LogicalKeyboardKey key;
  final bool primaryModifier;
  final bool shift;
  final bool alt;

  /// Optional display override (for example `'?'` when matched by character
  /// rather than a single physical key).
  final String? displayLabel;

  /// Expands this key combination into Flutter [SingleActivator] instances.
  List<SingleActivator> toActivators() {
    if (primaryModifier) {
      return [
        SingleActivator(key, control: true, shift: shift, alt: alt),
        SingleActivator(key, meta: true, shift: shift, alt: alt),
      ];
    }
    return [SingleActivator(key, shift: shift, alt: alt)];
  }

  /// Canonical collision key used by [validateShortcutCatalogue] to detect
  /// duplicate bindings within a context or against [ShortcutContext.global].
  String get signature =>
      '${key.keyId}:p=$primaryModifier:s=$shift:a=$alt:d=${displayLabel ?? ''}';

  /// Formats this key combination for human display using [l10n] and
  /// [platform].
  String format(AppLocalizations l10n, TargetPlatform platform) {
    final isMac = platform == TargetPlatform.macOS;
    final keyText = displayLabel ?? _formatKeyName(key, l10n);
    final parts = <String>[];
    if (primaryModifier) {
      parts.add(isMac ? '⌘' : 'Ctrl');
    }
    if (alt) {
      parts.add(isMac ? '⌥' : 'Alt');
    }
    if (shift) {
      parts.add(l10n.shortcutKeyShift);
    }
    if (isMac && primaryModifier && !shift && !alt) {
      return '⌘$keyText';
    }
    parts.add(keyText);
    return parts.join('+');
  }

  static String _formatKeyName(LogicalKeyboardKey key, AppLocalizations l10n) {
    if (key == LogicalKeyboardKey.escape) return l10n.shortcutKeyEscape;
    if (key == LogicalKeyboardKey.enter) return l10n.shortcutKeyEnter;
    if (key == LogicalKeyboardKey.arrowDown) return l10n.shortcutKeyArrowDown;
    if (key == LogicalKeyboardKey.arrowUp) return l10n.shortcutKeyArrowUp;
    final label = key.keyLabel;
    if (label.isEmpty) return key.debugName ?? '';
    return label.length == 1 ? label.toUpperCase() : label;
  }

  @override
  bool operator ==(Object other) =>
      other is ShortcutKey && other.signature == signature;

  @override
  int get hashCode => signature.hashCode;
}

/// A single catalogued application shortcut.
@immutable
class ShortcutEntry {
  const ShortcutEntry({
    required this.id,
    required this.context,
    required this.keys,
    required this.description,
  });

  final String id;
  final ShortcutContext context;
  final List<ShortcutKey> keys;
  final String Function(AppLocalizations l10n) description;

  /// All [SingleActivator]s across every [ShortcutKey] in [keys].
  List<SingleActivator> get activators => [
    for (final k in keys) ...k.toActivators(),
  ];

  /// Builds a `Map<ShortcutActivator, VoidCallback>` binding every activator of
  /// this entry to [onInvoke] for use with [CallbackShortcuts].
  Map<ShortcutActivator, VoidCallback> bind(VoidCallback onInvoke) => {
    for (final activator in activators) activator: onInvoke,
  };

  /// Returns `true` when [key] matches any [ShortcutKey] in [keys].
  bool matchesLogicalKey(LogicalKeyboardKey key) =>
      keys.any((k) => k.key == key);
}

/// Central catalogue of all application keyboard shortcuts.
///
/// How sibling changes register new shortcuts:
/// 1. Add a localized description getter to `lib/l10n/app_en.arb` and
///    `lib/l10n/app_de.arb` and run `flutter gen-l10n`.
/// 2. Declare a `static const ShortcutEntry` on [AppShortcuts] with a unique
///    `id`, its [ShortcutContext], its [ShortcutKey] list, and the l10n
///    description callback, then append it to [AppShortcuts.all].
/// 3. Bind the view's `CallbackShortcuts` / key handler directly to that entry
///    (for example `...AppShortcuts.myEntry.bind(handler)`) so the binding and
///    the `F1` / `?` shortcut overview cannot drift.
/// 4. Run `flutter test test/src/ui/shortcuts/app_shortcuts_test.dart` to
///    verify unique IDs, no context/global collisions, and non-empty `en`/`de`
///    labels.
abstract final class AppShortcuts {
  static final ShortcutEntry toggleExplorerSidebar = ShortcutEntry(
    id: 'explorer.toggle_sidebar',
    context: ShortcutContext.explorer,
    keys: const [ShortcutKey(LogicalKeyboardKey.keyB, primaryModifier: true)],
    description: (l10n) => l10n.shortcutToggleSidebar,
  );

  static final ShortcutEntry quickJump = ShortcutEntry(
    id: 'explorer.quick_jump',
    context: ShortcutContext.explorer,
    keys: const [ShortcutKey(LogicalKeyboardKey.keyG, primaryModifier: true)],
    description: (l10n) => l10n.shortcutQuickJump,
  );

  static final ShortcutEntry toggleScriptsSidebar = ShortcutEntry(
    id: 'scripts.toggle_sidebar',
    context: ShortcutContext.scripts,
    keys: const [ShortcutKey(LogicalKeyboardKey.keyB, primaryModifier: true)],
    description: (l10n) => l10n.shortcutToggleSidebar,
  );

  static final ShortcutEntry nextMessage = ShortcutEntry(
    id: 'messages.next_message',
    context: ShortcutContext.messages,
    keys: const [
      ShortcutKey(LogicalKeyboardKey.keyJ),
      ShortcutKey(LogicalKeyboardKey.arrowDown),
    ],
    description: (l10n) => l10n.shortcutNextMessage,
  );

  static final ShortcutEntry previousMessage = ShortcutEntry(
    id: 'messages.previous_message',
    context: ShortcutContext.messages,
    keys: const [
      ShortcutKey(LogicalKeyboardKey.keyK),
      ShortcutKey(LogicalKeyboardKey.arrowUp),
    ],
    description: (l10n) => l10n.shortcutPreviousMessage,
  );

  static final ShortcutEntry toggleFocusMode = ShortcutEntry(
    id: 'messages.toggle_focus_mode',
    context: ShortcutContext.messages,
    keys: const [ShortcutKey(LogicalKeyboardKey.keyF)],
    description: (l10n) => l10n.shortcutToggleFocusMode,
  );

  static final ShortcutEntry closeInspectorOrExitFocus = ShortcutEntry(
    id: 'inspector.close_or_exit_focus',
    context: ShortcutContext.inspector,
    keys: const [ShortcutKey(LogicalKeyboardKey.escape)],
    description: (l10n) => l10n.shortcutCloseInspectorOrExitFocus,
  );

  static final ShortcutEntry nextSearchMatch = ShortcutEntry(
    id: 'inspector_search.next_match',
    context: ShortcutContext.inspectorSearch,
    keys: const [ShortcutKey(LogicalKeyboardKey.enter)],
    description: (l10n) => l10n.shortcutNextSearchMatch,
  );

  static final ShortcutEntry previousSearchMatch = ShortcutEntry(
    id: 'inspector_search.previous_match',
    context: ShortcutContext.inspectorSearch,
    keys: const [ShortcutKey(LogicalKeyboardKey.enter, shift: true)],
    description: (l10n) => l10n.shortcutPreviousSearchMatch,
  );

  static final ShortcutEntry closeInspectorSearch = ShortcutEntry(
    id: 'inspector_search.close',
    context: ShortcutContext.inspectorSearch,
    keys: const [ShortcutKey(LogicalKeyboardKey.escape)],
    description: (l10n) => l10n.shortcutCloseInspectorSearch,
  );

  static final ShortcutEntry showOverview = ShortcutEntry(
    id: 'global.show_overview',
    context: ShortcutContext.global,
    keys: const [
      ShortcutKey(LogicalKeyboardKey.f1),
      ShortcutKey(LogicalKeyboardKey.question, displayLabel: '?'),
    ],
    description: (l10n) => l10n.shortcutShowOverview,
  );

  /// Every registered shortcut in display order.
  static final List<ShortcutEntry> all = [
    showOverview,
    toggleExplorerSidebar,
    quickJump,
    toggleScriptsSidebar,
    nextMessage,
    previousMessage,
    toggleFocusMode,
    closeInspectorOrExitFocus,
    nextSearchMatch,
    previousSearchMatch,
    closeInspectorSearch,
  ];
}

/// Validates [entries] for unique IDs, no key collisions within the same
/// [ShortcutContext] or against [ShortcutContext.global], and non-empty
/// localized descriptions across all [localizations].
///
/// Returns a list of human-readable violation strings (empty if valid).
List<String> validateShortcutCatalogue(
  List<ShortcutEntry> entries,
  List<AppLocalizations> localizations,
) {
  final errors = <String>[];
  final seenIds = <String>{};
  final byContext = <ShortcutContext, Map<String, String>>{};
  final globalKeys = <String, String>{};

  for (final entry in entries) {
    if (!seenIds.add(entry.id)) {
      errors.add('Duplicate shortcut id: ${entry.id}');
    }
    if (entry.keys.isEmpty) {
      errors.add('Shortcut ${entry.id} has no keys declared');
    }
    for (final l10n in localizations) {
      if (entry.description(l10n).trim().isEmpty) {
        errors.add(
          'Shortcut ${entry.id} has empty description for ${l10n.localeName}',
        );
      }
    }

    final contextMap = byContext.putIfAbsent(entry.context, () => {});
    for (final key in entry.keys) {
      final sig = key.signature;
      final existingSame = contextMap[sig];
      if (existingSame != null) {
        errors.add(
          'Key collision in ${entry.context.name}: ${entry.id} conflicts with $existingSame ($sig)',
        );
      } else {
        contextMap[sig] = entry.id;
      }

      if (entry.context == ShortcutContext.global) {
        globalKeys[sig] = entry.id;
        for (final otherEntry in entries) {
          if (otherEntry.context == ShortcutContext.global) continue;
          if (otherEntry.keys.any((k) => k.signature == sig)) {
            errors.add(
              'Global shortcut ${entry.id} conflicts with ${otherEntry.id} ($sig)',
            );
          }
        }
      } else {
        final existingGlobal = globalKeys[sig];
        if (existingGlobal != null) {
          errors.add(
            'Shortcut ${entry.id} conflicts with global shortcut $existingGlobal ($sig)',
          );
        }
      }
    }
  }
  return errors;
}
