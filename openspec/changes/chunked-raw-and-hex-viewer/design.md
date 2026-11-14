# Design: chunked-raw-and-hex-viewer

## Context

See proposal.md (Why). Current state, verified in code:

- `JsonOrStringViewer` (`lib/src/ui/json_or_string_viewer.dart`) has the view modes Raw (0), Tree (1) and Hex (3,
  binary only). Raw mode cuts the text at 500 000 characters (l.212-237) and wraps it in a `SingleChildScrollView`.
  `_buildHighlightedRawText` lowercases the whole text and builds one `TextSpan` per match inside `build()`, so this
  runs on the UI thread on every rebuild. It reports the match count through a post-frame callback.
  `jumpToMatch()` only forwards to the tree (l.66-70).
- `HexViewer` (`lib/src/ui/hex_viewer.dart`) builds the full dump in an isolate, keeps at most 500 000 characters of
  it (l.45-51) and shows them in one `SelectableText`. "Copy Full Hex Dump" builds the dump again in an isolate.
- Binary payloads reach Dart as the string `"<Binary Data>:<hex>"` (Rust `decode_message_component`,
  `kafka_consumer.rs:1418-1424`). `_hexToBytes` decodes them into a growable `List<int>` (8 bytes per element on
  64-bit, about 160 MB for a 20 MB payload) using `substring` and `int.parse` per byte.
- In `payload_processing_isolate.dart`, `isTestMode` runs the functions synchronously under `flutter test`. The
  existing `compute` helpers live there.
- Callers: `MessageInspectorPanel` (payload with search, key without search) and `TopicSchemaInspectorView`. Both
  call `jumpToMatch` and use `focusedMatchIndex` and `onMatchCountChanged`. Every caller gives the viewer a bounded
  height (`expand: true`, or a `SizedBox`).
- `SmartVirtualJsonTree` already uses `ScrollablePositionedList` with `scrollTo(index:, alignment: 0.5)` for jumping
  to a match. This is the pattern to copy.

## Goals / Non-Goals

**Goals:**
- Per-frame cost in Raw and Hex mode depends only on the viewport, not on the payload size.
- No O(payload) work on the UI thread after the payload is shown, except the existing `startsWith` and string
  identity checks.
- Raw-mode search behaves the same as Tree-mode search (count, focus, scroll to match).

**Non-Goals:**
- A custom text render object. Selecting across rows that are not built (copying beyond the viewport uses the Copy
  button). Syntax highlighting. Any change to Tree mode.

## Decisions

### D1: Layer = Dart only
Splitting rows, searching and formatting hex rows are pure view work for one widget. They have no second caller: MCP
caps payloads itself, and scripts do not render. Following the project rule "logic moves to Rust only with a second
caller", the code stays in `lib/src/utils/payload_processing_isolate.dart` as pure top-level functions. Unit tests can
call them directly. There is no bridge change.

### D2: Raw rows = bounded segments, indexed off-thread
`computeRawRowIndex(String text, {int maxRowChars = 1024}) -> Int32List` returns the start offset of each display row.
A row ends after a `\n`, or after `maxRowChars` UTF-16 code units, whichever comes first. A cut never splits a
surrogate pair: if the cut would land between a high and a low surrogate, it moves back one code unit. `\r\n` stays
inside one row. A trailing `\n` does not create an extra empty row. The UI renders row `i` as
`text.substring(start[i], end[i])` with the final line break removed, and soft-wraps it.

Size: about `(len / 1024 + lineCount) * 4` bytes. For 20 MB of pretty JSON (about 400k lines) that is about 1.6 MB.

- *Alternative: split only at `\n`.* Rejected. A 20 MB minified JSON is one line, and laying it out would cost as
  much as today.
- *Alternative: wrap by viewport column count* (exact visual lines, fixed `itemExtent`). Rejected for now. The index
  would depend on the width and font metrics and would have to be rebuilt on every resize. Bounded segments keep
  layout per row bounded (at most 1024 characters), and resizing costs nothing.

### D3: Raw list widget = `ScrollablePositionedList` inside `SelectionArea`
Rows have variable height because they soft-wrap. `ScrollablePositionedList`, already a dependency, can jump to an
index without knowing the height of the rows before it. This is the same approach as `SmartVirtualJsonTree`. Each
row is a `Text.rich`. Mouse selection uses one `SelectionArea` around the list, so selection works across the rows
that are built. Copy remains the way to get everything. Raw mode is no longer wrapped in `SingleChildScrollView`; it
takes the bounded height it is given, like Tree mode.

- *Alternative: `ListView.builder`.* Rejected. Jumping to row N with variable row heights needs an estimate and is
  inaccurate.
- *Alternative: one `SelectableText` per row.* Selection would stop at each row; this is the fallback if spike S1
  fails.

