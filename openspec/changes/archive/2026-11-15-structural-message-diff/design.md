# Design

## Context

See proposal.md for motivation; requirements are in `specs/message-structural-diff/spec.md`.

Current code (verified on disk, working tree with uncommitted edits of other changes):

- `widgets/diff/message_diff.dart`: `MessageDiff.computeDiff(older, newer)` decodes both payloads with `jsonDecode`
  (null/empty → `{}`), then `JsonDiffer.fromJson(...).diff()` (git `json_diff`, resolved ref `92c700f`) or, if one side
  is not JSON, `DiffMatchPatch().diff(...)`. Payloads ≥ 30 000 chars go through `compute()` (isolate), smaller ones run
  on the UI thread. `textDiffToPrevious` is computed but rendered nowhere (§5.27 finding confirmed).
- `widgets/diff/json_converter.dart`: `JsonConverter.fromDiff(DiffNode)` builds `DiffViewNode`s. Per level it emits
  **added, removed, changed, then nested nodes**; added/removed containers are expanded child by child with the same
  type; `DiffNode.moved` is ignored. Root key of a top-level type change is `''`.
- `widgets/diff/json_diff_widget.dart`: `JsonDiffWidget(diffNode:)` renders that tree (hard-coded `Colors.*`, a declared
  non-goal of `accessibility-and-l10n-sweep`), "No differences found." when empty.
- `ui/messages/views/messages_diff_view.dart`: pairs each message with the previous one of the same `topic/key`
  (sorted by timestamp), caches one `Future<MessageDiff>` per message id, starts a diff 250 ms after a card mounts
  (50 ms when cached). One diff = one computation; no batching. Non-JSON → payload preview (text diff unused).
- `script_schemas_view.dart` also uses `JsonDiffer` **synchronously inside `build()`** and for a Markdown export
  (`_diffNodeToMarkdown`, dot-joined keys). Not listed in the roadmap; must move too or `json_diff` cannot be removed.
- Observed `json_diff` behaviour (run against the pinned package): reordered `[1,2,3]`→`[3,1,2]` yields only `moved`
  → rendered as "No differences found."; `5` vs `5` at top level → `changed['']`; `1` vs `1.0` equal (Dart `==`);
  middle insertion → `added[1]`; objects: left-order for removed/changed, right-order for added; list elements are
  compared with *unordered* deep equality.
- Tests: the roadmap's "existing widget tests as safety net" barely exists — one test asserts a `JsonDiffWidget`
  appears (`messages_diff_view_test.dart`); `JsonConverter`, `MessageDiff` and the widget's rows are untested.
- Rust: `kafkalyzer-core` uses `serde_json` without `preserve_order` (objects are `BTreeMap`, key-sorted). Workspace
  feature unification means enabling `preserve_order` would also change key order of every decoded Avro payload and
  every `json_path` container rendering. `json_path::build_canonical_path` (dot when all segments are safe, else JSON
  Pointer; digit-only segments are "unsafe") and `FieldPath::parse(..).tokens()` exist and are reused.
- Bridge functions are plain `pub fn` → async `Future` in Dart, executed on the frb worker pool (off the UI isolate).
- The hard-coded-string guard (`test/l10n/hardcoded_strings_guard_test.dart` + allowlist) exists.

## Goals / Non-Goals

**Goals:** one diff engine in the core for GUI, MCP and later comparisons; byte-identical rendering of the existing
cases; per-topic ignore list; no git dependency; no per-card bridge call.

**Non-Goals (design level):** no new Rust crate or Dart package; no change of `json_path` grammar or of
`build_canonical_path`; no global `serde_json` feature change; no move of the `widgets/diff/` files to another
directory; no change of the predecessor pairing.

## Decisions

### D1 Layering (E11)
- `kafkalyzer-core::json_diff` (new): parse, compare, ignore filtering, cap. Pure, serde types, unit-tested. Ignore
  filtering is in the core (not Dart) because MCP (`kafka_diff_messages`) and `script-run-comparison` need the same
  semantics and the hidden count.
