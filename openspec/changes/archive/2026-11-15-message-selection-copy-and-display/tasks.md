# Tasks

Prerequisites merged first: `fix-result-view-defects`, `harden-read-only-gate`, `restore-tls-verification`.
No spike: the open technical points (IndexedStack visibility scope, frb mapping of `Option` fields) were checked in
the SDK source and the generated bridge code (see design Context, D6, D7).

## 1. Timestamp type in Rust crates (optional group, design D6)

- [x] 1.1 Add `MessageTimestampType { CreateTime, LogAppendTime, NotAvailable }` and `KafkaMessage.timestamp_type: Option<MessageTimestampType>` with `#[serde(default)]` in `rust/kafkalyzer-core/src/kafka_types.rs`; add a core unit test that a JSON `KafkaMessage` without the field deserializes with `None`; verify `cargo test -p kafkalyzer-core`
- [x] 1.2 In `rust/kafkalyzer-kafka/src/kafka_consumer.rs` map `rdkafka::Timestamp` to the new field in `process_and_send_message` and set `None` in every synthetic message literal (progress, heartbeat, EOF); add a unit test for the mapping function (CreateTime, LogAppendTime, NotAvailable); verify `cargo test -p kafkalyzer-kafka` and that no identifier contains `Producer`
- [x] 1.3 Mirror the enum and the optional field in `rust/src/api/kafka_consumer.rs` and extend the `From` impl; extend the existing bridge mapping test; verify `cargo test --workspace` in `rust/`

## 2. Bridge regeneration

- [x] 2.1 Run `flutter_rust_bridge_codegen generate`; verify `KafkaMessage` in `lib/src/rust/api/kafka_consumer.dart` has a nullable, non-required `timestampType` and `MessageTimestampType` is generated
- [x] 2.2 Run `dart run build_runner build`; verify `flutter analyze` reports no errors from `ScriptResultMessage`, `SearchJsonSerializer` or tests constructing `KafkaMessage`

## 3. Time display setting and formatting (design D5)

- [x] 3.1 Add `TimeDisplaySettings` (`ValueNotifier<TimeDisplayMode>`, key `message_time_display_mode`, unknown → local) in `lib/src/services/time_display_settings.dart`, register it in `setupDependencyInjection`, `await load()` in `main.dart` before `runApp`; unit tests for load, unknown value and persistence with mocked `SharedPreferences`
- [x] 3.2 Extend `DateFormatUtils` with `formatMessageTimestamp`, `isoTimestamp` (`Z` / `±HH:MM` with ms) and `relative`; unit tests in `test/src/ui/date_format_utils_test.dart` for `1768812660123` → `2026-01-19T08:51:00.123Z`, a local offset, negative offsets, and relative past/future
- [x] 3.3 Add a shared timestamp text widget with the detail tooltip (UTC ISO, local ISO, epoch ms, relative, type when known; "no timestamp" for `NotAvailable`) that listens to the setting; widget test for tooltip content, unknown type and `NotAvailable`
- [x] 3.4 Use it in the table Timestamp cells (mode joins the row-cache key; header label names "UTC"/"Local"), timeline/diff metadata cards (`message_metadata_card.dart`, `timeline_metadata_card.dart`) and the inspector chip (zone suffix); widget test: toggling the setting re-renders an open table and inspector without reopening, and the Timestamp column filter matches the active-mode string
- [x] 3.5 Add the toolbar time-mode toggle to `MessagesView` (tooltip names the target mode); widget test that it flips the global setting

## 4. Clipboard formats and quick filter (design D2, D3, D4)

- [x] 4.1 Add `message_clipboard_format.dart` with `messageJson`, `selectionJson`, `coordinates`, `kcatCommand`; unit tests: `""` key stays `""`, tombstone value is `null`, JSON key/value embedded, `timestampIso` in both modes, `timestampType` only when known, coordinates `orders/3/1042`, exact kcat string from the spec, SASL username present and password only as `$KAFKA_SASL_PASSWORD`, no `-P`/`-G`/secret values for any profile fixture, placeholder brokers without profile, single-quote escaping
- [x] 4.2 Switch the inspector's "Copy message", Raw JSON tab and "Copy metadata" (ISO-8601) to the helper; update `messages_view_split_test.dart`/inspector tests that asserted `formattedTimestamp` or the locale date
- [x] 4.3 Add `MessageQuickFilter.matches` (key, value, topic, step, header key/value, exact partition/offset for numeric queries); use it in `MessagesView._updateFilters` and the table's `isMatch` (drop the projected-value match); unit tests for header match, `1042` vs `10420`, partition `3`, and a widget test that dimmed rows equal the match count

