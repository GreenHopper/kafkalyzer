# Tasks

No Rust crate or `rust/src/api/` change, so there are no bridge or mock regeneration steps. All work is Dart.

## 1. Prerequisites and spike

- [x] 1.1 Confirm that `fix-result-view-defects` (5.23), `message-selection-copy-and-display` (5.27) and
  `chunked-raw-and-hex-viewer` (5.5) are merged. Note the APIs used later: tree JSON copy, `TimeDisplaySettings` +
  `DateFormatUtils.formatMessageTimestamp`/`isoTimestamp`, `VirtualJsonNode.segments` and the tree row context menu,
  Raw `jumpToMatch` + `onSearchStateChanged` + `Uint8List` hex bytes. Verify: `flutter test` is green on the base
  branch.
- [x] 1.2 Spike S1 (design D6): inside a `ConstrainedBox(maxHeight: 220)`, size `SmartVirtualJsonTree` to its content.
  Compare `ScrollablePositionedList(shrinkWrap: true)` with "row count × fixed row extent". Check that `scrollTo` to a
  match still works in both. Record the choice in design D6. Verify: a throwaway widget test shows a 3-row tree
  shorter than 220 px and a 50-row tree capped at 220 px with a working jump.

## 2. Decoder module (pure Dart)

- [x] 2.1 Add `lib/src/utils/nested_value_decoder.dart` with `DecodeKind`, `DecodeResult`, `DecodeError`, the
  8 MiB/16 MiB limits and `decodeValue` for json/base64/gzip as in design D2 (Base64 normalisation, strict UTF-8
  text/bytes classification, gzip magic check, chunked gunzip with a counting sink). Verify:
  `test/src/utils/nested_value_decoder_test.dart` covers valid/invalid JSON, a JSON string literal, standard/URL-safe/
  unpadded/multi-line Base64, invalid Base64, text vs binary output, gzip from text and from bytes, `notGzip`,
  `corruptGzip`, `inputTooLarge`, and a gzip bomb (more than 16 MiB output) that returns `outputTooLarge` while the
  sink never holds more than the cap plus one chunk.
- [x] 2.2 Add `decodeValueAsync` (`compute`, synchronous in `isTestMode` or below 32 KiB input) and the same 32 KiB
  guard in `parseJsonInIsolate` (design D8). Verify: unit tests for both paths, and the existing
  `json_or_string_viewer_test.dart` still passes.
- [x] 2.3 Add `guessEpoch` (int only, the four ranges from design D4). Verify: unit tests for the lower and upper bound
  of each unit, `42`, `3.5`, negative numbers and values between the ranges.

## 3. Tree: on-demand decoding and epoch tooltip

- [x] 3.1 Extend `VirtualJsonNode` (`decodedKind`, `insideDecoded`) and `JsonNodeType.binary`. Pass the
  `decodedValues` map through `JsonTreeFlattener.flatten`, `_findMatchingAncestors` and `hasMatchInSubtree`
  (design D3). Verify: `json_tree_flattener_test.dart` has new cases: decoded children appear only when expanded,
  rows inside them have `insideDecoded`, decoded text can carry its own decoded value (chain), search matches and
  expands inside decoded content, and the output without decoded values is unchanged.
- [x] 3.2 In `SmartVirtualJsonTree`: decode overlay state with a generation counter, a "Decode as…" menu on string and
  binary rows, pending/done/failed rendering with a kind chip and a dismissible error, "Show original only", binary
  row (byte count, hex preview, copy as hex, gzip), and pin/filter/path-copy hidden inside decoded content. Add the
  new strings to `app_en.arb` and `app_de.arb`. Verify: `smart_virtual_json_tree_test.dart` covers each scenario of
  *On-Demand Decoding of Tree Text Values*, *Bounded Off-Thread Decoding with Error Display* and *Decoded Subtrees Are
  View-Only* (including: a new `json` clears decoded views and drops a late result).
- [x] 3.3 Add the same decode entries to 5.27's tree row context menu. Verify: a widget test opens the context menu on
  a string row and decodes from there.
