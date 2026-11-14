# Design: nested-payload-decoding

## Context

Motivation and scope: see `proposal.md`. Requirements: the three spec deltas in `specs/`.

Current code, checked for this design:

- `SmartVirtualJsonTree` (`lib/src/ui/smart_tree/smart_virtual_json_tree.dart`) flattens synchronously on every
  state change via `JsonTreeFlattener.flatten` (`json_tree_flattener.dart`). Rows are `VirtualJsonNode`s with a
  concatenated string `path` (`root.a[0].b`). The only smart primitive is an ISO-8601 string (`_iso8601Regex`,
  l.583-601). Numbers render as plain teal text, and no epoch handling exists, although the main spec scenario claims
  it for "temporal keys". The timestamp tooltip always uses `toLocal()`.
- `JsonOrStringViewer` (`lib/src/ui/json_or_string_viewer.dart`): modes Raw (0), Tree (1), Hex (3). The
  `<Binary Data>:`/`<Binary Key>:` prefix switches to Hex (l.138-150). `jumpToMatch` only reaches the tree (l.66-70).
  `chunked-raw-and-hex-viewer` (5.5) replaces Raw/Hex with virtualised views, adds Raw `jumpToMatch`, an off-thread
  Raw search with `onSearchStateChanged`, and `Uint8List` hex bytes. This design builds on that version of the file.
- `MessageInspectorPanel`: the search query goes only to the payload viewer (l.873-877). The key viewer is a fixed
  `SizedBox(height: 130)` without a query (l.911-918). Headers are `ListTile`s with two `SelectableText`s
  (l.968-1020). The tab body is a `TabBarView`, which builds only the visible page. That is why a viewer on another
  tab cannot report a match count today.
- Rust sends header values as UTF-8 text, or as `0x` + hex for non-UTF-8 bytes. A missing value becomes `""`
  (`kafka_consumer.rs:917-931`). Payload and key use `<Binary Data>:hex` / `<Binary Key>:hex` instead.
- Off-thread pattern: `lib/src/utils/payload_processing_isolate.dart` (`compute`, synchronous when `isTestMode`).

No Kafka, Schema Registry or file I/O is involved. ACL, broker, offset-gap and topic-size cases do not apply. Only
payload size matters, and it is handled by the limits in D2.

## Goals / Non-Goals

**Goals:**
- One pure decoder used by the tree rows and by the whole-value viewer, with the same limits and error codes.
- Decoded content behaves like tree content for viewing, search and copy. It never enters column projection or
  filters, and it never needs a second path grammar (L7).
- Inspector search counts do not depend on which tab is visible.

**Non-Goals:**
- Moving the decoder to `kafkalyzer-core`. There is no second caller yet. MCP tools return raw values. Move it only
  when a headless caller needs it (config rule, §6.3 rule 3).
- Making `JsonTreeFlattener` asynchronous. It is synchronous today. Decoded JSON is bounded by the 16 MiB output cap,
  which is in the same range as large payloads the tree already handles.

## Decisions

### D1 Layer: Dart only, new pure module
`lib/src/utils/nested_value_decoder.dart` contains only `dart:convert`/`dart:io`/`dart:typed_data` code, with no
Flutter imports, so it can be unit-tested and moved to an isolate. `GZipCodec` from `dart:io` is available on all three
desktop targets (E12 excludes web). No new dependency (the `archive` package is already present, but `dart:io` is
enough).
*Alternative: Rust `flate2`/`base64` through a bridge call.* Rejected. It needs a bridge round trip for view-only
work, mock regeneration, and there is no second caller.

### D2 Decoder contract
```text
enum DecodeKind { json, base64, gzip }
sealed DecodeResult = DecodedJson(Object? value) | DecodedText(String) | DecodedBytes(Uint8List)
                    | DecodeFailure(DecodeError, {int? limit})
enum DecodeError { invalidJson, invalidBase64, notGzip, corruptGzip, inputTooLarge, outputTooLarge }
DecodeResult decodeValue(Object input /* String | Uint8List */, DecodeKind kind)
Future<DecodeResult> decodeValueAsync(...)   // compute(), sync in isTestMode or below 32 KiB input
```
- `json`: text only. `json.decode`. Any JSON value is a `DecodedJson`. A JSON string literal such as
  `"{\"a\":1}"` therefore yields a text value that can be decoded again (double-encoded JSON).
- `base64`: strip ASCII whitespace, map `-`→`+` and `_`→`/`, pad to a multiple of 4, then `base64.decode`. A
  `FormatException` becomes `invalidBase64`. The bytes go through strict `utf8.decode` (no `allowMalformed`). On
  success the result is `DecodedText`, otherwise `DecodedBytes`.
- `gzip`: text input is Base64-decoded first (step as above, with the same errors). Bytes input is used as is. Input
  without the magic bytes `1f 8b` is `notGzip`. Decompression feeds 64 KiB chunks into
  `GZipCodec().decoder.startChunkedConversion` with a counting `ByteConversionSink`. The sink throws an internal
  exception as soon as the total exceeds the output cap, which yields `outputTooLarge` without buffering the rest.
  Other codec errors are `corruptGzip`. The output is classified as text or bytes like Base64.
