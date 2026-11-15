# Proposal: structural-message-diff

Source: `design/kafkalyzer_verbesserungskonzept_und_roadmap.md`, §5.8 (change id `structural-message-diff`, size M),
decision E11 ("structural JSON diff moves to `kafkalyzer-core`; view state and text diff stay Dart"), guardrails L1,
L2, L3, L5 and L7 of §1. Phase 2b ("Analysekern"). Follow-up consumers: `poison-pill-compare` (§5.12),
`script-run-comparison` (§5.15) and the MCP tool `kafka_diff_messages` (§5.17 follow-up `mcp-extended-tools`).

## Why

The message diff is computed in Dart by the git dependency `json_diff` (`google/dart-json_diff`, unpinned `HEAD`).
It cannot be reused by the Rust-side consumers planned in §5.12/§5.15/§5.17, it has no spec and almost no tests, and
it has visible defects: a reordered array shows "No differences found." (moves are detected but never rendered),
two equal top-level scalars are reported as changed, and volatile fields (timestamps, ids) bury the real change in
every card with no way to hide them.

## What Changes

- **Core diff (`kafkalyzer_core::json_diff`):** compares two JSON documents given as text and returns a flat,
  deterministically ordered list of entries `{path, segments, kind (added|removed|changed), old, new}`. `path` uses
  the canonical L7 notation (`json_path::build_canonical_path`); `old`/`new` are compact JSON text, absent on the
  missing side, so JSON `null` and a missing field stay distinct. Type changes are one `changed` entry. Arrays are
  aligned by common prefix and suffix and paired by position in the middle (linear cost). Objects keep document key
  order (order-preserving parse local to the module). Non-JSON input is reported as such, never as "no differences".
- **Ignore list in the core:** a list of field paths (L7 syntax, no wildcards) suppresses entries at or below each
  path; the result reports how many entries were hidden. Optional entry cap with a total count and a truncation flag.
- **Bridge:** one async batch function `diff_json_batch(requests, max_entries)` with local DTOs; runs off the UI
  thread. No per-card bridge calls: the diff view batches the pending cards.
- **Dart:** `MessageDiff` and `JsonDiffWidget` switch from `json_diff` to the bridge result; a tree builder turns the
  flat entries into the existing `DiffViewNode` tree so the rendered diff stays identical. The text diff
  (`diff_match_patch`) stays in Dart unchanged. `script_schemas_view.dart` (a third, so far unlisted user of
  `json_diff`) moves to the same bridge call. **The git dependency `json_diff` is removed from `pubspec.yaml`.**
- **Diff view ignore list:** per topic, stored in shared_preferences (`diff_ignore_paths_<topic>`), edited in a small
  dialog opened from a header above the diff timeline and from a "hidden (n)" line on a card; a row context menu
  offers "Ignore this field". Suggestions for volatile fields (timestamp/time/date/…At, id/uuid/trace ids) taken from
  paths that actually changed are offered but never enabled automatically.
- **Intended behaviour fixes:** reordered arrays and equal top-level scalars are diffed correctly; everything else
  renders as before (pinned by fixtures captured from the current `json_diff` output before it is removed).

## Capabilities

### New Capabilities
- `message-structural-diff`: structural comparison of two JSON message payloads (entry model, paths, ordering,
  array/type/null semantics, non-JSON outcome, ignore list, entry cap) and the diff view behaviour built on it
  (predecessor pairing per topic and key, rendering, per-topic ignore list with hidden count and suggestions). The
  diff view had no spec so far (confirmed: no requirement in `openspec/specs/` describes `MessagesDiffView` content;
  `message-inspector-shell` only covers its selection highlight).

### Modified Capabilities
- None. `message-selection-and-copy` (*Compare Two Selected Messages*, already in `openspec/specs/` although its
  change `message-selection-copy-and-display` is not implemented) keeps its requirements; its comparison dialog will
  use the API of this change instead of `json_diff`. `json-path-resolution` is unchanged: diff paths are produced by
  the existing `build_canonical_path` and ignore entries are parsed by the existing `FieldPath`.

## Read-only impact

No new Kafka or Schema Registry calls. The change is pure computation over payloads already loaded in the app;
`scripts/check_read_only.sh` must pass unchanged.

## Prerequisites and coordination

- No hard prerequisite. Implement before `poison-pill-compare` (§5.12) and `script-run-comparison` (§5.15).
- `message-selection-copy-and-display` (§5.27, open): its planned `MessageCompareDialog` calls
  `MessageDiff.computeDiff` + `JsonDiffWidget`. Whichever lands second adapts: if §5.27 lands first, this change
  migrates the dialog; otherwise §5.27 uses the new signatures (same names kept on purpose). Its design note that a
  top-level JSON array makes the current differ fail is not accurate (top-level arrays are diffed; mixed top-level
  types yield one root-level change); with this change neither case is an error.
- `accessibility-and-l10n-sweep` (open): diff colours in `json_diff_widget.dart` are its declared non-goal and stay
  as they are here too; the literals in `script_schemas_view.dart` belong to its group 9 and are not touched beyond
  the diff call. New strings of this change are localized (en + de) and must pass its hard-coded-string guard
  (`test/l10n/hardcoded_strings_guard_test.dart`).

## Non-Goals

- Wildcards or patterns in ignore paths (`items[*].ts`, `**`), regex keys — L7 has none; see design.
- LCS/Myers array alignment and move detection; semantic (schema-aware) diff of Avro/Protobuf beyond their JSON form.
- Changing the diff colours, icons or tree layout; rendering the computed text diff in the timeline diff view
  (that is §5.27's comparison dialog).
- Comparing keys or headers; a diff between arbitrary messages outside the existing pairing (§5.27, §5.12).
- The MCP tool itself (§5.17 follow-up); the poison-pill and script-run comparison UIs (§5.12, §5.15).
- Syncing ignore lists across machines or per cluster.

## Impact

- Rust: new `rust/kafkalyzer-core/src/json_diff.rs` (+ `lib.rs` export), new bridge module `rust/src/api/json_diff.rs`
  (+ `mod.rs`); generated `lib/src/rust/**` and `test/src/rust/api/rust_mocks.mocks.dart` regenerated.
- Dart: `lib/src/features/scripting/presentation/widgets/diff/{message_diff.dart,json_converter.dart,
  json_diff_widget.dart}`, new batcher next to them, `lib/src/ui/messages/views/messages_diff_view.dart`,
  `lib/src/features/scripting/presentation/widgets/script_schemas_view.dart`, new
  `lib/src/services/diff_ignore_list_service.dart` + DI registration, new ignore-list dialog widget.
- `pubspec.yaml`/`pubspec.lock`: remove `json_diff` (git); `diff_match_patch` stays.
- `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`; tests: shared fixture file, Rust unit tests, Dart widget/unit tests,
  updated `messages_diff_view_test.dart`, `messages_view_test.dart`, `messages_view_stepper_test.dart` (bridge mock).
- Settings export/import picks up the new preference keys automatically (it copies all keys).