- [x] 3.4 Epoch tooltip on integer rows, using the global mode from `TimeDisplaySettings` and listening for changes.
  Add en+de strings for the unit names. Verify: widget tests check the tooltip text for `1768812660123` in local and
  in UTC mode, show no tooltip for `42` and `3.5`, and show UTC first after switching the mode. The number text
  itself stays unchanged.

## 4. Viewer: whole-value decoding, header support

- [x] 4.1 In `JsonOrStringViewer`: decode chain, toolbar "Decode as…" menu (text: JSON/Base64/gzip, Hex mode: gzip),
  banner with the chain, "Show original" and "Copy decoded", the original copy button unchanged, and match count and
  `jumpToMatch` delegated to the active decoded view. Add en+de strings. Verify: `json_or_string_viewer_test.dart`
  covers the three *Whole-Value Decoding in the Payload Viewer* scenarios, an error banner on invalid Base64, and a
  search count inside a decoded tree.
- [x] 4.2 Add `recognizeHexFallback` (`0x` + hex pairs → hex view, copy returns the literal), the "empty value" marker
  and `fitTreeHeight` as decided in spike 1.2. Add en+de strings. Verify: widget tests for a binary header value, an
  empty value, a text value that is not hex, and a small JSON value shorter than the cap.

## 5. Inspector: header viewer and cross-source search

- [x] 5.1 Keep the Payload and `Key & Headers` pages mounted. Build Raw JSON and Schema only while selected
  (design D7). Verify: a widget test shows that the Schema view is not built before its tab is selected, and that tree
  expansion in the Payload tab survives a switch to `Key & Headers` and back. Existing `message_inspector_panel_test.dart`
  tests pass.
- [x] 5.2 Rebuild the `Key & Headers` tab: Key section and one section per header with the shared viewer
  (`recognizeHexFallback`, `persistenceKey: 'inspector_header'`, max heights from design D6), header key title, and
  per-header copy and copy-all kept. Move the touched literals (`'Key'`, `'Headers (n)'`) to en+de ARB. Verify:
  updated `message_inspector_panel_test.dart` covers the *Message Headers UI Display* scenarios (list, JSON tree,
  binary hex, decode on demand, empty value) and the header-count badge scenario of *Structured Multi-Tab Inspection*.
- [x] 5.3 Cross-source search: per-source counts (null = running, from `onMatchCountChanged`/`onSearchStateChanged`;
  header keys counted directly), summed total, running state, prefix-sum mapping, tab switch + `ensureVisible` +
  `jumpToMatch`, active highlight on header-key matches, and reset on message change. Verify:
  `message_inspector_panel_search_test.dart` updates the fixture expectation from `1 of 2` to `1 of 3` (key
  `order-1234`) and adds tests for each scenario of *In-Inspector Value Search and Match Stepping*: summed count
  (2+1+1), stepping into `Key & Headers` and wrapping back, a jump in Raw mode, a header match counted while the
  Payload tab is shown, and "running" instead of "No matches".

## 6. Localization review

- [x] 6.1 Check that every string added in groups 3–5 exists in `app_en.arb` and `app_de.arb` with a German
  translation, and that the new UI has no hard-coded user-facing literals. Verify: `flutter gen-l10n` reports no
  untranslated messages for `de`, and `grep` over the changed widget files finds no new string literals in `Text(`,
  `tooltip:` or `SnackBar`.

## 7. Final verification

- [x] 7.1 Confirm that `git diff --stat` shows no change under `rust/` (so `cargo fmt`/`clippy`/`test` and bridge
  regeneration do not apply). Then run `dart format --set-exit-if-changed lib test`, `flutter analyze`,
  `flutter test` and `scripts/check_read_only.sh`. Verify: all exit 0, and the read-only gate passes unchanged.
- [x] 7.2 Manual check against `docker-compose.yaml`: a message with a Base64+gzip JSON field, a double-encoded JSON
  string, an epoch-millisecond field, a binary header and a Base64 header. Decode each, step the search through payload,
  key and headers in Tree and Raw mode, and decode a multi-megabyte value while scrolling the table. Verify: the
  results match the spec scenarios, the UI stays responsive, and no Kafka request is issued by decoding (broker
  request log unchanged).
