## 1. Localization

- [x] 1.1 Add localized strings for the sort-order control tooltips/labels (ascending and descending) to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, regenerate localizations if required, and verify both locales expose the new keys via `AppLocalizations`

## 2. Sort state and preference

- [x] 2.1 Add ascending/descending sort state to `MessagesView`, defaulting to descending, load/save via SharedPreferences keys `message_sort_order_<view>` (`timeline`/`table`/`diff`/`schema`, values `asc`/`desc`), and verify missing or invalid values resolve to descending per view type
- [x] 2.2 On view-mode change, load that view type’s stored sort order, re-sort, and update the toolbar indicator; verify switching between views restores independent orders
- [x] 2.3 Apply the active view’s order when building `_cachedSortedMessages` in `_updateFilters()`, pass the sorted list to timeline, diff, and table views, and verify toggling rebuilds the list with oldest-first vs newest-first for the active view only

## 3. Toolbar control

- [x] 3.1 Add a sort-order toggle `IconButton` (with localized tooltip and distinct icons for asc/desc) to the results toolbar near the view-mode switcher, wire it to update state and persist preference for the **active** view type, and verify the control reflects the current view’s order and switches it on tap

## 4. Child view consistency

- [x] 4.1 Remove or adjust unconditional ascending re-sorts in child views (e.g. `MessagesDiffView`) so they respect the order supplied by `MessagesView`, and verify timeline and diff both follow their respective toolbar settings

## 5. Tests

- [x] 5.1 Extend `test/src/ui/messages/messages_view_test.dart` (and related tests as needed) to cover default descending per view, toggle + persistence scoped to the active view, independent orders across view types, and display order; verify with `flutter test test/src/ui/messages/`
