# Proposal

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.4 `command-palette` (M), conflict note §2.3
no. 14, phase 1b (§6.1). Guardrails L1, L5 and L6 apply.

## Why

Reaching a known object takes several pointer steps today. To open a topic, the user scrolls or filters the Explorer
sidebar. To see one consumer group, the user switches to Consumer Lag, types into its search field and expands a
tile. To run a script, the user switches to Scripts and picks it from the list. The only keyboard entry point is Quick
Jump (`Ctrl+G`/`Cmd+G`). It accepts only a pasted `kafkalyzer://` reference, works only while focus is inside the
Explorer, and cannot find anything by name. A command palette lets the user find all of these by name from anywhere
in the main window, using only the keyboard.

## What Changes

- `Ctrl+K` (Linux/Windows) / `Cmd+K` (macOS) opens a command palette from any of the four destinations, even when
  focus is outside the Explorer. It does not open over another dialog, and the shortcut does not open a second
  palette. On macOS, `Ctrl+K` inside a text field stays the native "delete to end of line" command. `Cmd+K` always
  opens the palette.
- The palette fuzzy-searches only lists that are already in memory:
  - cluster profiles: connects, or switches to the Explorer if the profile is already active;
  - topics of the active cluster: opens the topic tab, or focuses it if it is already open;
  - consumer groups that the Consumer Lag view loaded for the active cluster in this session: switches to Consumer
    Lag and opens that group's details;
  - saved scripts: switches to Scripts and opens the script's Run tab. The script is never started;
  - the four navigation destinations.
  Typing never makes a network call. If no consumer groups are loaded yet, the palette says so and does not fetch
  them.
- Keyboard-only use: arrow keys move the highlight, `Enter` runs the highlighted entry, `Escape` closes. Every row
  shows its kind as text and an icon, not only as a colour.
- Relation to Quick Jump: both stay. The palette finds things by name. Quick Jump resolves pasted references and
  keeps `Ctrl+G`/`Cmd+G` and its behaviour. If the palette query is a valid `kafkalyzer://` reference, the palette
  shows one entry that opens Quick Jump with the reference already filled in.
- Fix for the conflict in §2.3 no. 14: the message view's letter shortcuts `J`, `K` and `F` fire only when no
  `Ctrl`, `Cmd` or `Alt` key is held. Today `Ctrl+K` with an open inspector would also step to the previous message.
- The palette shortcut is registered in the central shortcut catalogue `AppShortcuts`
  (`app-diagnostics-and-error-reporting`), so it appears in the `F1` overview. The catalogue's collision check covers
  it.
- To support this: a small navigation controller that replaces `MainLayout`'s private destination index, and an
  in-memory record of the consumer group ids the Consumer Lag view last loaded for each cluster. The record lives only
  for the session (consistent with E17).

## Capabilities

### New Capabilities
- `command-palette`: opening the palette (shortcut, text-field and dialog rules), its sources and the action for each
  kind of entry, fuzzy matching and ranking, keyboard-only operation, the hand-off to Quick Jump, and the "in-memory
  lists only" rule.

### Modified Capabilities
- `keyboard-shortcuts` (new in `app-diagnostics-and-error-reporting`, not yet in `openspec/specs/`): no delta. The
  palette entry is added to the catalogue under that capability's existing rules. The `command-palette` spec requires
  this.

Not modified: `main-navigation`. The rail keeps exactly four destinations, and the palette only selects them.
`shareable-message-references`: Quick Jump keeps its shortcut and behaviour. `message-inspector-shell`: the
modifier rule for `J`/`K`/`F` is specified in `command-palette` (a `Ctrl+K`/`Cmd+K` press must not step messages),
because `message-selection-copy-and-display` already rewrites that requirement block, and a second rewrite would
conflict at archive time.

## Impact

- **Dart only** (`features/navigation`, as in the roadmap): new `lib/src/features/navigation/command_palette/`
  (fuzzy matcher, entry sources, dialog), new `MainNavigationController`, new `ConsumerGroupDirectory` (in-memory),
  `lib/src/ui/main_layout.dart` (destination state, `Ctrl/Cmd+K` handler), `consumer_lag_view.dart` (records loaded
  group ids, reveals a requested group), `script_manager_view.dart` (selects a requested script on the Run tab),
  `quick_jump_dialog.dart` (optional initial input), `messages_view.dart` (modifier guard),
  `lib/src/ui/shortcuts/app_shortcuts.dart` (one entry), `dependency_injection.dart`, en+de ARB.
- **No Rust, no bridge, no new dependency.** The fuzzy matcher is a small Dart function.
- **Read-only impact:** no new Kafka or Schema Registry calls. Connecting to a profile and opening a topic use the
  existing `ActiveConnectionController.connect`/`openTopic` paths. Switching to Consumer Lag starts the same fetch
  the view starts when the user clicks the rail today. `scripts/check_read_only.sh` must pass unchanged.
- **Prerequisites (implement first):** `app-diagnostics-and-error-reporting` (§5.25). It provides `AppShortcuts`,
  `ShortcutEntry`, the `F1` overview and `lib/src/ui/focus_utils.dart` (`isTextInputFocused`). The Phase 0 changes
  (`restore-tls-verification`, `harden-local-storage-and-imports`, `harden-read-only-gate`,
  `fix-consumer-lag-accuracy`, `fix-result-view-defects`) do not overlap functionally but go first (E14).
- **Coordination:** `message-selection-copy-and-display` (§5.27) extends the same `messages_view` key handler and
  uses `Ctrl/Cmd+F`. The palette uses `K`, so the two do not collide. The modifier guard must keep 5.27's
  `Ctrl/Cmd+F`/`Ctrl/Cmd+C` branches working. `cluster-profile-ergonomics` (§5.26) may later show the environment tag on
  profile rows; this change does not need it. `accessibility-and-l10n-sweep` (§5.32) reviews semantics afterwards.

## Non-Goals

- Running commands that change state beyond navigation: no script start, no export, no disconnect, no settings
  toggles from the palette.
- Searching message contents, schema subjects or saved searches; fetching any list on demand (topics of inactive
  clusters, consumer groups that are not loaded).
- Merging Quick Jump into the palette or changing `Ctrl+G`/`Cmd+G`. Making Quick Jump work outside the Explorer and
  its partition/offset seek gap (see design) are not part of this change.
- User-configurable key bindings; a history or "recently used" ranking; a fifth navigation destination (L6).
