# Design

## Context

See proposal.md (Why) and `specs/command-palette/spec.md` for the required behaviour. Current state, checked in the
code:

- **Destinations.** `lib/src/ui/main_layout.dart` holds the destination in a private `int _selectedIndex` and builds
  the view with a `switch`. Leaving a destination disposes its view state. `go_router` has a single route `/`.
- **Quick Jump** (`lib/src/features/navigation/widgets/quick_jump_dialog.dart`) is not a partial palette. It is a
  single text field that parses a `kafkalyzer://` reference (`MessageReference.tryParse`), picks the cluster (with a
  dropdown if the cluster name is unknown), connects, and opens the topic tab with `openTopic(forceNew: false)`. It
  has no name search and no list. It is bound in `explorer_view.dart` (~107-117) through `CallbackShortcuts`
  (`Ctrl/Cmd+G`, next to `Ctrl/Cmd+B`). The binding only fires while focus is inside the Explorer subtree.
  - Deviation from `shareable-message-references`: the spec calls Quick Jump a "global keyboard shortcut" and
    requires seeking to the partition/offset and selecting the message. The code is Explorer-only, and its default
    path ignores `partition`, `offset` and `filter` (it only opens the topic). This is recorded here and left alone
    (proposal non-goals). The hand-off in D6 reuses Quick Jump as it is.
- **Message view keys.** `messages_view.dart` registers a global `HardwareKeyboard` handler
  (`_handleInspectorShortcut`, ~539-585) while the inspector is open. It compares `event.logicalKey` with `keyJ`,
  `keyK` and `keyF` and does not look at modifiers. Flutter calls every `HardwareKeyboard` handler, and then also the
  focus system's key handler (`KeyEventManager`). So a `Ctrl+K` press would step to the previous message and also
  trigger any palette binding (roadmap §2.3 no. 14). The handler skips letters while an `EditableText` has focus
  (`fix-search-input-shortcut-conflict`) and stops while another route is on top (`ModalRoute.isCurrent`).
- **Text fields and `K`.** Flutter's `DefaultTextEditingShortcuts` has no `K` binding on any platform. On macOS,
  `Ctrl+K` reaches the text field through the native key-binding selector `deleteToEndOfLine:`
  (`intentForMacOSSelector`), after the framework has declined the key. `Cmd+K` has no text meaning.
- **Data in memory.**
  - Cluster profiles: `ClusterListController.clusters`.
  - Topics: `TopicController.getTopics(profile)` returns the cached list or `null` (not loaded or failed) and does
    no I/O. `ActiveConnectionController.topics` additionally applies the sidebar text filter and the
    internal/stream visibility.
  - Scripts: `ScriptController.scripts`, loaded at startup.
  - Consumer groups exist only in `_ConsumerLagViewState._lags`, are fetched when the view mounts
    (`fetchConsumerGroups`), and are lost when the user leaves the view. Per-group lag is loaded lazily when a row is
    built (`_loadGroupLag`).
- **Opening actions that already exist.** `ActiveConnectionController.connect(profile)` shows progress through
  `cluster-connection-progress`. `openTopic(topic:, profile:, forceNew: false)` focuses an existing tab.
  `ScriptManagerView` selects a script through `_selectedScript` and shows the Run tab (index 0). `ScriptRunView`
  never starts a run in `initState`. It only re-attaches to a run that is already in progress.
- **Prerequisite API** (`app-diagnostics-and-error-reporting` D8): `AppShortcuts`/`ShortcutEntry`/`ShortcutKey`
  (`primaryModifier` expands to `control` and `meta`), `ShortcutContext.global`, a catalogue unit test (unique ids,
  no collision within a context or with `global`, en+de labels), and `lib/src/ui/focus_utils.dart`
  (`isTextInputFocused`). Its `MainLayout` `HardwareKeyboard` handler for `F1`/`?` is the model for this change.

## Goals / Non-Goals

**Goals:**
- One global, focus-independent palette shortcut with predictable text-field behaviour.
- Pure, unit-tested matching and ranking. The dialog stays a thin view over it.
- Cross-destination actions without lifting the views' state into new controllers beyond what is needed.

**Non-Goals:**
- A generic `Shortcuts`/`Actions`/intent rewrite of the app.
- Moving consumer lag polling into a controller (`lag-stall-detection-and-alerts`, §5.13).
- Fixing Quick Jump's scope or seek gap.

