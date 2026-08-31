## 1. Localization

- [x] 1.1 Add localized labels for sort fields (timestamp, partition, offset, key, value) and generalize ascending/descending tooltips so they are not timestamp-only; verify keys via `AppLocalizations` in EN and DE

## 2. Sort field state and comparison

- [x] 2.1 Add per-view sort-field state to `MessagesView`, load/save via `message_sort_field_<view>` (`timestamp`/`partition`/`offset`/`key`/`value`, default `timestamp`), and verify missing/invalid values resolve to timestamp
- [x] 2.2 Update `_updateFilters()` comparator to sort by the active field with null key/payload treated as empty; verify ascending/descending for timestamp, offset, and at least one string field

## 3. Toolbar control

- [x] 3.1 Add a sort-field selector in the results toolbar, place **all** sorting controls (field selector then ascending/descending toggle) **before** the view-mode switcher, wire field changes to update state and persist for the active view type, and verify toolbar order plus independent per-view field restore when switching views

## 4. Tests

- [x] 4.1 Extend `test/src/ui/messages/messages_view_test.dart` for default timestamp field, field persistence per view, and ordering by a non-timestamp field; verify with `flutter test test/src/ui/messages/`