- Limits (constants in the module): input ≤ 8 MiB (string length, or byte length), output ≤ 16 MiB. Exceeding the
  input cap is checked before any work starts.
- Isolate: `compute` copies input and output. Both are bounded by the caps, so that is acceptable. A generation
  counter in the caller drops late results (D3, D5).

### D3 Tree integration: decode overlay keyed by row path
`SmartVirtualJsonTreeState` holds `Map<String, NodeDecodeState> _decodes` keyed by `VirtualJsonNode.path`. The states
are `pending(kind)`, `done(kind, result)` and `failed(kind, error, limit)`. It also holds an `int _generation`. When
`widget.json` changes, the map is cleared and the generation is incremented. When a decode completes, the state is
updated only if the generation still matches. The row path is added to `_expandedPaths` so the result is visible at
once.

`JsonTreeFlattener.flatten` gets an optional `Map<String, Object?> decodedValues` (path → decoded value: a JSON
value, a `String`, or a `DecodedBytes`). Primitive branch: if the path has a decoded value, the row gets
`hasChildren: true` and `decodedKind`. When expanded, it traverses the decoded value at depth + 1 under the path
`'$path\u{1F}d'`. The unit separator is very unlikely in real keys. A collision could only mix up expansion state,
because actions depend on the `insideDecoded` flag and not on the path. `insideDecoded: true` is passed down. A decoded Map/List contributes its entries/items directly as children. Text gives one
string row, which can be decoded again because it has its own path. Bytes give one row of the new
`JsonNodeType.binary`. `_findMatchingAncestors` and `hasMatchInSubtree` take the same map, so search expands and
counts decoded content (spec: *Decoded Subtrees Are View-Only*). `VirtualJsonNode` gets `decodedKind` (the row that
owns a decode) and `insideDecoded` (rows under it). With 5.27's `segments`, rows that are `insideDecoded` get no
segments.

Row rendering (`_buildNodeRow`):
- String rows (outside or inside decoded content) and binary rows get one `PopupMenuButton` icon button
  (`Icons.unfold_more`, tooltip and semantics label "Decode as…"). It lists JSON, Base64 and gzip for strings, and
  gzip and "Copy as hex" for bytes. Once decoded, it also lists "Show original only". If 5.27's row context menu
  exists, the same entries are added there.
- `pending`: a 12 px `CircularProgressIndicator` next to the value. `done`: a text chip with the kind ("JSON",
  "Base64", "gzip"), so the state is not shown by colour alone. `failed`: an error icon, the localized reason (with the
  limit in MiB for the size errors) and a dismiss button that removes the entry.
- Pin, filter and path-copy buttons are hidden when `insideDecoded`. The copy button uses `node.value`, which already
  holds the decoded content. With 5.23 in place, objects and arrays are copied as JSON. Binary rows copy hex.

*Alternative: replace the string value in a copy of the JSON and re-flatten.* Rejected. The original would no longer
be visible on the row, pin/filter paths would point to non-existent fields, and copy of the parent would silently
return modified data.

### D4 Epoch tooltip
`EpochGuess? guessEpoch(Object? value)` lives in the decoder module. Only `int` values are checked (`json.decode`
yields `int` for integer literals). The ranges [946684800, 4102444800) are scaled by 1, 1e3, 1e6 and 1e9 for s, ms,
µs and ns. The ranges do not overlap, so the unit is unambiguous. All bounds fit in a 64-bit int. The number row
wraps its text in a `Tooltip` only when the guess is not null. The message is built in the row builder, so only
visible rows pay for it (lazy formatting rule). The first line uses the global mode from 5.27
(`getIt<TimeDisplaySettings>()`, `DateFormatUtils.formatMessageTimestamp`). The second line is ISO-8601 in the other
zone (`DateFormatUtils.isoTimestamp`). The third line is the unit. The tree listens to the notifier so a mode change
applies to the next tooltip. µs/ns values are shown with millisecond precision. The unit line makes clear that the raw
number is finer.
*Alternative: key-name heuristics (`*At`, `timestamp`) as in the old spec text.* Rejected. They miss unnamed fields
and reinterpret values inline, against the "nothing auto-reinterpreted" rule.

### D5 Whole-value decoding in `JsonOrStringViewer`
The viewer gets `List<({DecodeKind kind, DecodeResult result})> _decodeChain` and a generation counter (reset when
`rawContent` changes). A "Decode as…" menu button appears in the toolbar when the content is non-empty and either not a
JSON object/array (text: JSON, Base64, gzip) or binary (Hex mode: gzip). The last chain element decides the view:
`DecodedJson` with Map/List → `SmartVirtualJsonTree`, other JSON values and text → the 5.5 Raw view, bytes → the 5.5
hex view. The "Decode as…" menu stays available on decoded text and bytes, so decodings chain. A banner above the
content names the chain (for example "Base64 → gzip") and offers "Show original" (clears the chain) and "Copy
decoded". The existing copy button keeps copying `rawContent` (spec scenario *Copy keeps the original value*). Match
count and `jumpToMatch` delegate to the active view, so inspector search works in decoded views. A failure shows the
localized reason in the banner and leaves the current view unchanged.

