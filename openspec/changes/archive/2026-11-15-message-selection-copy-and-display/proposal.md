# Proposal: message-selection-copy-and-display

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.27 (change id `message-selection-copy-and-display`,
size M), motivated by §2.4 C ("Nachrichten: nur Einzelauswahl, Zeilen-Kontextmenü mit einem einzigen Eintrag …
Tombstone nicht von leerem Wert unterscheidbar, Zeit nur lokal ohne Zonenangabe"), under the guardrails L1, L5 and L7
of §1. Phase 1.

## Why

Getting a message out of kafkalyzer and into a ticket, a chat or a terminal is slow and lossy today. The table
allows one selected row, its context menu has one entry ("Copy Shareable Link"), and the keyboard only works while
the inspector is open. A tombstone looks like an empty value, a `null` key looks like an empty key (`<null>` for
both), timestamps are local time without a zone, and "Copy metadata" writes a locale-formatted date. The quick filter
ignores headers, partition and offset. Users comparing two messages have to rely on the key-based Diff view.

## What Changes

- **Multi-selection in the table:** `Ctrl`/`Cmd`+click toggles a row, `Shift`+click selects a range in the displayed
  order. The toolbar shows the selected count and a "Clear selection" action. With exactly two messages selected,
  "Compare" opens both in a comparison dialog that reuses the existing message diff (`MessageDiff`,
  `JsonDiffWidget`).
- **Row context menu** (table and timeline): Copy key, Copy value, Copy message as JSON, Copy coordinates
  (`topic/partition/offset`), Copy kcat command, Copy shareable link (kept). With a multi-selection: Copy selected
  messages as JSON, Compare (exactly two). The kcat command is a **consume-only** call for exactly this message
  (`kcat -C -b … -t … -p <partition> -o <offset> -c 1 -e`); it never contains producer, group or offset-commit flags
  and never contains a secret.
- **Tree:** a row context menu in `SmartVirtualJsonTree` with "Copy value" and "Copy field path". The path uses the
  canonical grammar of `json-path-resolution` (dot and `[n]`, JSON Pointer when a key cannot be written in dot form).
- **Null, empty and tombstone:** table, timeline and inspector mark a tombstone (`null` value) and a `null` key
  explicitly and show an empty string as "empty", not as nothing. Copy actions keep `null` and `""` apart (today the
  inspector's message JSON turns `""` into `null`). Copy key / Copy value are disabled when the field is `null`.
- **Timestamps:** a global, persisted setting switches every Kafka message timestamp between local time and UTC. A
  toolbar toggle in the results view changes it; the active zone is visible on the Timestamp column header and the
  inspector chip. A tooltip on every message timestamp shows ISO-8601, epoch milliseconds, relative time and — when
  known — the timestamp type. "Copy metadata" and "Copy message as JSON" write ISO-8601 with zone.
- **Timestamp type (optional, additive):** `KafkaMessage` gets an optional `timestamp_type`
  (`CreateTime`/`LogAppendTime`/`NotAvailable`), filled from rdkafka. A message without broker timestamp shows
  "no timestamp" instead of 1970-01-01.
- **Keyboard without inspector:** focus the quick filter (`Ctrl`/`Cmd`+`F`), first/last message (`Home`/`End`), page
  up/down, move the selection (`↑`/`↓`, `J`/`K`), open the inspector (`Enter`), copy the selection as JSON
  (`Ctrl`/`Cmd`+`C`), clear the selection (`Esc`). Shortcuts are named in the tooltips of the controls they trigger.
  Shortcuts act only in the visible results view (inactive topic tabs stay alive in an `IndexedStack` and today
  would also react while their inspector is open).
- **Quick filter scope:** the in-memory filter also matches header keys and values, and a numeric query matches the
  exact partition or offset.
- The shortcut list lives in one Dart table that drives both the key handler and the tooltips; it is registered with
  the central shortcut registry of `app-diagnostics-and-error-reporting` (§5.25) when that exists (see design D8).
- `TombstoneWidget` and the inspector's `Key:` / `<null>` texts are localized (they are part of the reworked UI).

Read-only impact: no new Kafka or Schema Registry calls. The timestamp type is read from messages that are already
being consumed. The copied kcat command is text on the clipboard, never executed by kafkalyzer, and is restricted to
consume mode. `scripts/check_read_only.sh` must pass unchanged; no new exception.

Prerequisites (implemented first): `fix-result-view-defects` (§5.23: tree copy as JSON, which "Copy value" builds on;
deterministic sort used for range selection; Content filter on the full payload), `harden-read-only-gate` (§5.1),
`restore-tls-verification` (§5.21; the kcat command never adds verification-disabling flags).

Non-goals:
- Export content, export of the visible view or the selection, NDJSON, ISO timestamps in export files
  (`message-export-fidelity`, §5.28).
- Showing the time-display setting in the Settings page and a "reset to default" there
  (`appearance-window-and-update-settings`, §5.31 shows the setting this change owns).
- The central shortcut registry and the F1 overview (`app-diagnostics-and-error-reporting`, §5.25); a command palette
  (`command-palette`, §5.4).
- Decoding nested payloads, epoch tooltips on payload numbers, headers in the shared viewer, inspector search over
  key and headers (`nested-payload-decoding`, §5.30); payload timestamps inside the tree keep their current
  formatting.
- Structural diff with ignore list, poison-pill comparison (`structural-message-diff` §5.8, `poison-pill-compare`
  §5.12); the comparison dialog only reuses the existing diff.
- Multi-selection in timeline and diff views, keyboard range selection (`Shift`+arrow), selection across tabs.
- Header values that are `null` on the wire (today decoded as `""` in Rust); unchanged.
- Remaining hard-coded strings outside the reworked widgets (`accessibility-and-l10n-sweep`, §5.32).
- Any kcat variant other than single-message consume (no producer, replay, group or schema-registry flags).

## Capabilities

### New Capabilities
- `message-selection-and-copy`: selecting one or more loaded messages in the result views, the row context menu, copy
  formats (key, value, message JSON, coordinates, consume-only kcat command, selection JSON), comparing two selected
  messages, and faithful display and copy of `null`, empty and tombstone keys and values.
- `message-timestamp-display`: how Kafka message timestamps are shown and copied — global persisted local/UTC mode,
  zone indication, detail tooltip (ISO-8601, epoch, relative, timestamp type) and ISO-8601 in copied metadata.

### Modified Capabilities
- `message-inspector-shell`: MODIFIED *Kafka Metadata and Context Header* (ISO-8601 metadata copy, explicit `null`
  and empty key, tombstone marker); MODIFIED *Global Keyboard Shortcuts for Stream Inspection* (shortcuts without
  open inspector, visible view only, shortcuts named in tooltips).
- `smart-virtual-json-tree`: ADDED *Copy Field Path from Tree Row* (row context menu with canonical path).
- `unified-results-toolbar`: ADDED *Quick Filter Covers Headers, Partition and Offset*.

Deviation from §5.27: the roadmap names `message-table-columns` as modified. No column requirement changes; table
multi-selection and the cell markers are specified in `message-selection-and-copy`, the zone label on the Timestamp
header in `message-timestamp-display`. Time display is a separate capability because §5.31 references it as a
setting of its own.

## Impact

- Rust (optional group): `rust/kafkalyzer-core/src/kafka_types.rs` (`MessageTimestampType`, field on
  `KafkaMessage`), `rust/kafkalyzer-kafka/src/kafka_consumer.rs` (fill from `msg.timestamp()`, all `KafkaMessage`
  literals), `rust/src/api/kafka_consumer.rs` (bridge DTO + mapping). Bridge regeneration and mocks. Additive; the
  Dart constructor keeps compiling because the new field is an optional named parameter.
- Dart: `lib/src/ui/messages/messages_view.dart`, `views/messages_table_view.dart`, `views/messages_timeline_view.dart`,
  `widgets/message_inspector_panel.dart`, `widgets/timeline_message_card.dart`, `widgets/message_metadata_card.dart`,
  `widgets/message_search_bar.dart`, `lib/src/features/scripting/presentation/widgets/timeline_metadata_card.dart`,
  `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`, `json_tree_flattener.dart`, `virtual_json_node.dart`,
  `lib/src/ui/date_format_utils.dart`, `lib/src/ui/tombstone_widget.dart`, `lib/src/dependency_injection.dart`.
- New Dart files: message clipboard formatter (JSON, coordinates, kcat), shared quick-filter predicate, time-display
  settings notifier, message-view shortcut table, message comparison dialog.
- `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`; widget and unit tests.
- No new dependency.
