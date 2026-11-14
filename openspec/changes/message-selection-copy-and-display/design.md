# Design: message-selection-copy-and-display

## Context

See proposal.md for motivation and scope; requirements are in `specs/message-selection-and-copy`,
`specs/message-timestamp-display`, `specs/message-inspector-shell`, `specs/smart-virtual-json-tree` and
`specs/unified-results-toolbar`.

Current state (verified in code, not executed):

- `MessagesView` (`lib/src/ui/messages/messages_view.dart`) owns one `KafkaMessage? _selectedMessage`, an
  `_isInspectorOpen` flag and the visual order (`_activeOrderedMessages`, the table reports its own sorted order via
  `onVisualOrderChanged`). Topic tabs and script run details both use it.
- Keyboard: one `HardwareKeyboard` handler (`_handleInspectorShortcut`, ~539-585) that returns early unless the
  inspector is open (`_shouldHandleInspectorShortcuts`). It checks `ModalRoute.isCurrent` but not visibility. Topic
  tabs live in an `IndexedStack` (`explorer_view.dart:1062`), whose hidden children stay mounted; in the current
  Flutter SDK it wraps each child in a visibility scope (`Visibility.of`) and `ExcludeFocus`. By code reading, two tabs
  with an open inspector both step on `J`.
- Quick filter (`_updateFilters`, ~372-394) matches key, payload, topic and step name. The table computes its own
  `isMatch` for dimming (key, payload, topic, step, projected values) — two predicates that can disagree.
- Table (`messages_table_view.dart`): one context-menu entry (`_showRowContextMenu`, "Copy Shareable Link"); Key cell
  uses `msg.key ?? ""` and Content uses `TextPreviewUtils.getPayloadPreview`, which returns `""` for both `null` and
  `""`. Timestamps are formatted eagerly per row with `DateFormatUtils.formatDateTime` (local, no zone).
- Inspector (`message_inspector_panel.dart`): key summary shows `'<null>'` for `null` and `""`; `_tryParseJson`
  turns `""` into `null` in "Copy message" and the Raw JSON tab; "Copy metadata" writes the locale date; Payload tab
  passes `payload ?? ''`, so a tombstone shows an empty viewer. Hard-coded `'Key: '`.
- Timeline card already shows `TombstoneWidget` for `payload == null` (hard-coded English text) and hides a `null`
  key, but shows an empty key as an empty row.
- Rust: `null` key/value arrive as `None`, empty bytes as `Some("")` (`decode_message_component` returns `data?`), so
  Dart can already tell them apart. `timestamp` is `msg.timestamp().to_millis().unwrap_or(0)`; the type
  (CreateTime/LogAppendTime/NotAvailable) is dropped. `KafkaMessage` is built at six places in
  `kafkalyzer-kafka/src/kafka_consumer.rs` (real, progress, heartbeat, EOF messages).
- Tree: rows carry a string path built by concatenation (`root.a.b[0]`); pin-to-column normalizes it with
  `normalizeSchemaFieldPath`. Keys containing `.` or `[` are ambiguous in that string.
- A diff of two arbitrary messages exists as `MessageDiff.computeDiff(older, newer)` + `JsonDiffWidget`; the text
  diff (`textDiffToPrevious`) is computed but rendered nowhere.
- No central shortcut registry exists yet; `app-diagnostics-and-error-reporting` (§5.25) is only scaffolded.

## Goals / Non-Goals

**Goals:**
- One selection model in `MessagesView` that all views, shortcuts and copy actions read.
- One pure Dart formatter for every clipboard format (message JSON, selection JSON, coordinates, kcat), unit-tested
  without widgets.
- One quick-filter predicate shared by the filter, the match count and the table dimming.
- One time-display source of truth (`ValueNotifier`) that every timestamp widget listens to.

**Non-Goals:**
- Moving any of this logic to Rust: no second caller (MCP/headless) needs selection, clipboard or display formats.
- A generic `Shortcuts`/`Actions` rewrite of the app; only the message view handler is extended.
- Changing the persisted export format or `SearchJsonSerializer` (§5.28).

## Decisions

