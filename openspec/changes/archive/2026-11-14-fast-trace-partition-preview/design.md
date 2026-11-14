# Design

## Context

Observed in code (see proposal.md - Why for motivation):

- **Scan side.** `consume_with_filter` (`rust/src/api/kafka_consumer.rs`) forwards `fast_trace_key: Option<String>` to
  `kafkalyzer-kafka`. `resolve_target_partitions` (`kafka_consumer.rs:1017`) computes
  `to_positive(murmur2(key.as_bytes())) % partitions().len()` from the broker metadata fetched at scan start and
  assigns only that partition; with 0 partitions it falls back to all partitions. It also `println!`s the key — that
  line is already owned by `app-diagnostics-and-error-reporting` (task 2.2: log without the key).
- **Hash.** `murmur2`/`to_positive` live in `rust/kafkalyzer-kafka/src/kafka_utils.rs` (pure computation in the I/O
  crate) and are wrapped as bridge functions in `rust/src/api/kafka_utils.rs` (Dart: `murmur2(data:)`,
  `toPositive(number:)`, only referenced by a bridge smoke test). The implementation matches Kafka's
  `Utils.murmur2` (seed `0x9747b28c`, fall-through tail) by inspection; there is **no Rust test** for it.
- **Key derivation.** Explorer: `topic_detail_view.dart` splits the quick-filter text on `,`, trims, drops empties;
  `MessageStreamController` passes `filterTerms.firstOrNull` as the key. Scripts/multi-search:
  `target.filterTerm ?? target.filterTerms.firstOrNull` after template resolution at run time.
- **Partition count.** `TopicMetadata.partitionCount` (`i32`) from the loaded topic list. Unknown topics from
  "recently used" and script targets get a placeholder `partitionCount: 0` (`explorer_view.dart:678,712`,
  `script_runner.dart:789,804`; roadmap B7 → 5.33).
- **UI.** Fast Trace switch lives in `TopicSearchBar` (Explorer; label hardcoded `"Fast Trace (Hash Key)"`, chip
  `chipFastTrace` when collapsed) and in `SearchStreamConfiguration` (used only by `ScriptStepEditor`). The bar
  already runs a debounced async bridge call (`validateFilterPatterns`) on key edits — the preview reuses that pattern.
- **Spec note.** `search-configuration-panel` describes a collapsible panel with a localized title, but
  `searchConfigurationTitle` is not referenced anywhere in `lib/`; the current Explorer UI is the compact
  `TopicSearchBar` with an "Advanced" toggle. Not fixed here; the new requirements attach to the capability as the
  roadmap prescribes and are phrased against "the topic search configuration".

## Goals / Non-Goals

**Goals:** one partition formula used by scan and preview; preview with zero cluster I/O; honest unknown/empty
states.

**Non-Goals:** sync bridge calls (the project has none; not introduced for this); caching hashes; any change to
which partitions Fast Trace scans.

## Decisions

1. **Formula in `kafkalyzer-core`, not Dart.** New module `kafkalyzer_core::partitioner` with `murmur2`,
   `to_positive` (moved verbatim) and `default_partition(key: &[u8], partition_count: i32) -> Option<i32>` (`None`
   for `partition_count <= 0`). `kafkalyzer-kafka::kafka_utils` re-exports `murmur2`/`to_positive` so existing
   callers and the bridge wrappers compile unchanged; `resolve_target_partitions` calls `default_partition`.
   *Why:* two callers (scan, preview) plus the planned MCP `kafka_*` search (E10) need the identical result; pure
   computation belongs in core (L2). *Alternative:* Dart composes `murmur2(utf8.encode(key))` → `toPositive` →
   `% n` from the existing bridge functions (roadmap's "Dart only"). Rejected: duplicates the modulo, the byte
   encoding and the 0-partition rule in a second language — exactly the drift this preview must rule out — and needs
   two bridge round trips per keystroke. Deviation from roadmap §5.6 "Schichten: nur Dart" is deliberate and small.
2. **One additive bridge function.** `predict_default_partition(key: String, partition_count: i32) -> Option<i32>`
   in `rust/src/api/kafka_utils.rs`, encoding the key as UTF-8 (`key.as_bytes()`, same as the scan). Async like every
   other bridge function. Existing `murmur2`/`to_positive` bridge signatures stay.
3. **One Dart key helper.** A top-level function in `lib/src/features/search/domain/` (e.g.
   `splitFilterTerms(String)`) holds the split/trim/drop-empty rule; `topic_detail_view.dart` and the preview both
   use it, so "first term" means the same thing for both. Multi-search/script derivation is untouched.
4. **Preview state in `TopicSearchBar`.** New optional parameter `int? partitionCount` (passed as
   `widget.topic.partitionCount` from `topic_detail_view.dart`). On Fast Trace toggle, key edit (debounced like
   pattern validation, 300 ms) and `didUpdateWidget`, the bar calls the bridge; it keeps a request counter and drops
   stale answers. States: *no key* → hint; `partitionCount == null || <= 0` → "partition count unknown" (no bridge
   call); otherwise "Partition P of N" plus a "first term only" note when more than one term exists. A bridge error
   shows "unknown" (never a number) and is logged without the key. The assumption/caveat text is a visible one-line
   assumption plus the full caveat in a tooltip with a semantic label (info icon). Chip label becomes e.g.
   "Fast Trace → P3". The hardcoded switch label is replaced by the existing `l10n.fastTrace` while touching it.
5. **Script step editor: disclosure only.** The key is a template (`${var}`) resolved per run and a step can target
   several topics whose partition counts the editor does not load; a number there would be guesswork. It only gets
   the caveat tooltip on its Fast Trace switch.

## Risks / Trade-offs

- [Loaded metadata is stale (partitions added since the topic list loaded)] → preview shows the count it used
  ("of N"); the scan uses fresh metadata, so a mismatch is visible. Caveat names partition increases.
- [Producer used another partitioner / serialized key] → cannot be detected; disclosed in the caveat. Fast Trace
  remains opt-in.
- [Moving `murmur2` breaks an import] → re-export from `kafka_utils`; `cargo test --workspace` + clippy catch it.
- [`murmur2` currently wrong vs. Java] → new core tests pin Kafka's reference vectors (`UtilsTest.testMurmur2`); a
  failure there is a real scan bug and is fixed in core, which fixes scan and preview together.
- [Merge conflict with `app-diagnostics-and-error-reporting` in `resolve_target_partitions`] → keep its keyless log
  line; only the hash call changes here.

Edge cases: empty topic or compacted/transactional topics do not affect the computation (no offsets involved);
missing ACLs or an unreachable broker do not affect the preview (no I/O) — the scan reports them as before.

## Migration Plan

Additive; no stored data changes (`fastTraceEnabled` in presets/scripts unchanged). Rollback = revert the change; the
bridge function is new and unused elsewhere.
