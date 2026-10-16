# Tasks

## 1. Localization & String Assets

- [x] 1.1 Add localized strings for view modes (`viewModeTable`, `viewModeTimeline`, `viewModeDiff`, `viewModeSchema`, and tooltips) in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- [x] 1.2 Add localized strings for search placeholders and match counts (`filterInLoadedMessages`, `matchesOfTotal`, `loadedMessagesCount`) in `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`.
- [x] 1.3 Run `flutter gen-l10n` to regenerate `AppLocalizations`.

## 2. In-Memory Search Bar Refactoring

- [x] 2.1 Update `MessageSearchBar` in `lib/src/ui/messages/widgets/message_search_bar.dart` to accept `totalCount`.
- [x] 2.2 Update search bar placeholder to use dynamic `filterInLoadedMessages(totalCount)`.
- [x] 2.3 Update match count display to show `matchesOfTotal(matchCount, totalCount)` when search phrase is active, and show total loaded count when empty.

## 3. Context-Aware Sort Controls in `MessagesView`

- [x] 3.1 In `lib/src/ui/messages/messages_view.dart`, pass `widget.messages.length` as `totalCount` to `MessageSearchBar`.
- [x] 3.2 Conditionally render `message_sort_field_selector` and `message_sort_order_toggle` only when `_activeView != 'table'`.
- [x] 3.3 Ensure sorting state remains intact when switching between table and timeline/diff modes.

## 4. Labeled View Mode Switcher

- [x] 4.1 Refactor `ViewModeSwitcher` in `lib/src/ui/messages/widgets/view_mode_switcher.dart` to display localized text labels alongside icons for Table, Timeline, Diff, and Schema view modes.
- [x] 4.2 Adjust padding, constraints, and icon sizing for an ergonomic desktop toolbar appearance without visual overflow.

## 5. Testing & Verification

- [x] 5.1 Update `test/src/ui/messages/widgets/message_search_bar_test.dart` to verify dynamic placeholder, match counter, and total count display.
- [x] 5.2 Update `test/src/ui/messages/widgets/view_mode_switcher_test.dart` to verify labeled view mode segments.
- [x] 5.3 Update `test/src/ui/messages/messages_view_test.dart` to verify sort controls are hidden in Table mode and visible in Timeline/Diff modes.
- [x] 5.4 Run `flutter test` and `dart analyze lib test` to ensure zero regressions and clean static analysis.