- Bridge `rust/src/api/json_diff.rs`: DTOs + one function, mapping only.
- Dart: `jsonDecode`-free orchestration, the tree builder (presentation), text diff (`diff_match_patch`, E11), ignore
  list storage, suggestions heuristic (GUI-only; moves to core only when a second caller appears).
- `kafkalyzer-kafka`: untouched (no I/O).

### D2 Core API
```rust
pub enum DiffKind { Added, Removed, Changed }            // serde: "added" | "removed" | "changed"
pub struct DiffEntry { path: String, segments: Vec<String>, kind: DiffKind,
                       old: Option<String>, new: Option<String> }   // compact JSON text; None = side missing
pub struct DiffOptions { ignore: Vec<FieldPath>, max_entries: Option<usize> }
impl DiffOptions { pub fn new(ignore_paths: &[String], max_entries: Option<usize>) -> Self } // skips unparseable
pub enum DiffOutcome {
    Json { entries: Vec<DiffEntry>, hidden: usize, total: usize, truncated: bool },
    NotJson { old_is_json: bool, new_is_json: bool },
}
pub fn diff_json(old: &str, new: &str, options: &DiffOptions) -> DiffOutcome;
```
- Strings in, because every consumer holds payload text (GUI, poison-pill, script runs, MCP). `DiffOptions` is built
  once per call/batch so ignore paths are parsed once (no parsing in loops). `total` counts visible entries before
  the cap; `hidden` counts ignored ones. All types derive `Serialize`/`Deserialize` for the MCP tool.
- *Alternative:* a `Result<_, Error>` for non-JSON — rejected: non-JSON is an expected outcome that triggers the Dart
  text diff, not an error. Real errors cannot occur after successful parsing.

### D3 Order-preserving parse local to the module
A private `enum Node { Null, Bool, Number(serde_json::Number), String, Array(Vec<Node>), Object(Vec<(String, Node)>) }`
with a `Deserialize` visitor; `serde_json::from_str::<Node>` keeps document key order. Duplicate keys: value replaced
in the first position (same as Dart `LinkedHashMap`). Value text for entries is written by a small serializer over
`Node` (compact, keys in document order) so re-decoding it in Dart gives the same `toString()` as before.
- *Alternative:* enable `serde_json/preserve_order` — rejected: workspace-wide feature unification changes key order
  of decoded Avro payloads and `json_path` container output (visible elsewhere).
- *Alternative:* sorted keys — rejected: breaks "rendering identical" for every object with more than one change.
- Object lookup during compare: build a `HashMap<&str, usize>` index for objects with more than 16 keys, linear scan
  otherwise (keeps large objects linear).
- serde_json's recursion limit (128) stays: deeper documents are reported `NotJson` and fall back to the text view.
  The spike measures whether any realistic payload hits it.

### D4 Comparison semantics
- Objects: walk old keys in order → `removed` (missing in new), recurse (same container type), `changed` (scalar
  differs or type differs); then new-only keys in new order → `added`. Containers added/removed whole = one entry.
- Numbers: equal if both fit `i64`/`u64` and are equal, else compare as `f64` (matches Dart `1 == 1.0`).
- Arrays (spec *Array Alignment With Bounded Cost*): common prefix, common suffix (not overlapping), then positional
  pairing of the middle window at the same index `p+k`; surplus → `removed` (old index) / `added` (new index). Deep
  equality is ordered for arrays, unordered for objects. Linear in elements; each element is visited at most by
  prefix/suffix equality plus one recursion, so `O(size · depth)` worst case.
  - *Alternative:* index-only pairing — rejected: a single insertion in the middle would mark every later element
    changed (json_diff reported one `added`, so rendering would regress).
  - *Alternative:* LCS/Myers with move detection — rejected for now: `O(n·d)`/`O(n·m)` needs a cap and a fallback,
    and moves have no `kind` in the roadmap model. Scattered multi-insertions degrade to positional pairing; accepted
    and documented (`shortcut:` comment in code).
  - Deviation from json_diff: reorders now produce entries (defect fix); nested arrays inside elements compare
    ordered (json_diff used unordered equality — rare, accepted).
