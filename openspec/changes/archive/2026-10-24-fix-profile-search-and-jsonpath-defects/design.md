# Design

## Context

Four independent defects share one root cause: the same behavior is implemented in several places, and no place is authoritative.

- Cluster profiles are persisted by a hand-written Dart extension, `ClusterProfileExtension.toJson` in `lib/src/services/cluster_service.dart`. It lists 11 of the 21 fields of `ClusterProfile`; the frb-generated class has no `toJson` of its own, so the extension always wins and the remaining 10 fields never reach `SharedPreferences`. Stored files use camelCase keys (`bootstrapServers`, `sslKeystoreLocation`) and contain only those 11 keys. The bridge struct `rust/src/api/kafka_types.rs::ClusterProfile` already derives `Serialize`/`Deserialize`, and every optional field is `Option<String>`.
- Field paths exist four times with three different grammars: `lib/src/utils/json_path_extractor.dart` (dot + `[n]`, strips only `root.`), `lib/src/features/scripting/domain/extraction_utils.dart` (dot only), the private `_extractValue` in `lib/src/features/scripting/presentation/controllers/script_runner.dart`, and `matches_filter` in `rust/kafkalyzer-kafka/src/kafka_consumer.rs:1417` (JSON Pointer, but it builds `format!("/{}", field)` so a dotted path becomes one literal key name). The localized hint `extractionJsonPath` advertises `$.id`, which no implementation resolves.
- Table projection caches extracted values per row (`messages_table_view.dart:346`) and message arrival is already throttled in 60 ms windows (`message_stream_controller.dart:201`), so extraction work happens on bounded batches, not per keystroke.
- Filter evaluation pre-compiles patterns at setup (`kafka_consumer.rs:638`) but falls back to `Regex::new(term)` per message and then to substring matching when compilation fails (`kafka_consumer.rs:1444`), and logs the full matched payload per hit (`kafka_consumer.rs:1455`). Dart `RegExp` and Rust `regex` are different engines, so client-side validation cannot be assumed equivalent to what the scan actually runs.
- Project constraints that shape the approach: read-only Kafka access (no producer, no commits), bridge-boundary type isolation (DTOs declared in `rust_lib_kafkalyzer`), pure computation in `kafkalyzer-core`, `material_ui` for widgets, no hard-coded UI strings, and no blocking work in the UI isolate.

Motivation and scope: see `proposal.md`. Behavior contracts: see the four spec deltas.

## Goals / Non-Goals

**Goals:**

- One authoritative field-path implementation, reachable from both the Dart UI and the Rust consumer, with a single test-vector suite that defines the grammar.
- One authoritative profile serialization for local persistence, such that adding a field to `ClusterProfile` cannot silently drop data again.
- Filter patterns validated by the engine that will evaluate them, with the failure surfaced in the UI instead of silently degrading a scan.
- No new per-message or per-cell cost: extraction and diagnostics stay inside the existing batch and throttle boundaries.

**Non-Goals:**