### D1 Selection model in `MessagesView`
State: `_selectedMessage` (primary, shown in the inspector, unchanged meaning), `_selection`
(`LinkedHashSet<KafkaMessage>.identity()`, always contains the primary when non-empty) and `_anchor` (last plain or
`Ctrl`-clicked message). The table's tap callback gets the pressed modifiers
(`HardwareKeyboard.instance.isControlPressed/isMetaPressed/isShiftPressed`, `Cmd` on macOS, `Ctrl` elsewhere):
plain → `{msg}` + open inspector (today's behaviour); toggle → add/remove, primary = msg, inspector untouched; range →
slice of `_activeOrderedMessages` between anchor and msg. `_updateFilters` prunes `_selection` to the filtered list;
a live append does not touch it. Identity sets avoid hashing large payloads and match how the buffer holds instances.
Timeline and diff keep single selection (they only get the context menu).
*Alternative:* a separate `SelectionController` ChangeNotifier — rejected; the state is per view instance and already
lives next to `_selectedMessage`.

### D2 Clipboard formats in one pure helper
New `lib/src/ui/messages/message_clipboard_format.dart` with static functions: `messageJson(msg, mode)`,
`selectionJson(list, mode)`, `coordinates(msg)` → `topic/partition/offset`, `kcatCommand(msg, profile)`. Message JSON
keeps today's inspector keys (`topic`, `partition`, `offset`, `timestamp`, `key`, `content`, `headers`), replaces
`formattedTimestamp` by `timestampIso`, adds `timestampType` when known, and fixes `""` → `""` (parse as JSON only for
non-empty text). The inspector's "Copy message" and Raw JSON tab use it, so all copies agree. Selection JSON for more
than 200 messages is encoded with `compute` to keep the UI responsive.
*Alternative:* reuse `SearchJsonSerializer.serializeMessage` — rejected; it is the persisted search format (no
headers, no ISO) and belongs to §5.28.

### D3 kcat command
`kcat -C -b <brokers> -t <topic> -p <partition> -o <offset> -c 1 -e`, every value single-quoted for POSIX
(`'` → `'\''`). From the profile only: `-X security.protocol=…`, `-X sasl.mechanisms=…`, `-X sasl.username=…`, and for
a profile with a SASL password `-X sasl.password="$KAFKA_SASL_PASSWORD"` (literal reference, value never read). No
truststore/keystore paths (JKS locations do not map to kcat's PEM options), no `-G`, `-P`, `-K`, no TLS verification
switch. Without a profile, `-b '<bootstrap-servers>'`. The function is unit-tested for the exact output and for the
absence of `-P`, `-G` and secrets. Identifiers must not contain `Producer` (read-only gate pattern).
`// shortcut: POSIX quoting only; add a PowerShell variant if Windows users ask for it.`

### D4 Shared quick-filter predicate
New `MessageQuickFilter.matches(msg, lowerQuery, {int? number})` in `lib/src/ui/messages/`: key, payload, topic,
step name (`ScriptResultMessage`), header keys and values (substring, case-insensitive); `number` (parsed once per
query via `int.tryParse`) matches `partition == n || offset == n`. `MessagesView._updateFilters` and the table's
`isMatch` both call it; the table drops its extra projected-value match (projected values come from the payload, and
the spec requires count and dimming to agree). The search bar keeps its 300 ms debounce.

### D5 Time display setting
New `TimeDisplaySettings` (`lib/src/services/time_display_settings.dart`): a `ValueNotifier<TimeDisplayMode>`
(`local`, `utc`), persisted under `message_time_display_mode` in `SharedPreferences`, registered as lazy singleton in
`setupDependencyInjection` and loaded with `await load()` in `main.dart` before `runApp` (value is `local` until
loaded). Unknown/missing → `local`. `DateFormatUtils` gets
`formatMessageTimestamp(context, epochMs, mode)` (locale pattern + ms; UTC converts with `toUtc()`), `isoTimestamp(epochMs,
mode)` (`…Z` or `…±HH:MM` built from `timeZoneOffset`, since `toIso8601String` omits the local offset) and
`relative(context, epochMs)` (localized "n s/min/h/d ago"/"in …" via ARB plurals). Widgets listen with `watchIt`/
`ValueListenableBuilder`. The table caches `dateStr` per row today; the mode becomes part of the row-cache key so a
toggle rebuilds rows once. The Timestamp column filter matches the string in the active mode.
`appearance-window-and-update-settings` (§5.31) adds the same notifier to the Settings page; this change only adds
the toolbar toggle (D9).
*Alternative:* store in `SettingsService` — rejected; it is async-only and has no listeners.

### D6 Timestamp type (Rust → bridge, additive)
`kafkalyzer-core::kafka_types::MessageTimestampType { CreateTime, LogAppendTime, NotAvailable }` and
`KafkaMessage.timestamp_type: Option<MessageTimestampType>` with `#[serde(default)]`. `kafkalyzer-kafka` maps
`rdkafka::Timestamp` in `process_and_send_message`; synthetic messages (progress, heartbeat, EOF) set `None`. Bridge:
mirror enum + field in `rust/src/api/kafka_consumer.rs` and the `From` impl. frb emits an `Option` field as an
optional named Dart parameter (as for `key`, `headers`), so `ScriptResultMessage`, tests and
`SearchJsonSerializer.deserializeMessage` keep compiling; their messages have `null` = unknown. `NotAvailable` → the UI
shows "no timestamp" (spec). The enum is pure data, so it lives in core (L2). This group is independent of the rest:
if dropped, tooltips omit the type and `timestamp == 0` keeps today's display.

### D7 Keyboard handler
Extend the existing `HardwareKeyboard` handler instead of adding a second one:
1. Gate: mounted, route current, and `Visibility.of(context)` true (fixes the hidden-tab case).
2. Inspector open → today's behaviour plus `Home/End/PageUp/PageDown`, `Ctrl/Cmd+C`, `Ctrl/Cmd+F`.
3. Inspector closed → only when `_shortcutFocusNode.hasFocus` (focus inside the view; a row tap already requests it)
   — except `Ctrl/Cmd+F`, which only needs visibility. Arrows/J/K move the selection without opening the inspector,
   `Enter` opens it, `Esc` collapses a multi-selection to the primary.
4. Text isolation: letter keys, `Home/End/PageUp/PageDown`, `Enter` and `Ctrl/Cmd+C` are ignored while an
   `EditableText` (includes `SelectableText`) has focus.
Page step: table = `floor(viewportHeight / rowHeight)` (44 px rows), reported by the table with its visual order;
timeline/diff = 5. `// shortcut: fixed page step outside the table; measure card heights if users complain.`
Ctrl/Cmd+F: `MessageSearchBar` gets an optional `FocusNode`; the view requests focus and selects all text.

### D8 Shortcut table and the §5.25 registry
New `lib/src/ui/messages/message_view_shortcuts.dart`: a const list of entries (id, `SingleActivator`s, l10n label
getter). The handler matches against it and tooltips render the label with `shortcutLabel(activator, platform)`
(`Ctrl`/`⌘`, `↑`). Decision: this change ships the local list. If §5.25 is merged first, the implementer registers
these entries in its registry instead and keeps the list only as the source of the entries; if §5.25 comes later,
it imports this list. Either way the F1 overview and the tooltips read the same entries.

### D9 UI placement
- Toolbar (`MessagesView` header `Wrap`): time-mode toggle (`IconButton`, `Icons.public` for UTC /
  `Icons.schedule` for local, tooltip names the target mode); selection chip "n selected" with clear and "Compare"
  (enabled at exactly two) shown only when `_selection.length > 1`.
- Context menu: one `showMessageContextMenu(context, position, msg, …)` used by table rows and timeline cards;
  shortcut hints as trailing text on menu items.
- Comparison: `MessageCompareDialog` (`Dialog` sized to 90 % of the window) with two metadata headers and either
  `JsonDiffWidget` or a new small text-diff renderer over `diff_match_patch` `Diff`s (insert/delete with icon prefix
  and colour, so not colour-only). Order: older by timestamp, then offset. Tombstone side → `TombstoneWidget`, no diff.
  Errors from `computeDiff` (e.g. a top-level JSON array that the JSON differ rejects) → localized error text.
  *Alternative:* render the pair inside the inspector — rejected; the inspector is single-message by spec.
- Markers: a small `MessageFieldMarker` (icon + localized label, `colorScheme.outline`, italic) for "no key", "empty"
  and tombstone in table cells; timeline/inspector reuse it; `TombstoneWidget` becomes localized and theme-coloured.

### D10 Tree path copy
`VirtualJsonNode` gets `List<Object> segments` (`String` key / `int` index) filled by `JsonTreeFlattener` next to the
string path (compound breadcrumb rows get the innermost node's segments). `canonicalFieldPath(segments)`: dot and
`[n]` form when every key matches `^[A-Za-z_$][\w$-]*$`, otherwise JSON Pointer with `~0`/`~1` escaping — both are
grammar of `kafkalyzer_core::json_path` (L7), no new syntax. A round-trip unit test resolves the copied path with
`resolveJsonPath` on the bridge mock or the Rust test suite. The row gets `onSecondaryTapDown` → menu (Copy value =
existing JSON copy from `fix-result-view-defects` D4, Copy field path, Pin as column). `nested-payload-decoding`
(§5.30) adds its decode entries to this menu. Pin-to-column keeps its current normalization.

## Risks / Trade-offs

- [Two Phase-1 changes edit `messages_view.dart`, the table and the tree in parallel (5.28, 5.29, 5.30)] → keep edits
  local to new helpers; selection pruning is the only touch point with 5.29's buffer cap (pruning on list change).
- [Copying thousands of selected messages produces a huge clipboard string] → `compute` above 200 messages; selection
  is bounded by the loaded buffer, which 5.29 caps.
- [Global `Ctrl+F` could collide with a future command palette (5.4)] → 5.4 must use a different activator; both
  register in the shared list/registry, which makes collisions visible.
- [Header matching costs O(headers) per message per query] → only on debounced filter changes, not per stream tick.
- [Relative time in tooltips goes stale] → computed when the tooltip builds; acceptable.
- [Exact numeric match surprises users who expect substring on offsets] → documented in the search-bar tooltip
  ("partition or offset: exact number").
- [`Visibility.of` behaviour depends on the Flutter SDK's `IndexedStack`] → covered by a widget test with two
  `MessagesView`s in an `IndexedStack`.

## Migration Plan

Additive. The time setting defaults to local (today's behaviour). The new `KafkaMessage` field is optional on both
sides; stored or imported messages without it load as "type unknown". Clipboard JSON renames `formattedTimestamp` to
`timestampIso` (clipboard only, not persisted). Rollback = revert; the preference key is ignored by older versions.
