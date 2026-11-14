# Tasks

No Rust or bridge changes (design D1). Skip `flutter_rust_bridge_codegen generate` and `dart run build_runner build`.

## 1. Spikes

- [x] 1.1 Spike S1: in a scratch widget test, put a `ScrollablePositionedList` with 500k `Text.rich` rows inside a
      `SelectionArea`. Confirm that `scrollTo`/`jumpTo` to index 499 999 builds only the rows near the viewport, and
      that a drag selection across visible rows can be copied. Record the result in design.md D3. If it fails, switch
      D3 to its fallback (`SelectableText` per row, or `ListView.builder` + `ensureVisible`) before group 3.
- [x] 1.2 Spike S2: in profile mode on desktop, measure how long the UI isolate is blocked when a 20 MB `String` is
      sent to `compute` versus `Isolate.run`. Record the numbers in design.md (Risks). If it is above ~50 ms, apply
      the Risks mitigation (one `Isolate.run` worker that does both indexing and the first search).

## 2. Pure functions (`lib/src/utils/payload_processing_isolate.dart`)

- [x] 2.1 Add `computeRawRowIndex(text, {maxRowChars = 1024}) -> Int32List` and its isolate wrapper (synchronous
      under `isTestMode`) per D2. Unit tests in `test/src/utils/payload_processing_isolate_test.dart` cover: empty
      text, `\n` and `\r\n` endings, a trailing newline, a 2 MB single line (all rows ≤ 1024 chars, rows concatenated
      == input), a surrogate pair at the cut position, and 20 MB input. `flutter test` on that file passes.
- [x] 2.2 Add `findRawMatches(text, query, {cap = 100000})` returning the offsets plus a `capped` flag, with an
      isolate wrapper and a synchronous path below 64 KiB, per D4. Unit tests cover: case-insensitive matches,
      non-overlapping counting (same results as the current `_buildHighlightedRawText` on sample inputs), offsets
      pointing into the original text when lowercasing changes the length, the cap and its flag, an empty query, and
      20 MB input. Tests pass.
- [x] 2.3 Change `parseHexToBytesInIsolate` to return a `Uint8List` using nibble decoding. Keep the stop-on-invalid
      and ignore-odd-nibble behaviour. Extract `formatHexRow(bytes, row)` and make `_generateHexDump` use it (D6).
      Unit tests: the row format matches the existing dump output for `"Hello World"`, the last partial row is
      padded, invalid hex input gives the same prefix as before. Tests pass.

## 3. Raw view (`lib/src/ui/json_or_string_viewer.dart`)

- [x] 3.1 Replace the 500k truncation, its banner and the `SingleChildScrollView` raw path with a row index computed
      in `_parseContentAsync` (with a progress indicator while it runs, and an inline error state that keeps Copy
      available if it fails), and a `ScrollablePositionedList` of rows inside a `SelectionArea` (D2/D3). Update
      `test/src/ui/json_or_string_viewer_test.dart` so it no longer expects a single `SelectableText`. Existing
      expectations ('Not a JSON string', switching to Raw, copy) still pass.
- [x] 3.2 Move raw search out of `build()`: run `findRawMatches` when the query or payload changes, with a generation
      counter that drops stale results. Highlight per row via binary search over the offsets (a match crossing a row
      boundary is highlighted in both rows). Report the final count through `onMatchCountChanged`, and the state
      through the new optional `onSearchStateChanged` (idle/running/done/capped/failed) (D4/D5). Widget tests:
      highlight count equals the match count, a quick change of query shows only the latest result, a failed search
      reports `failed`.
- [x] 3.3 Make `jumpToMatch(i)` work in Raw mode: binary search for the row of `offsets[i]`, then
      `scrollTo(alignment: 0.5)`. Widget test: jumping to the last match of a long multi-row payload builds that row
      and shows the focused highlight. This fixes `message-inspector-shell` "Jump between matches" in Raw mode.

## 4. Hex view (`lib/src/ui/hex_viewer.dart`)

- [x] 4.1 Change `HexViewer.bytes` to `Uint8List`. Render a `ListView.builder` with a fixed `itemExtent` of rows
      built by `formatHexRow`. Remove `_hexOutput`, the truncation and its banner. Keep "Copy Full Hex Dump"
      unchanged (D6). Update the caller in `json_or_string_viewer.dart` and `test/src/ui/hex_viewer_test.dart`: the
      'Hello World' row content is found in a row widget, the empty placeholder and the copy test still pass.

## 5. Inspector search bar (`lib/src/ui/messages/widgets/message_inspector_panel.dart`) and l10n

- [x] 5.1 Add `searchRunning`, `searchFailed` and `matchesCountCapped` (`{current} / {total}+`, int placeholders) to
      `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`, then run `flutter gen-l10n` (or the build that runs it). The
      generated `AppLocalizations` contains the keys.
- [x] 5.2 Wire `onSearchStateChanged` in the payload `JsonOrStringViewer`. While running, show a small progress
      indicator with the `searchRunning` semantic label instead of the counter. Show `searchFailed` when it failed and
      `matchesCountCapped` when capped. Never show `noMatches` before the search is done. Widget test in
      `test/src/ui/messages/widgets/message_inspector_panel_search_test.dart` covers the running → done and failed states.

## 6. Measurement-based acceptance

- [x] 6.1 Add `test/src/ui/large_payload_viewer_test.dart` per design D7. Synthetic 20 MB text (200k × 100-character
      lines + one 2 MB line), and a 20 MB `Uint8List`. Assert: no `RichText` longer than `maxRowChars`, ≤ 200 built
      raw rows in an 800 px viewport, no truncation banner, a jump to the last match builds a focused-highlighted row,
      the last hex row shows the correct offset, and each `tester.pump()` after the index is ready and after the jump
      takes < 250 ms (Stopwatch). `flutter test test/src/ui/large_payload_viewer_test.dart` passes.

## 7. Final verification

- [x] 7.1 Run `dart format lib test` (no diff left), `flutter analyze` (no issues), `flutter test` (all green) and
      `scripts/check_read_only.sh` (passes unchanged). Cargo steps are not needed (no Rust touched). Manually open a
      payload larger than 500k characters in the app and confirm there is no truncation notice and that search
      next/previous scrolls in Raw mode.