### D4: Search = offsets in an isolate, capped
`findRawMatches(String text, String query, {int cap = 100000}) -> ({Int32List offsets, bool capped})`. It searches
case-insensitively and does not count overlapping matches, the same rules as today. The offsets point into the
original text. The function lowercases the text and the query. If lowercasing changes the length (a rare Unicode
case), it falls back to ASCII-only case folding so the offsets stay correct.

The viewer runs the search in an isolate (`compute`, synchronous in tests, as `isTestMode` already does) when
`searchQuery` changes or the payload changes. A generation counter drops results of outdated queries. Rows find
their matches by binary search over `offsets`, and a match that crosses a row boundary is highlighted in both rows.
The focused match uses the existing highlight style. `jumpToMatch(i)` in Raw mode looks up the row of `offsets[i]`
by binary search over the row index and calls `scrollTo(index:, alignment: 0.5)`.

Below 64 KiB the function runs synchronously on the UI thread, using the same pure function. This avoids the cost of
starting an isolate and a progress flicker for every keystroke on normal messages.

- *Alternative: debounce the query.* Not needed. One search over 20 MB takes tens of milliseconds, the generation
  counter already drops stale results, and debouncing would add latency for small payloads.

### D5: Search state reporting
The viewer gets an optional callback `ValueChanged<RawSearchState>? onSearchStateChanged`. The state is an enum:
idle, running, done, capped, or failed. `onMatchCountChanged` keeps its meaning and is called with the final count
only (capped count = cap). `MessageInspectorPanel` shows a small progress indicator while the state is running,
`l10n.searchFailed` when it failed, and `l10n.matchesCountCapped(current, total)` when capped. It never shows
`noMatches` before the search is done. `TopicSchemaInspectorView` does not need the callback; its payloads are
small.

### D6: Hex = `Uint8List` + lazily formatted fixed-extent rows
`parseHexToBytesInIsolate` returns a `Uint8List`, decoded through a nibble lookup with no `substring` or `int.parse`.
Its behaviour on bad input stays the same: decoding stops at the first invalid pair, and a trailing odd nibble is
ignored. `HexViewer.bytes` becomes `Uint8List`. This is a breaking change only for its single internal caller and
the tests.

The view is a `ListView.builder` with a fixed `itemExtent`, one row per 16 bytes, so jumping is exact. Each row is
built by `formatHexRow(bytes, rowIndex)`, which uses the same layout as `_generateHexDump` (shared code, so Copy and
display cannot drift apart). The full dump is no longer built for display. "Copy Full Hex Dump" keeps its existing
behaviour.

### D7: Measurement-based acceptance (widget test)
A new test, `test/src/ui/large_payload_viewer_test.dart`, uses synthetic payloads: 20 MB of text made of about 200k
lines of 100 characters plus one 2 MB line with no line break, and a 20 MB `Uint8List`. It checks:

1. No `RichText` in the tree contains more than `maxRowChars` characters (no huge `TextSpan`).
2. The number of built raw rows is at most a small bound (for example 200) for an 800 px viewport.
3. No truncation banner is shown, and after `jumpToMatch` to a match near the end, that row is built and contains the
   focused highlight.
4. Hex: after jumping to the end, the last row shows the correct offset (`(len-1) & ~0xF` in hex).
5. Coarse frame budget: a `Stopwatch` around each `tester.pump()` after the index is ready and after the jump stays
   below 250 ms. Laying out the old 500k-character `TextSpan` took seconds, so a 10× margin keeps the check stable
   and still catches a return to whole-text layout.

The index and search functions also get unit tests on the 20 MB input (correctness, cap, surrogate pairs, `\r\n`,
an empty string, a match crossing a row boundary). Steps 1 to 4 are the gate. Step 5 is a guard.

## Risks / Trade-offs

- [Copying the 20 MB string into the isolate for indexing and search] → This already happens today for JSON parsing.
  Spike S2 measures it. If the copy blocks the UI thread for more than about 50 ms, the index is computed once and
  the search reuses the same worker, using `Isolate.run`, which can share immutable data inside the isolate group.
- [Selection cannot extend beyond built rows] → This is documented. The Copy button returns everything, which is the
  existing behaviour for large payloads.
- [A 20 MB clipboard write can be slow or rejected by the OS] → This is unchanged from today and outside this
  change's control. The SnackBar reports success only after `Clipboard.setData` returns.
- [`ScrollablePositionedList` with 500k items] → Spike S1 confirms that `scrollTo` and `jumpTo` stay O(viewport).
  Fallback: `ListView.builder` with an estimated extent plus `ensureVisible` correction.
- [Stopwatch-based test flakiness in CI] → It has a large margin and is not the only gate (D7 steps 1 to 4 are
  deterministic).
- [Segment cuts inside words look like wrap points] → Accepted. The rows are soft-wrapped anyway, so a cut at 1024
  characters looks like a normal wrap.

## Migration Plan

UI-only, no stored data. The persisted view-mode preference keys (`json_view_mode_*`, `json_hide_null_*`) keep their
meaning. To roll back, revert the commit.