- No JSONPath feature growth beyond the accepted grammar (no wildcards, no recursive descent, no filter expressions).
- No extraction from message headers (`ScriptExtractionSource.HEADER` keeps today's behavior; the resolver is value/key only).
- No relocation of the JSON diff, no headless CLI/MCP surface, no Kafka write path.
- No profile storage format migration and no secret storage change (keyring work stays a separate proposal).

## Decisions

### D1. Field-path resolver lives in `kafkalyzer-core`, Dart calls it in batches

`rust/kafkalyzer-core/src/json_path.rs` exposes `resolve(payload: &str, path: &str) -> Option<String>` and `resolve_batch(payloads: Vec<String>, paths: Vec<String>) -> Vec<Option<String>>`, with the grammar implemented once: leading `/` is taken as JSON Pointer verbatim, otherwise an optional leading `$` is dropped and dot/`[n]` tokens are converted to a JSON Pointer (keys escaped per RFC 6901) and evaluated with `serde_json::Value::pointer`. Objects and arrays are returned as compact JSON text so today's Dart rendering (`jsonEncode` for `Map`/`List`) stays identical.

Bridge functions in `rust/src/api/` expose the same two entry points; per the project's orphan rule the bridge declares its own request/response types and maps to core types.

Table projection calls `resolve_batch` once per message batch (the same place that already appends new messages and invalidates the per-row cache), so the FFI call count is per batch rather than per cell. Script extraction calls it once per step result set. The Rust consumer calls the core function directly with no bridge involved.

Alternatives considered:

- **Per-cell bridge call from the table builder.** Rejected: it puts an FFI round trip inside the scroll path and defeats the existing per-row cache.
- **Keep a Dart implementation and enforce parity with a shared vector file.** Rejected: that is the current state, and the divergence is exactly what users hit.
- **Return a typed value instead of a string.** Rejected: more bridge types for no observable gain; every consumer renders text today.

### D2. Grammar is a union of what users already type, not a new language

Accepted: `a.b.c`, `a.0.b`, `a[0].b`, `$.a.b`, `/a/b/c`. Rejected alternatives: full JSONPath (`$..id`, `[?(@.x==1)]`) — a larger parser, and no existing feature needs it. `$.` support is required because the UI already advertises it (`app_en.arb:720`); existing saved column configs that used `$.x` start resolving instead of rendering empty, which is a user-visible improvement rather than a break.

### D3. Profile persistence is delegated to the bridge struct's serde

Add `#[serde(rename_all = "camelCase", default)]` to the bridge `ClusterProfile`, plus `serializeClusterProfile(profile) -> String` and `deserializeClusterProfile(json) -> ClusterProfile` in `rust/src/api/`. `ClusterService` stores that string and deletes the hand-written extension; `copyWith` callers keep working because the Dart class is unchanged.

`rename_all = "camelCase"` matches the keys already on disk, and `default` makes today's 11-key files deserialize with the remaining fields as `null`, so no migration step is needed. A field added to the struct in the future is persisted automatically — that is the recurrence prevention, which a completed hand-written `toJson` would not provide.

Alternatives considered: completing the Dart extension (fixes today, breaks again on the next field); a Dart-side `json_serializable` model duplicating the bridge struct (second model to keep in sync); storing the core (snake_case) struct (would orphan existing stored files).

### D4. Validation happens in Rust, surfaced in Dart

`validate_filter_patterns(terms: Vec<String>) -> Vec<String>` returns the terms the `regex` crate rejects. The search bar calls it on scan start and, debounced, when the pattern changes, and shows a localized inline error at the input plus an invalid-state marker on the collapsed filter chip. In the core, the fallback branches at `kafka_consumer.rs:1444` are removed: the pre-compiled set is the only source, and an uncompilable term cannot reach the loop because the scan is refused earlier.

Validating with Dart's `RegExp` was rejected: engine differences mean a pattern can pass the client and fail in the scan, reproducing the silent-degradation problem in a new place.

### D5. Match diagnostics become metadata-only

The per-match `log_to_dart` call at `kafka_consumer.rs:1455` is reduced to topic, partition, offset and the matched term. Payload content is already delivered as the message record itself and is visible in the table and inspector, so the echo adds cost without information. No new setting is introduced; a debug toggle would add configuration nobody requested.

### D6. Test strategy

Rust unit tests carry the grammar vectors (all accepted notations, missing path, non-JSON payload, keys containing `/` and `~`), profile serde round-trip over a captured 11-key sample, and filter pre-compilation with no fallback. Dart tests replace `json_path_extractor_test.dart` with bridge-backed equivalents and extend `cluster_service_test.dart` with a Kerberos plus PEM round trip. Existing widget tests (`messages_view_column_customization_test.dart`, `messages_table_view_customization_test.dart`) guard the projection UI.

## Risks / Trade-offs

- **FFI batching regressions in projection** (extraction called more often than the current Dart path) → keep the per-row cache and the 60 ms arrival throttle as the only call sites; assert call count in a Dart test over a 500-message batch.
- **Stored profiles in the old 11-key shape fail to parse** → `#[serde(default)]` plus a regression test that loads a captured legacy file; if parsing still fails, fall back to treating that profile as unusable and log once, never silently rewrite it.
- **frb regeneration churn** (`rust/src/frb_generated*.rs`, `lib/src/rust/api/**`) → regenerate in the same commit and let `flutter test` plus `cargo test` catch signature drift; no existing bridge signature changes, only additions.
- **Behavior change for existing saved paths** (`$.x` previously empty, now resolved) → intentional and matching the advertised hint; noted in the changelog entry.
- **`matches_filter` change alters match counts** for users who relied on an invalid regex behaving like substring search → the validation error states the offending term, and scan refusal is the safer default; no data is lost.

## Migration Plan

1. Land the core resolver, its tests, the bridge wrappers, and regenerate the bridge in one commit; the Dart callers switch in the same commit so no second parser survives.
2. Land the profile serde persistence; old stored files stay readable, nothing is rewritten until the user saves a profile again — at which point the full field set is written.
3. Rollback is a plain revert. Profiles saved by the new code keep all keys in the camelCase shape the old Dart reader also understands, because the key names are unchanged.

## Open Questions

- Whether extraction from message headers should use the same grammar (`ScriptExtractionSource.HEADER`) can be decided after this change; it does not alter the specs or the task breakdown.
- Exposing `resolve`/`resolve_batch` to a future CLI/MCP surface follows automatically once that surface exists; no interface decision is needed now.
