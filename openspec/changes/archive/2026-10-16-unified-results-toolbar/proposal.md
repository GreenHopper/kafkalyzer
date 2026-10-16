# Proposal

## Why

In `MessagesView`, the results toolbar contains subtle UX friction points that cause cognitive overload and confusion for users:
1. **Search Field Ambiguity**: The in-memory filter field is ambiguously labeled `Suchergebnisse...` / `Search results...`, leading users to confuse it with the server-side Kafka fetch/scan filter above. Users do not immediately see that it filters locally loaded messages in-memory, nor how many total messages are loaded.
2. **Redundant Sort Dropdowns in Table View**: When `MessagesView` is in `table` view, the toolbar displays both the `message_sort_field_selector` dropdown (`Timestamp ▼`) and the table's native interactive column headers. Sorting by a table column does not update the dropdown above, creating a disjointed dual-sort experience. The dropdown is only needed in non-column views like `timeline` and `diff`.
3. **Unlabeled View Switcher Buttons**: The `ViewModeSwitcher` renders only icon buttons (`table_chart`, `view_list`, `difference`, `data_object`) without text labels, reducing discoverability for new users.

Resolving these issues aligns `MessagesView` with Measure 4 of `design/ui_ux_audit_und_onboarding_konzept.md` by clarifying data boundaries, streamlining sort controls, and improving view mode ergonomics.

## What Changes

1. **Explicit In-Result Search Wording & Loaded Count**:
   - Update `MessageSearchBar` to dynamically display the total loaded message count in its hint/placeholder (e.g., `Filter in 200 loaded messages...` / `In 200 geladenen Nachrichten filtern...`).
   - Clearly display the active result count and total loaded message count (e.g., `14 of 200 matches` / `200 loaded messages`).
2. **Context-Aware Sort Controls**:
   - Hide the redundant `message_sort_field_selector` and `message_sort_order_toggle` from the toolbar when `_activeView == 'table'` (since `MessagesTableView` provides native column header sorting).
   - Display the sort controls when `_activeView` is `timeline` or `diff`, where table column headers are absent.
3. **Labeled View Mode Switcher**:
   - Refactor `ViewModeSwitcher` to include clear, localized text labels alongside or inside the toggle options (e.g., `Table` / `Tabelle`, `Timeline` / `Zeitverlauf`, `Diff` / `Vergleich`, `Schema`).
4. **Complete Localization**:
   - Add localized strings for view modes, dynamic search bar placeholders, and message count status in `app_en.arb` and `app_de.arb`.

## Capabilities

### New Capabilities
- `unified-results-toolbar`: Provides an ergonomic, context-aware results toolbar in `MessagesView` with explicit in-memory search placeholders, loaded message count badges, context-sensitive sort controls, and labeled view mode buttons.

### Modified Capabilities
<!-- None: existing capability specs do not require modified requirement definitions -->

## Impact

- **Frontend UI**:
  - `lib/src/ui/messages/messages_view.dart`: Conditional rendering of sort controls and passing message counts to the toolbar.
  - `lib/src/ui/messages/widgets/message_search_bar.dart`: Support for total message count, dynamic placeholder, and match counter.
  - `lib/src/ui/messages/widgets/view_mode_switcher.dart`: Addition of text labels and responsive layout.
  - `lib/l10n/app_en.arb` & `lib/l10n/app_de.arb`: Localized strings.
- **Tests**:
  - `test/src/ui/messages/messages_view_test.dart` and component widget tests.