## Decisions

### D1 — All new logic is Dart, in `features/navigation`

Matching, ranking and entry assembly are view-adjacent logic with a single caller (the GUI). The headless runner and
MCP have no palette. So nothing goes into `kafkalyzer-core`. That would add a bridge round trip per keystroke for
no second consumer (project rule: move to core only with a second caller). No Rust, no bridge regeneration.

Layout:
- `lib/src/features/navigation/command_palette/fuzzy_match.dart`: pure `FuzzyMatch? fuzzyMatch(String query,
  String candidate)` returning a score and the matched indices (for highlighting).
- `.../palette_entry.dart`: `PaletteEntry` (kind enum `reference, destination, cluster, topic, consumerGroup,
  script`, label, optional subtitle, `Future<void> Function() run`).
- `.../palette_sources.dart`: builds the entries from injected lists (plain parameters, so it is testable without
  `getIt`) and ranks them (`rankEntries(query, entries, limit)`).
- `.../command_palette_dialog.dart`: the dialog.
- `lib/src/features/navigation/main_navigation_controller.dart`: see D4.

### D2 — Shortcut handling: one `HardwareKeyboard` handler in `MainLayout`

Register the palette in the same `MainLayout` `HardwareKeyboard` handler that 5.25 adds for `F1`/`?` (extend it; do
not add a second one). On `KeyDownEvent` only (no repeat), when the event matches
`AppShortcuts.commandPalette.activators`:
1. Do nothing if `MainLayout`'s `ModalRoute` is not current. That covers any open dialog, including the palette, the
   overview and Quick Jump, so no second palette opens.
2. Do nothing (return `false`) if `defaultTargetPlatform == TargetPlatform.macOS`, the key is `Ctrl+K` (not `Cmd`),
   and `isTextInputFocused()`. The native `deleteToEndOfLine:` then still runs.
3. Otherwise open the palette and return `true`. Returning `true` stops the platform text input from seeing the
   key, so `Ctrl+K` on Linux/Windows inserts nothing.

Catalogue entry: `AppShortcuts.commandPalette = ShortcutEntry(id: 'global.commandPalette', context: global,
keys: [ShortcutKey(LogicalKeyboardKey.keyK, primaryModifier: true)], label: (l) => l.shortcutCommandPalette)`,
appended to `all`. The catalogue test then checks it against every context.

Alternatives:
- `CallbackShortcuts` around the `MainLayout` body. Rejected: it fires only when focus is inside that subtree, and
  after a dialog closes focus can sit on the root scope. That is exactly the bug class Quick Jump has today. It also
  would not run for keys the text field consumes first.
- `Ctrl+Shift+P` (VS Code style). Rejected: the roadmap fixes `Ctrl+K`, and `Ctrl+K` collides with nothing in the
  catalogue (5.27 uses `Ctrl/Cmd+F`, `Ctrl/Cmd+C`).

### D3 — Modifier guard in the message view handler

In `_handleInspectorShortcut`, treat `J`, `K` and `F` as letter shortcuts only when
`!HardwareKeyboard.instance.isControlPressed && !isMetaPressed && !isAltPressed`. With a modifier held, the handler
returns `false` for these keys. Arrow keys and `Escape` are unchanged. If 5.27 is merged first, its `Ctrl/Cmd+F`
and `Ctrl/Cmd+C` branches must be checked before the plain-letter branch, so the guard only applies to the
modifier-free entries. Its shortcut table already separates activators, and matching on full `SingleActivator`s
(`activator.accepts(event, HardwareKeyboard.instance)`) gives the guard for free. Prefer that if the table exists.

Why not let the palette handler run "first": Flutter calls all `HardwareKeyboard` handlers no matter what earlier
handlers return. Ordering cannot suppress the message-view step. Only the guard can.

### D4 — `MainNavigationController` replaces `_selectedIndex`

`ChangeNotifier`, registered as a lazy singleton in `dependency_injection.dart`:
- `enum MainDestination { explorer, consumerLag, scripts, settings }` (rail order). `destination` getter,
  `select(MainDestination)`.
