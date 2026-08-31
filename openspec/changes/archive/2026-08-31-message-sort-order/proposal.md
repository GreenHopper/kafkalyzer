## Why

Displayed Kafka messages are always ordered ascending by timestamp (oldest first). Users who primarily want the newest message must scroll to the bottom of every result set, which is confusing and slow. A visible, persistent sort-order control in the results toolbar fixes this.

## What Changes

- **Sort order control**: Add a control to the bar above the message result display that shows the current chronological sort order (ascending vs descending) and lets the user switch it.
- **Default to descending**: New sessions and first-time users get descending order (newest messages first) as the default for each view type.
- **Preference persistence per view type**: Persist the chosen sort order in user preferences (`SharedPreferences`) **per selected view mode** (timeline, table, diff, schema). Switching view modes restores that mode’s last sort order across sessions and result reloads.
- **Apply across message views**: Apply the selected chronological order to the shared message result views that currently force ascending timestamp order (timeline and related views driven by `MessagesView`).

## Capabilities

### New Capabilities
- `message-sort-order`: Chronological sort-order control for displayed Kafka messages in the shared results UI, including per-view-type preference persistence and a descending default.

### Modified Capabilities
<!-- None -->

## Impact

- **Affected code**:
  - `lib/src/ui/messages/messages_view.dart`: Own sort-order state keyed by active view mode, preference load/save per view type, and sorting of cached message lists.
  - Results toolbar widgets under `lib/src/ui/messages/widgets/` (e.g. alongside `ViewModeSwitcher` / `MessageSearchBar`): Add the sort-order control.
  - Possibly `messages_timeline_view.dart` / `messages_diff_view.dart` / `messages_table_view.dart` if they re-sort independently.
  - Localization (`.arb` files) for control labels/tooltips.
  - Widget tests in `test/src/ui/messages/`.
- **Dependencies**: No new packages; reuse `shared_preferences` and existing Material UI patterns.
- **APIs**: No Rust/bridge or Kafka consumer API changes; sorting is a presentation concern only.