- Top level: two objects or two arrays recurse; anything else equal → no entry; unequal → one root `changed` entry
  (empty path, segments `[]`). json_diff's "equal scalars reported as changed" is not reproduced (defect fix).
- Paths: `json_path::build_canonical_path(&segments)`; segments are keys or decimal indices as strings. Index paths
  therefore come out as JSON Pointer (`/items/0/sku`), which the resolver accepts and which matches field paths of the
  topic analysis. *Alternative:* a new dot/`[n]` formatter in Rust — rejected (no second formatter; §5.27 plans a Dart
  `canonicalFieldPath` for tree copy, and ignore matching is token-based, so pasted dot/`[n]` paths still match).

### D5 Ignore semantics (spec *Ignored Field Paths*)
An entry is hidden when its `segments` start with the tokens of an ignore path (`FieldPath::tokens()`), i.e. exact
match or descendant, compared segment by segment (so `a.b` never hides `a.bc`). Notation-independent because
tokenisation already normalises `.`, `[n]`, `$.` and JSON Pointer. No wildcards (L7): a field inside every array
element (`items[*].updatedAt`) needs one entry per index or ignoring the whole array; this is the documented limit.
Ancestor entries (e.g. `meta` added as a whole while `meta.ts` is ignored) are not hidden and not rewritten —
filtering after the diff keeps the hidden count exact and the code simple.
- *Alternative:* strip ignored fields from both documents before diffing — rejected: needs a second pass for the
  count and silently changes added/removed subtree values.
- *Alternative:* `*` segment wildcard — rejected: contradicts L7/§7 ("keine Wildcards"); revisit only by amending L7.

### D6 Bridge
```rust
pub struct JsonDiffRequest { pub old: String, pub new: String, pub ignore_paths: Vec<String> }
pub enum JsonDiffKind { Added, Removed, Changed }
pub struct JsonDiffEntry { pub path: String, pub segments: Vec<String>, pub kind: JsonDiffKind,
                           pub old: Option<String>, pub new: Option<String> }
pub struct JsonDiffResult { pub is_json: bool, pub old_is_json: bool, pub new_is_json: bool,
                            pub entries: Vec<JsonDiffEntry>, pub hidden_count: u32, pub total_count: u32,
                            pub truncated: bool }
pub fn diff_json_batch(requests: Vec<JsonDiffRequest>, max_entries: Option<u32>) -> Vec<JsonDiffResult>;
```
Result `i` belongs to request `i`. Ignore paths are per request because one diff view can show several topics.
DTOs are not persisted, so no `serde(default)` needed; new file, no existing signature changes. A single diff is a
batch of one (no second function).

### D7 Dart orchestration
- `JsonDiffBatcher` (new, `widgets/diff/json_diff_batcher.dart`): `Future<JsonDiffResult> request(old, new, ignore)`
  queues a `Completer`; a `Timer(Duration.zero)` flush sends up to 50 requests per bridge call; a thrown call
  completes all its completers with the error. One app-wide instance via `getIt`.
- `MessageDiff.computeDiff(older, newer, {List<String> ignorePaths = const []})` keeps its name (used by §5.27): applies
  the `{}` substitution for null/empty payloads exactly as today, awaits the batcher, and only for non-JSON results
  computes the text diff (isolate threshold of 30 000 chars kept for that branch). Fields: `isJson`, `jsonDiff`
  (`JsonDiffResult?`), `textDiffToPrevious` (unchanged).