- One-shot requests: `openConsumerGroup(String groupId)` and `openScript(String scriptId)` set a pending id, then
  select the destination. `String? takeConsumerGroupRequest()` / `takeScriptRequest()` return the pending id and
  clear it.

`MainLayout` listens and maps `destination` to the rail index (the `NavigationRail` callback calls `select`). The
target views consume a request in `initState` (view freshly mounted) and in a controller listener (view already
visible behind the palette). Because the value is taken once, a later remount does not reveal the same item again.
The `main-navigation` behaviour does not change, so there is no spec delta.

Alternative: pass callbacks from `MainLayout` into the dialog and expose `GlobalKey`s on the views. Rejected:
reaching into private view state through keys couples `MainLayout` to `ConsumerLagView`/`ScriptManagerView`
internals and breaks when a view is not mounted.

### D5 — Consumer groups: session-only `ConsumerGroupDirectory`

`lib/src/features/consumer/application/consumer_group_directory.dart`, lazy singleton:
`void record(String clusterName, Iterable<String> groupIds)`, `List<String>? idsFor(String clusterName)` (`null` =
never loaded). `ConsumerLagView._fetchLags` calls `record` after a successful fetch. A failed fetch does not
overwrite the last good list, and the palette does not show it as "no groups". The state is in memory only, never
persisted (E17). Memory is one id list per cluster.

Reveal in `ConsumerLagView`: on a request, reset the status filter to "All", put the group id into the existing
search field (this reuses the existing substring filter, so the row is built and its lag loads through the existing
lazy `_loadGroupLag`), and expand that group's tile through an `ExpansibleController` (Flutter 3.50 API; the project
does not use it yet) or `initiallyExpanded` keyed on the requested id. If the group list has not arrived yet, keep
the id as `_pendingRevealGroupId` and apply it when `_fetchLags` completes. If the loaded list lacks the id, show a
SnackBar "Consumer group … not found" (spec scenario) and leave the search text so the user sees the empty
filtered list for a reason.

Alternatives:
- Fetch groups when the palette opens. Rejected: the roadmap says "only already-loaded lists". It would also be a
  hidden network call against production clusters on a keyboard shortcut.
- Add the cache to `KafkaMetadataService`. Rejected: 10 test fakes `implements` that service and would all break.
  The cache also describes view-loaded state, not the API.
- Lift the whole lag list into a controller. Out of scope (5.13). When 5.13 lands, the directory should read from
  that controller, and `record` calls disappear.

### D6 — Quick Jump stays separate; the palette hands off references

Keep both. Merging would mean rewriting `shareable-message-references` (spec-bound `Ctrl+G`, cluster-mismatch
prompt, inline invalid-format error) inside a list UI. The two inputs also mean different things: a reference is
exact and may name an unknown cluster, while a name search is fuzzy over loaded data. The distinction is shown in the
UI: the palette's hint text says "Search clusters, topics, groups, scripts…", and Quick Jump's says "Paste a
kafkalyzer:// link".

Hand-off: if `MessageReference.tryParse(query.trim())` succeeds, the palette puts a `reference` entry first
("Open reference in Quick Jump"). Running it pops the palette and opens `QuickJumpDialog(initialInput: query)`. The
new optional constructor parameter `initialInput` pre-fills the field and runs the existing `_onInputChanged` once
after the first frame. The default is `null`, so existing call sites and tests are unchanged.

### D7 — Matching and ranking

Case-insensitive subsequence match with greedy-leftmost scanning plus one backtrack-free improvement pass (prefer a
match that starts at a word boundary if one exists). Score, higher is better:
- +100 exact (case-insensitive) match, +60 prefix match;
- +15 per character that continues a contiguous run;
- +10 per match at a word start (index 0, or after `.`, `-`, `_`, `/`, space, or a lower→upper case change);
- −1 per skipped character before the first match, −0.5 per gap character between matches;
- tie-break: kind order (`reference`, `destination`, `cluster`, `topic`, `consumerGroup`, `script`), then label
  alphabetically, then label length.

Empty query: destinations, then cluster profiles, then open topic tabs of the active cluster, then scripts.
`limit` = 50 displayed results. When more match, the dialog shows "50 of N matches, keep typing" so the cap is
visible (bounded-memory rule). Cost: for 20 000 topics with 30-character names, about 600 k character comparisons
per keystroke, well under a frame on desktop. Run synchronously, with no isolate and no debounce. A unit test pins
the ranking examples from the spec.