### D6 Header values and key in the shared viewer
The `Key & Headers` tab becomes one vertical scroll view with a Key section and one section per header (header key
title with highlight, copy button, viewer). Each viewer sits in a `ConstrainedBox(maxHeight: …)` (key 280 px,
header 220 px). The viewer then sizes to its content in Raw mode. For Tree mode, `JsonOrStringViewer` gets
`fitTreeHeight` (passing `shrinkWrap: true` to `SmartVirtualJsonTree` / `ScrollablePositionedList.builder`).
Spike S1 verified inside `ConstrainedBox(maxHeight: 220)` inside a `SingleChildScrollView` that
`ScrollablePositionedList.builder(shrinkWrap: true)` sizes a 3-row tree shorter than 220 px, caps a 50-row tree at
220 px, and supports `scrollTo` without assuming a fixed row extent. Header viewers share
`persistenceKey: 'inspector_header'`.

Binary headers: `JsonOrStringViewer` gets `bool recognizeHexFallback` (only headers set it). A value matching
`^0x([0-9a-fA-F]{2})+$` is decoded into bytes and shown in the hex view. Copy still copies the literal value. An empty
value shows the localized "empty value" marker. Rust maps a missing header value to `""`, so "null" cannot be
distinguished and is not claimed.

### D7 Inspector search across sources
- Mounting: the tab body keeps `TabBar`/`TabController` but replaces `TabBarView` by an `IndexedStack`-style body.
  Payload and `Key & Headers` pages are always mounted, so their viewers parse and report counts. Raw JSON and Schema
  are built only while selected. The Schema tab loads from the registry and must not load eagerly. State such as tree
  expansion survives tab switches.
- Sources in fixed order: `payload`, `key`, then per header `headerKey[i]` and `headerValue[i]`. The inspector stores
  `Map<SourceId, int?> counts` (null = still running, fed from `onMatchCountChanged` and 5.5's
  `onSearchStateChanged`). Header-key counts are computed directly (occurrences, case-insensitive, same rule as Raw
  search; keys are short). Total = sum. While any count is null, the bar shows the running state (5.5 adds that UI
  state and string).
- Stepping maps the global index to `(source, localIndex)` by prefix sums. If the source is on another tab,
  `_tabController.animateTo` runs first. After the frame, `Scrollable.ensureVisible` runs on the section's
  `GlobalKey`, then `viewerState.jumpToMatch(localIndex)`. Each viewer gets `focusedMatchIndex` = local index for the
  current source, otherwise null. A header-key match highlights the key title with the active style.
- The query and counts reset on message change, as today (`didUpdateWidget`).

### D8 Small-input fast path
`decodeValueAsync` decodes synchronously below 32 KiB of input. This avoids an isolate spawn per header viewer and per
click on small values. The same threshold is applied in `parseJsonInIsolate`. All header viewers are now mounted, so
otherwise every message with N headers would spawn N isolates. This is the only edit to shared processing code.
Coordinate with 5.5, which edits the same file. Keep the change to one guard line.

## Risks / Trade-offs

- [A UTF-8 header whose text is exactly `0x` + hex pairs is shown as hex bytes] → Rust uses the same form for binary,
  so Dart cannot tell them apart. Copy returns the literal text. A tagged binary flag would need a Rust/bridge change
  (non-goal). Note it for a later change if users report it.
- [Memory: several 16 MiB decodes on one message] → They are user-triggered, bounded per decode and dropped on message
  change. No global cap is added (YAGNI). The spec requires bounded size per decode.
- [Synchronous flatten of a large decoded subtree on the UI thread] → Same cost class as an equally large payload
  today. The output cap bounds it.
- [Mounting all header viewers for every message] → Headers are usually few. The fast path (D8) avoids isolate spawns.
  If profiling shows a problem with hundreds of headers, build header viewers lazily and count with the pure search
  function instead. That would not change the spec.
- [Parallel edits in the same files by 5.5 (viewer, isolate utils), 5.27 (tree rows, inspector header) and 5.23
  (tree copy)] → Implement this change after them (Phase 1b order 5.5 → 5.29 → 5.30). Tasks start by rebasing onto
  their final APIs.
- [`compute` copies up to 8 MiB in and 16 MiB out] → Acceptable for a user action. `Isolate.run` would not avoid the
  copy of the result.

## Migration Plan

None needed. The change is UI-only and has no stored data. The new preference key is `json_view_mode_inspector_header`
(through the existing persistence scheme). Rollback = revert. No Rust, bridge or read-only gate change.

## Open Questions

- Should inline ISO-8601 string formatting in the tree also follow the global local/UTC mode? 5.27 limits that mode
  to Kafka message timestamps. This change only applies it to the epoch tooltip. It can be decided later without
  changing this plan.
- The existing scenario "row copy action SHALL allow copying either the raw timestamp or formatted string" is not
  implemented (copy is raw only). It is kept unchanged in the MODIFIED block. A "Copy formatted" entry fits 5.27's row
  context menu and can be added there or in a follow-up.
