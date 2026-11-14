# Proposal: chunked-raw-and-hex-viewer

Roadmap: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md` §5.5 (Phase 1b), residual of §2.1 row
"Virtualisierter Lazy-Loading-Tree".

## Why

The tree view is virtualised, but the Raw and Hex views of the payload viewer still put the whole text into one
selectable text widget and therefore cut the display at 500 000 characters (`json_or_string_viewer.dart:212-237`,
`hex_viewer.dart:45-51`). Large payloads, especially non-JSON text and binary data with no tree view, can only be read
after copying them out of the app. In Raw mode the in-message search also scans the full text on the UI thread
during every rebuild and cannot scroll to a match (`jumpToMatch` only works in Tree mode). This breaks the existing
`message-inspector-shell` requirement that next/previous scrolls to the match.

## What Changes

- Raw view renders payloads of any size as a virtualised list of bounded text rows. Only visible rows are laid out.
  Row boundaries are computed off the UI thread. The 500 000-character cap and its warning banner are removed.
- Hex view renders binary payloads of any size as a virtualised list of 16-byte rows. Each row is formatted only when
  it is built, from a compact byte buffer. The full hex dump is no longer built for display, and the 500 000-character
  cap and its banner are removed.
- Raw-mode search computes match positions off the UI thread and stores them up to a fixed limit. The UI shows when
  that limit is reached. Next/previous (Enter, Shift+Enter, the arrow buttons) scrolls the Raw view to the focused
  match. Until a search finishes, the counter shows that it is running, not "No matches". A failed search shows an
  error.
- Copy still returns the complete, unchanged raw payload. "Copy Full Hex Dump" still returns the complete hex dump.
  Message export is not affected (it never went through the viewer).
- **BREAKING (spec):** the `large-message-handling` requirement *Output Truncation* is removed and replaced by
  virtualised rendering requirements. Users and stored data need no migration.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `large-message-handling`: remove *Output Truncation*. Add requirements for virtualised Raw/Hex rendering without a
  size cap, full-data copy, and off-UI-thread Raw search with a bounded match list.

Fixed without a spec delta: `message-inspector-shell` *In-Inspector Value Search and Match Stepping* already requires
that next/previous "scroll and focus to the next matching node/text". In Raw mode the code does not do this today,
so this change fixes the deviation without changing the spec.

## Impact

- Code (Dart only): `lib/src/ui/json_or_string_viewer.dart`, `lib/src/ui/hex_viewer.dart`,
  `lib/src/utils/payload_processing_isolate.dart` (row index, match search, `Uint8List` hex decoding),
  `lib/src/ui/messages/widgets/message_inspector_panel.dart` (pending/failed/capped counter states). The Raw-mode
  jump also fixes `topic_schema_inspector_view.dart`, which calls the same `jumpToMatch`; that file needs no change.
- Tests: `test/src/ui/json_or_string_viewer_test.dart` and `test/src/ui/hex_viewer_test.dart` currently expect one
  `SelectableText` that holds the whole text, so they need updating. New unit tests cover the pure index and search
  functions. A new widget test uses a synthetic 20 MB payload.
- l10n: a few new keys (search running, search failed, capped match count) in `app_en.arb` and `app_de.arb`.
- No Rust, bridge, or dependency changes. `scrollable_positioned_list` is already a dependency.
- **Read-only impact:** no new Kafka or Schema Registry calls. This is a pure UI/rendering change, and
  `scripts/check_read_only.sh` must pass unchanged.

## Prerequisites

- `fix-result-view-defects` (5.23) and the other Phase-0 changes are implemented first, as required by roadmap E14.
  None of them touches the payload viewer, so there is no functional dependency and no overlapping edit.

## Non-Goals

- Tree view: already virtualised (`smart-virtual-json-tree`).
- Searching the message key or headers, and nested/embedded payload decoding: owned by `nested-payload-decoding`
  (5.30).
- Searching inside the Hex view, a Hex toggle for text payloads, line numbers, a "save payload to file" action, and
  editing.
- Translating the hard-coded strings this change keeps as they are ("Copy content", "Raw"/"Tree", "Copy Full Hex
  Dump", hex snackbars): owned by `accessibility-and-l10n-sweep` (5.32). Only strings this change adds go to the ARB
  files.
- Copying message rows or selections, and the time display: owned by `message-selection-copy-and-display` (5.27).
- Raising Kafka fetch or message-size limits.