Alternative: a fuzzy package from pub.dev. Rejected: about 60 lines of code do not justify a new dependency
(ponytail/project rule), and the matched indices are needed for highlighting.

### D8 — Dialog UI

`Dialog` (material_ui), top-aligned, max width 640. A `TextField` (autofocus, hint, `textInputAction: go`) above a
`ListView.builder` of `ListTile`s: kind icon plus a localized kind label as trailing text (not colour-only),
the label with the matched characters in bold (reuse `highlight_text_utils.dart` if its API fits indices; otherwise
a small `TextSpan` builder), and a subtitle (topic: partition count; script: step count; cluster: "active" marker).
Keys are handled with `CallbackShortcuts` on the `TextField`'s parent, while focus stays in the field:
`ArrowDown`/`ArrowUp` move `_highlight` (wraps around), `Enter`/`onSubmitted` runs, and `Escape` uses the default
dialog dismiss. The highlighted row gets `selected: true` and `Scrollable.ensureVisible` through a per-index key.
Semantics: the list is a `Semantics(container: true, label: …)`, and each row says "kind, name". A tap runs the row.

Run order: `Navigator.pop` first, then `await entry.run()` on the root context. The palette then never stays open
during a connect, and errors surface through the existing SnackBar/inline paths (D9).

### D9 — Entry actions and failure cases

| Kind | Action | Failure / edge case |
|---|---|---|
| destination | `nav.select(d)` | none |
| cluster | `nav.select(explorer)`; if `activeProfile?.name != p.name` → `connect(p)` | connect errors use the existing `ActiveConnectionController.error` UI in the Explorer; connect already ignores a second request for the same profile |
| topic | `nav.select(explorer)`; `openTopic(topic: t, profile: active, forceNew: false)` | topic list `null` (loading or failed) → no topic entries (spec); ACL-hidden topics are absent from the metadata list and therefore absent here |
| consumerGroup | `nav.openConsumerGroup(id)` | group gone → "not found" SnackBar (D5); missing describe ACL → existing failed-group badge in the view |
| script | `nav.openScript(id)` | script deleted meanwhile → SnackBar "Script not found", view shows its list; a running script keeps running |
| reference | open Quick Jump prefilled | invalid input never yields this entry |

The topic source uses the full `TopicController.getTopics(active)` list, not `ActiveConnectionController.topics`. A
user who types a name expects to find it even if the sidebar hides it (spec scenario). The roadmap's suffix-based
"stream topic" hiding (B8, 5.33) therefore does not affect the palette.

## Risks / Trade-offs

- [5.25 not merged yet] → Hard prerequisite: the catalogue, `isTextInputFocused` and the `MainLayout` key handler
  come from it. If 5.25 slips, do not ship a local shortcut table. Wait, or implement 5.25 D8 first as its own step.
- [5.27 rewrites the same `messages_view` handler] → D3 is a single condition. Implement it after 5.27 if 5.27 lands
  first, and re-run both changes' key tests (`messages_view_stepper_test`).
- [macOS behaviour cannot be verified in widget tests] → Spike task 1.2 checks `Ctrl+K`/`Cmd+K` manually on macOS
  in a text field. Widget tests cover the decision logic with `debugDefaultTargetPlatformOverride`.
- [Consumer groups are unavailable until Consumer Lag has been visited once per session] → Accepted (roadmap rule).
  The palette states it (spec), and the Consumer Lag destination entry is always present.
- [Group ids in memory for every visited cluster] → One string list per cluster, cleared on app exit. It holds no
  payloads or secrets.
- [Substring search reveal may show sibling groups whose id contains the requested id] → The requested tile is the
  one expanded. Acceptable.
- [Ranking constants are arbitrary] → Pinned by unit tests on the spec examples and tunable without a spec change.

## Migration Plan

No stored data and no migration. Rollback means removing the dialog, the catalogue entry and the controller. The
`MainNavigationController` replacement of `_selectedIndex` is behaviour-neutral (covered by `main_layout_test`).

## Open Questions

- Should `F1`/the overview dialog also be reachable as a palette destination entry ("Keyboard shortcuts")? This is
  cheap to add later and changes no spec here.
