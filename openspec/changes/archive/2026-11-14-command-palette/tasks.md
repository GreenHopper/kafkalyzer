# Tasks

No Rust or bridge work: this change is Dart only (design D1). There are no `cargo` or `flutter_rust_bridge_codegen`
steps.

## 1. Prerequisite check and spikes

- [x] 1.1 Confirm `app-diagnostics-and-error-reporting` is merged: `AppShortcuts`/`ShortcutEntry`/`ShortcutKey`,
  `ShortcutContext.global`, `test/src/ui/shortcuts/app_shortcuts_test.dart`, `lib/src/ui/focus_utils.dart` and the
  `MainLayout` `HardwareKeyboard` handler for `F1`/`?` exist. Also note whether `message-selection-copy-and-display`
  has already changed `_handleInspectorShortcut`. Verify: `flutter test test/src/ui/shortcuts/` is green; record the
  findings in the PR description
- [ ] 1.2 Spike (macOS, manual): in a scratch branch, register a `HardwareKeyboard` handler that returns `true` for
  `Cmd+K` and `false` for `Ctrl+K` while a `TextField` has focus. Check that `Ctrl+K` still deletes to end of line and
  that `Cmd+K` inserts nothing. On Linux (and Windows if available), check that returning `true` for `Ctrl+K` in a
  focused `TextField` inserts nothing. Verify: write the results into design D2 if they differ; discard the branch
- [ ] 1.3 Spike: check that `ExpansionTile(controller: ExpansibleController())` from `material_ui` expands a tile
  that was built off-screen and then scrolled in, or fall back to `initiallyExpanded` with a key on the requested
  group id. Verify: a throwaway widget test; record the choice in design D5

## 2. Shared pieces: fuzzy matcher, navigation controller, group directory

- [x] 2.1 Add `lib/src/features/navigation/command_palette/fuzzy_match.dart` (design D7: case-insensitive
  subsequence, score, matched indices). Verify: `test/src/features/navigation/command_palette/fuzzy_match_test.dart`
  covers `ordevt` → `orders.events`, the ranking `orders` > `orders.events` > `ops-reader-dlq-events`, no match,
  empty query, word-boundary and camel-case bonuses, and non-ASCII names
- [x] 2.2 Add `lib/src/features/navigation/main_navigation_controller.dart` (`MainDestination`, `select`,
  `openConsumerGroup`/`takeConsumerGroupRequest`, `openScript`/`takeScriptRequest`; design D4) and register it in
  `lib/src/dependency_injection.dart`. Verify: a unit test checks that each request is taken exactly once and that
  `select` notifies
- [x] 2.3 Switch `lib/src/ui/main_layout.dart` from `_selectedIndex` to `MainNavigationController` (rail index ⇄
  enum). Verify: `test/src/ui/main_layout_test.dart` stays green unchanged (register the controller in its setup),
  plus one new test: `select(settings)` shows `SettingsView` and marks the rail
- [x] 2.4 Add `lib/src/features/consumer/application/consumer_group_directory.dart` (`record`, `idsFor` with `null` =
  never loaded; memory only) and register it. In `consumer_lag_view.dart`, `_fetchLags` calls `record` only on
  success. Verify: a unit test for the directory, and a widget test with a mocked `KafkaMetadataService` checking that
  a successful fetch records the ids and a failed fetch keeps the previous list

## 3. Localization