## 5. Selection model, context menu and comparison (design D1, D9)

- [x] 5.1 Add `_selection`/`_anchor` to `MessagesView` and modifier-aware taps in `MessagesTableView` (plain, `Ctrl`/`Cmd` toggle, `Shift` range in visual order); prune on filter change; selected-row styling distinct from the primary highlight; widget tests for toggle, range on a sorted table, plain-click reset and pruning
- [x] 5.2 Add the toolbar selection chip ("n selected", clear, Compare enabled at exactly two); widget test for count, clear and hidden chip at one selection
- [x] 5.3 Replace `_showRowContextMenu` by a shared `showMessageContextMenu` used by table rows and timeline cards (Copy key/value/JSON/coordinates/kcat/shareable link; selection JSON and Compare for multi-selection; right-click outside the selection reselects); success and error notices; widget tests per entry with a mocked clipboard channel, disabled key/value for `null`, and a rejected clipboard write showing the error notice
- [x] 5.4 Add `MessageCompareDialog` (older left, metadata headers, `JsonDiffWidget` or text-diff renderer with icon prefixes, tombstone side, error text); widget tests for JSON, text, tombstone and a failing diff (top-level JSON array)
- [x] 5.5 Encode selection JSON with `compute` above 200 messages; unit test that the result equals the synchronous encoding

## 6. Null, empty and tombstone markers

- [x] 6.1 Add the marker widget and use it in table Key/Content cells, timeline card key and payload, inspector key summary (replacing `'Key: '`/`'<null>'`) and a tombstone notice in the Payload tab; localize `TombstoneWidget` with theme colours and update `tombstone_widget_test.dart`; widget tests for `null` vs `""` key in table and inspector, tombstone in table/timeline/inspector, empty value in timeline

## 7. Keyboard shortcuts (design D7, D8)

- [x] 7.1 Add `message_view_shortcuts.dart` (entries, platform labels `Ctrl`/`⌘`); if `app-diagnostics-and-error-reporting` is merged, register the entries in its registry, otherwise leave the exported list for it; unit test for labels on macOS and Linux
- [x] 7.2 Extend the `HardwareKeyboard` handler: `Visibility.of` gate, inspector-closed mode (focus inside view), `Home/End/PageUp/PageDown`, `Enter`, `Esc` collapse, `Ctrl/Cmd+C`, `Ctrl/Cmd+F` (search bar gets a `FocusNode`, text selected); table reports its page step; extend `messages_view_stepper_test.dart` with tests per shortcut, text-field isolation for the new keys, and two `MessagesView`s in an `IndexedStack` where only the visible one steps
- [x] 7.3 Name shortcuts in tooltips of quick filter, previous/next, maximize, close, copy message and context-menu items; widget test reading the tooltip texts

## 8. Tree field path (design D10)

- [x] 8.1 Add `segments` to `VirtualJsonNode`, fill them in `JsonTreeFlattener` (innermost node for compound rows), add `canonicalFieldPath` (dot/`[n]`, JSON Pointer fallback with `~0`/`~1`); unit tests for `leistungen[0].transportId`, `/meta/a.b`, `/a~1b`, compound rows and context-windowed array items
- [x] 8.2 Add the tree row context menu (Copy value, Copy field path, Pin as column; no path on the root row); widget test; a Rust test in `rust/kafkalyzer-core` (or bridge test) that the JSON Pointer and dot outputs of the Dart fixtures resolve with `json_path::resolve`

## 9. Localization

- [x] 9.1 Add every new string (context-menu entries, notices, markers, selection chip, compare dialog, time-mode tooltip/labels, relative-time plurals, timestamp types, shortcut-labelled tooltips, quick-filter tooltip) to `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`; run `flutter gen-l10n` (or the build) and verify no new hard-coded literal in the touched widgets

## 10. Final verification

- [x] 10.1 In `rust/`: `cargo fmt --all`, `cargo clippy --workspace --all-targets`, `cargo test --workspace` pass (only if group 1 was implemented)
- [x] 10.2 `dart format .`, `flutter analyze`, `flutter test` pass
- [x] 10.3 `scripts/check_read_only.sh` passes unchanged (no new exception)
- [x] 10.4 Manual check on Linux desktop: multi-select + Compare, kcat command copied for a SASL profile contains no secret, UTC toggle updates table and inspector, shortcuts work only in the visible tab
