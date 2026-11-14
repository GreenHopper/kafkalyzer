# Proposal: nested-payload-decoding

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.30 (Phase 1b), gap list §2.4 C ("Nachrichten").

## Why

Kafka payloads often carry data inside data: a JSON document stored as a string field, a Base64 blob, or a
gzip-compressed and Base64-encoded field. Today the tree can only show such a value as one long string. The user has to
copy it out of the app to read it. The same applies to the key and the headers. Headers are shown as plain text without
the tree, hex view or search (`message_inspector_panel.dart:987-1000`). The key sits in a fixed 130 px box and the
in-inspector search only reaches the payload (`message_inspector_panel.dart:873-916`). That contradicts the existing
`message-inspector-shell` requirement, which says the search covers payload **and key**.

## What Changes

- **On-demand decoding of text values.** Each string row in `SmartVirtualJsonTree` gets a "Decode as…" action with
  JSON, Base64 and gzip (Base64 → gunzip). The result is shown in place as a child subtree of that row. The original
  value stays visible on the row, and the user can remove the decoded view again. Results can be decoded further
  step by step (for example Base64 → text → JSON). Byte results get a compact hex preview and a gzip action. A
  non-JSON text value or a binary value shown in `JsonOrStringViewer` (payload, key, header) offers the same action
  for the whole value, with a "Show original" switch. Nothing is decoded automatically.
- **Bounded, off-thread decoding.** Decoding runs in a background isolate and the row shows a progress state while it
  runs. Input and output size are capped (a gzip bomb stops at the output cap). A failure (invalid Base64, not gzip,
  invalid JSON, limit exceeded) shows a localized inline error on that row. The raw value is never changed.
- **Decoded subtrees are view-only.** They are included in the in-tree search. Rows inside them offer no "Pin as
  column", "Filter by field" or "Copy field path". The canonical path grammar (`json_path`) cannot address content
  inside a decoded string, and this change adds no second path syntax.
- **Epoch date tooltip.** Integer numbers in a plausible epoch range (seconds, milliseconds, microseconds or
  nanoseconds between 2000-01-01 and 2100-01-01 UTC) keep their numeric display. A tooltip shows the date in the
  global local/UTC mode, plus the other zone and the assumed unit. This replaces the unimplemented spec clause that
  epoch numbers next to "temporal keys" should be reformatted inline.
- **Header values use the shared viewer.** Each header value is rendered with `JsonOrStringViewer`, the same as key
  and payload: JSON values as a tree, text as raw text, the Rust binary fallback (`0x` + hex) in the hex view, plus
  decode actions and per-header copy. The key viewer is no longer a fixed 130 px box. It sizes to its content up to a
  cap.
- **Inspector search covers payload, key and headers.** Match counts of all sources are added up (`n of N`), and
  next/previous steps through them in order: payload, key, then each header's key and value. When the next match is
  in another tab, the inspector switches to that tab and scrolls to the match. This works in Tree and Raw mode (Raw
  jump comes from `chunked-raw-and-hex-viewer`).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `smart-virtual-json-tree`: ADD on-demand decoding of text values (in the tree and for whole viewer values), with
  limits, error display and view-only decoded subtrees. MODIFY *Human-Readable Smart Timestamp Formatting* so that
  epoch numbers get a date tooltip in the global time mode instead of inline reformatting.
- `message-headers-inspection`: MODIFY *Message Headers UI Display* so that header values use the shared viewer.
- `message-inspector-shell`: MODIFY *In-Inspector Value Search and Match Stepping* to include headers, sum the counts
  across sources and jump across tabs.

Fixed without a spec delta: the key is already in scope of the inspector search under the existing
*In-Inspector Value Search and Match Stepping* requirement, but the code does not pass the query to the key viewer.
Off-thread decoding is already required by `large-message-handling` *Non-Blocking Payload Processing*.

## Impact

- Code (Dart only): `lib/src/ui/smart_tree/smart_virtual_json_tree.dart`, `json_tree_flattener.dart`,
  `virtual_json_node.dart`, `lib/src/ui/json_or_string_viewer.dart`,
  `lib/src/ui/messages/widgets/message_inspector_panel.dart`. New pure module
  `lib/src/utils/nested_value_decoder.dart` (decode functions, limits, epoch range check). It uses `dart:convert`
  (`base64`, `utf8`, `json`) and `dart:io` (`GZipCodec`). That is fine because the app targets desktop only (E12).
- Tests: new unit tests for the decoder and epoch check, plus flattener tests with decoded overlays. Widget tests
  for tree decode, viewer decode, header viewer and the cross-source inspector search. The existing inspector search
  test fixture has the key `order-1234`, so its expected count changes from 2 to 3.
- l10n: new keys for decode actions, errors, limits, epoch tooltip and header section labels, in `app_en.arb` and
  `app_de.arb`.
- No Rust, bridge or dependency changes.
- **Read-only impact:** no new Kafka or Schema Registry calls. Decoding works only on data that is already loaded.
  `scripts/check_read_only.sh` must pass unchanged.

## Prerequisites

- Phase-0 changes first (E14). Functionally relevant: `fix-result-view-defects` (5.23, tree copy of object/array nodes
  as JSON). Copying a decoded subtree reuses that.
- `message-selection-copy-and-display` (5.27, Phase 1a): provides `TimeDisplaySettings` (global local/UTC), which the
  epoch tooltip reads, and `VirtualJsonNode` path segments plus the tree context menu. Decoded rows are excluded from
  path copy there.
- `chunked-raw-and-hex-viewer` (5.5, earlier in Phase 1b): provides Raw-mode `jumpToMatch`, the off-thread Raw search
  and the `Uint8List` hex viewer. This change only widens the search scope to key and headers and uses that jump.

## Non-Goals

- Automatic detection or decoding of nested content (no auto-JSON, no auto-Base64, no auto-gunzip).
- Other codecs (zstd, snappy, lz4, deflate without gzip header, Protobuf/Avro inside a field, hex text → bytes).
- Using decoded content for column projection, filters, sorting, export or the broker-side search. It stays a view.
- Searching the Raw JSON or Schema tabs.
- Time display setting and its UI (5.27/5.31), chunked Raw/Hex rendering (5.5), leftover hard-coded strings in
  existing viewer chrome (5.32), keyboard shortcuts (none added).
- Any Rust or bridge change, such as tagging binary headers explicitly.
