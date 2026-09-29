## 1. Localization

- [x] 1.1 Add `searchConfigurationTitle`, `collapseSearchConfiguration`, and `expandSearchConfiguration` to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, regenerate localizations, and verify the new getters appear on `AppLocalizations`

## 2. Search Configuration Header Affordance

- [x] 2.1 In `TopicDetailView._buildSettings`, track expansion with local state (default expanded), wire `onExpansionChanged`, and replace the tune-only trailing with a stateful expand/collapse chevron (optionally keep a decorative leading/title filter cue) — verify the expanded state shows a collapse chevron and filter controls remain visible
- [x] 2.2 Wrap the Search Configuration header toggle with a localized expand/collapse tooltip driven by expansion state, and replace the hardcoded title with `searchConfigurationTitle` — verify tooltips and title resolve from `AppLocalizations`

## 3. Tests and Verification

- [x] 3.1 Add a widget test that expands/collapses the Search Configuration panel via the header and asserts chevron state plus filter visibility for both states — verify with `flutter test test/src/features/topic/`
- [x] 3.2 Run `dart analyze` on touched Dart files and confirm no new issues