- `DiffTreeBuilder.fromEntries(entries)` replaces `JsonConverter.fromDiff`: groups entries by segment prefix, emits per
  level added → removed → changed → nested (first-appearance order), expands added/removed containers by decoding the
  value text with `jsonDecode` (same Dart objects as before, so `"${value}"` renders identically), root entry key `''`.
  `DiffViewNode` gains `path` (for "Ignore this field"). `JsonDiffWidget({required List<JsonDiffEntry> entries,
  ValueChanged<String>? onIgnorePath, int hiddenCount = 0})`; context menu only when `onIgnorePath != null`.
- `script_schemas_view.dart`: one batch call per field card (baseline vs. each occurrence) via `FutureBuilder`
  with a progress indicator and error text; Markdown export awaits the same call and prints `entry.path` (paths of
  array elements change from `a.0.b` to `/a/0/b` — accepted, still valid L7).

### D8 Ignore list storage and UI
- `DiffIgnoreListService extends ChangeNotifier` (new, `lib/src/services/`), registered in `dependency_injection.dart`
  like `SavedSearchesService`. Key `diff_ignore_paths_<topic>` as string list — per topic like the projected-column
  preset (`topic_columns_preset_<topic>`): volatile fields are a property of the payload schema, which is the same
  for a topic name across environments. A stored value of the wrong type is reported (`load` returns an error state),
  not overwritten until the user saves explicitly. Settings export/import already copies all preference keys.
- `MessagesDiffView`: listens to the service; a header row above the timeline ("Ignored fields" + count per topic,
  opens the dialog; topic dropdown when the list holds several topics); per card "hidden (n)" under the tree (opens the
  dialog for that topic) and the truncation notice; changing a topic's list drops cached diffs of that topic only.
  GUI cap: `max_entries = 2000` per card.
- `DiffIgnoreListDialog` (new): current paths with remove buttons (tooltip + semantic label), text field + add (trimmed,
  non-empty, no duplicates), suggestions as `ActionChip`s.
- Suggestions: from `changed` entries of the cached results of that topic, last non-index segment matching (case
  insensitive) `^(id|uuid|guid)$`, `(timestamp|time|date|ts)$`, `(created|updated|modified|sent|received|processed)
  (at|on)$`, `(trace|span|correlation|request|message|event)_?id$`; at most 20, never auto-added.

## Risks / Trade-offs

- [Rendering drift in the tree rebuild] → fixture chain: (1) capture `JsonConverter.fromDiff(JsonDiffer(...))` output
  for a fixture set into `test/fixtures/json_diff/cases.json` **before** removing `json_diff`; (2) a Rust test asserts
  `diff_json` on the same inputs yields the listed entries; (3) a Dart test asserts `DiffTreeBuilder` on those entries
  yields the captured tree; deviations (reorder, equal top-level scalars, nested unordered lists) are marked per case.
- [Large added subtrees make big value strings] → GUI decodes lazily per rendered node; the MCP follow-up must cap
  value text (noted for §5.17).
- [Batching delays a single diff by one event-loop turn] → negligible next to the existing 250 ms mount delay.
- [Positional pairing after scattered inserts is noisy] → documented limit; LCS can replace the middle-window pairing
  later without changing the entry model.
- [Recursion limit 128 hides structure of extremely deep payloads] → falls back to text view, not an error.
- [§5.27 lands first and uses the old types] → its dialog is migrated in this change (task 6.4).
- Kafka edge cases (ACLs, unreachable broker, compacted/transactional topics, empty topics) do not apply: the change
  only compares payloads already loaded; an empty list shows the existing "No messages to display".

## Migration Plan

Additive Rust API; Dart call sites changed in one go; `json_diff` removed last after the fixture capture. Rollback =
revert the change (no persisted format besides the new preference keys, which older versions ignore).

## Open Questions

- Whether users need per-element ignore across arrays often enough to amend L7 with a segment wildcard (deferred;
  needs a roadmap decision, not part of this change).