- [x] 3.1 Add the en and de keys to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`: shortcut label
  (`shortcutCommandPalette`), palette title and hint, kind labels (destination, cluster, topic, consumer group,
  script, reference), "Open reference in Quick Jump", "active" marker, no results, "{shown} of {total} matches, keep
  typing", "Consumer groups appear after Consumer Lag has loaded them", "Consumer group {id} not found", "Script not
  found", list semantics label. Verify: `flutter gen-l10n` (or the build) succeeds and both files have the same key
  set

## 4. Palette entries and dialog

- [x] 4.1 Add `palette_entry.dart` and `palette_sources.dart`: build entries from injected lists (destinations,
  `ClusterListController.clusters`, `TopicController.getTopics(active)`, `ConsumerGroupDirectory.idsFor(active)`,
  `ScriptController.scripts`, a reference entry when `MessageReference.tryParse` succeeds), then rank and cap at 50
  with the total count (design D7, D9). Verify: unit tests for each spec "Palette Sources" scenario (not connected,
  connected, topic hidden by sidebar filter/internal flag, groups never loaded → note flag, topic list `null` → no
  topics), the empty-query order, the cap with total, and the reference entry ranked first
- [x] 4.2 Add `command_palette_dialog.dart` (design D8): autofocus field, highlighted list, `ArrowUp`/`ArrowDown`
  wrap with `ensureVisible`, `Enter`/tap runs after `Navigator.pop`, `Escape` closes, kind icon plus text label,
  bold matched characters, semantics labels, no-results and cap messages. Verify:
  `test/src/features/navigation/command_palette/command_palette_dialog_test.dart` checks typing that filters, arrow
  navigation, `Enter` running the third entry, `Escape` with no action, the no-results case where `Enter` does
  nothing, and focus restored after close
- [x] 4.3 Add the optional `initialInput` parameter to `QuickJumpDialog`: it pre-fills the field and parses it after
  the first frame. Verify: `quick_jump_dialog_test.dart` stays green, plus one new test where a pre-filled valid
  reference shows the parsed preview and enables "Jump"

## 5. Entry actions in the target views

- [x] 5.1 Wire the destination, cluster and topic actions (design D9: `select`, `connect` only when the profile is
  not active, `openTopic(forceNew: false)` after selecting Explorer). Verify: widget tests with fake controllers
  check that running a cluster entry calls `connect` once and selects Explorer, that the active profile does not
  reconnect, and that a topic entry with an existing tab activates it without adding a tab
- [x] 5.2 `ConsumerLagView`: consume `takeConsumerGroupRequest()` in `initState` and through a controller listener.
  Reset the status filter to "All", put the id into the search field, expand the tile (choice from 1.3), defer the
  reveal until `_fetchLags` completes, and show the "not found" SnackBar when the loaded list lacks the id. Verify:
  widget tests for a reveal after a fresh mount, a reveal while the view is already visible, and the not-found case
- [x] 5.3 `ScriptManagerView`: consume `takeScriptRequest()` in `initState` (before `_attemptRestoreState`) and
  through a listener. Select the script, switch to the Run tab (index 0), and never call `ScriptRunner`. Show
  "Script not found" for an unknown id. Verify: widget tests check that the selected script shows on the Run tab,
  that `ScriptRunner.run…` is never invoked (mock verify), and that a running script stays running when another
  script is opened

## 6. Shortcut binding and conflict fix

- [x] 6.1 Add `AppShortcuts.commandPalette` (`global.commandPalette`, `K` with `primaryModifier`) and append it to
  `AppShortcuts.all`. Verify: `app_shortcuts_test.dart` (unique ids, no collision, en+de labels) is green and the
  overview widget test lists `Ctrl+K` / `⌘K`
- [x] 6.2 Extend the `MainLayout` `HardwareKeyboard` handler (design D2): `KeyDownEvent` only, stop when the route is
  not current, return `false` for macOS `Ctrl+K` while `isTextInputFocused()`, otherwise open the palette and return
  `true`. Verify: widget tests open the palette from each destination, from a focused topic filter (no character
  inserted), with no second palette, with no palette over an open dialog, and with
  `debugDefaultTargetPlatformOverride = TargetPlatform.macOS` keeping `Ctrl+K` in a focused field while `Meta+K` opens
- [x] 6.3 Add the modifier guard in `messages_view.dart` `_handleInspectorShortcut` (design D3): `J`/`K`/`F` act only
  without Ctrl/Meta/Alt, while 5.27's `Ctrl/Cmd+F`/`Ctrl/Cmd+C` branches (if present) keep working. Verify:
  `messages_view_stepper_test.dart` stays green, plus new tests: `Ctrl+K` and `Meta+K` with an open inspector do not
  change the selection, and plain `K` still steps

## 7. Final verification

- [x] 7.1 Run `dart format lib test` (no diff left), `flutter analyze` (no issues), `flutter test` (all green) and
  `scripts/check_read_only.sh` (passes unchanged; this change adds no Kafka or Schema Registry calls). Do not run
  `cargo fmt`/`clippy`/`test` or the bridge codegen, because no Rust or `rust/src/api/` file changed
- [ ] 7.2 Manual smoke test on the desktop build: with no cluster active, `Ctrl/Cmd+K` → a profile connects with a
  progress indicator; a topic opens or focuses its tab; after visiting Consumer Lag once, a group entry expands its
  details; a script entry shows the Run tab without starting; pasting a `kafkalyzer://` link hands off to Quick Jump;
  `F1` lists the palette shortcut

## Workflow follow-up

- After review, archive the change. The new `command-palette` capability is created in `openspec/specs/`.
- If `app-diagnostics-and-error-reporting` is archived after this change, check that `keyboard-shortcuts` exists in
  `openspec/specs/` before this change is archived.
