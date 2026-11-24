# Design

## Context

See `proposal.md` — Why. The constraints that shape the approach:

- The consumption path is three layers deep: bridge entry point → `kafkalyzer-kafka::consume_with_filter` → `run_poll_loop` → `process_and_send_message`. All four carry the same 12–18 criteria, so a struct introduced at the boundary removes most of the inner `too_many_arguments` findings by itself.
- The bridge crate owns every type that crosses to Dart (orphan rule in `openspec/config.yaml`), so the request type cannot be shared with `kafkalyzer-kafka`.
- The criteria are not all plain data. By the time the poll loop runs, a string filter expression has become `kafkalyzer_core::filter_expr::CompiledExpr` and local schemas have become `LoadedTopicLocalSchemas`. A single DTO for all layers would force the compiled form over the FFI boundary.
- `StreamSink<KafkaMessage>` is a flutter_rust_bridge type and is not serde-serialisable, so it stays outside any request struct.
- Regenerating bindings is mandatory whenever `rust/src/api/` changes (`flutter_rust_bridge_codegen generate`, then `dart run build_runner build` for the checked-in mocks). The generated diff is large and must not hide the hand-written diff.
- Local blocker measured on 2026-11-21: `cargo clippy --workspace --all-targets` and `cargo test --workspace` abort in `sasl2-sys` when the SASL development package is absent. Linux selects `rdkafka` with `ssl`, `sasl`, `gssapi` (`rust/kafkalyzer-kafka/Cargo.toml`, Linux target section), so the native set is `libssl-dev`, `libsasl2-dev`, `libz-dev` plus pkg-config. CI installs exactly that set (`.github/workflows/build.yml:46`); `scripts/build_linux.sh` checks only `gtk+-3.0` and `libsecret-1`, and `README.md` §Prerequisites lists no native packages at all.

## Goals / Non-Goals

**Goals:**

- Zero clippy findings for `cargo clippy --workspace --all-targets`, so `enable-rust-lint-gate` becomes a one-line change.
- Every consumption criterion reachable by name at the boundary and inside the poll loop.
- Zero extra allocation or copy per message: the criteria structs are constructed once per run and borrowed per message.
- Generated and hand-written diffs separable, so the review can read the hand-written change.

**Non-Goals:**

- No new lint infrastructure, no `#[allow]` sweep, no baseline file (see `proposal.md` Non-Goals).
- No change to what the criteria mean, to EOF handling, or to the read-only surface.
- No Dart-side model for the request beyond the generated bridge class.

## Decisions

### D1 — One request struct at the bridge, `sink` stays a separate parameter

`rust/src/api/kafka_consumer.rs` gets `ConsumeRequest` (serde `Serialize`/`Deserialize`, `Debug`, `Clone`), holding the 18 criteria that `consume_with_filter` takes today. The bridge function becomes `consume_with_filter(request: ConsumeRequest, sink: StreamSink<KafkaMessage>)`.

Rejected alternatives:

- `#[allow(clippy::too_many_arguments)]` at the six sites. Smallest diff, but it leaves the silent-swap hazard that the `topic-consumption` delta now forbids, and the existing capability only accepts suppressions that carry a stated reason for an unfixable finding.
- A builder pattern. Requires a hand-written Dart-side counterpart and fights flutter_rust_bridge's plain-struct mapping.
- Keeping `sink` inside the struct. Not possible: `StreamSink` is not serde-serialisable and frb maps it as a dedicated parameter.

`ConsumeRequest` is a transient call argument, not a persisted DTO, so `#[serde(rename_all = "camelCase", default)]` is not required by the stored-compatibility rule. It is still applied, because `default` makes an omitted optional criterion explicit in the generated Dart class and costs nothing.

### D2 — Two domain structs in `kafkalyzer-kafka`, not one shared mega-struct

Inside `kafkalyzer-kafka`:

- `ConsumeCriteria` — filter terms, filter field, filter type, search scope, `Option<CompiledExpr>`, `Option<HashMap<String, Vec<String>>>` variables, local schema assignments, max results, run-forever.
- `ScanBounds` — start offset, start timestamp, start partition, fast-trace key, end offset, end timestamp, tail flag, per-run timeout.

`BaseConsumer`, `StreamSink`, the tokio runtime, the decoder set and the loaded local schemas stay explicit parameters, because they are resources with different lifetimes, not criteria.

Rejected alternative: one struct shared with the bridge crate. Blocked by the orphan rule (the bridge owns its types) and by the compiled form (`CompiledExpr`, `LoadedTopicLocalSchemas`) that only exists after the boundary.

Expected effect on the six `too_many_arguments` findings: `consume_with_filter` (bridge) 19 → 2, `consume_with_filter` (kafka) 19 → 4, `run_poll_loop` 18 → 8 or fewer, `process_and_send_message` 14 → 7 or fewer, `calculate_end_offsets` 11 → 6, `resolve_start_offsets` 9 → 5. If `run_poll_loop` still exceeds seven parameters after the structs land, the remaining ones are grouped per D6 rather than suppressed.

### D3 — Layer assignment

| Work | Layer | Justification |
|---|---|---|
| `ConsumeRequest` DTO and mapping to domain types | bridge crate | Only the bridge may define FFI types; mapping stays at the boundary |
| `ConsumeCriteria` / `ScanBounds`, `type_complexity` aliases, mechanical fixes in `kafka_consumer.rs`, `kafka_analyzer.rs`, `kafka_metadata.rs`, `kafka_utils.rs`, `schema_registry.rs` | `kafkalyzer-kafka` | These group I/O arguments; no pure computation is introduced |
| lint fixes in `duplicate_fingerprint.rs`, `filter_expr.rs`, `size_stats.rs`, `tests/spike_s2_descriptor_set.rs` | `kafkalyzer-core` | Test-side and one iterator fix; nothing new is computed, so nothing moves into core |
| call-site updates in two controllers and one table widget, regenerated bindings, regenerated mocks | Dart | Presentation keeps its shape; the generated class is the request model |
| prerequisite list in `README.md` §Prerequisites, prerequisite check in `scripts/build_linux.sh` | tooling/docs | Makes the Rust verdict reachable locally |

### D4 — `to_domain(&self)` takes `self` for the three `Copy` types

`FilterType`, `SearchScope` and `DuplicateDetectionScope` are `Copy`, so `to_domain(&self)` becomes `to_domain(self)`. Call sites are unchanged and the other 22 `to_domain(&self)` methods on non-`Copy` types stay as they are.

Rejected alternative from the backlog: rename to `as_domain`. That renames one method out of 25 identical converters, changes no behaviour, and makes the boundary mapping less uniform. Clippy's own suggestion is the by-value signature.

### D5 — Mechanical fixes: `cargo clippy --fix` first, hand fixes second

Machine-applicable group (`--fix`): `field_reassign_with_default` ×4, `bool_assert_comparison` ×3, `needless_lifetimes` ×2, `useless_conversion` ×2, `unnecessary_cast`, `needless_borrow`, `needless_borrows_for_generic_args`. Hand-applied because the fix changes control flow or introduces a named type: `type_complexity` ×3, `single_match`, `redundant_guards`, `manual_flatten`, `redundant_iter_cloned`, `wrong_self_convention` ×3.

`cargo clippy --fix` runs per crate with `--lib` and `--tests` separately, and each run is committed separately so a wrong autofix is revertible on its own.

### D6 — No new suppressions; a leftover finding is suppressed only with a reason

The one existing `#[allow(clippy::too_many_arguments)]` on `record_message_with_filter` stays. If a signature still exceeds the limit after grouping, the remaining parameters are folded into a struct rather than suppressed. A suppression is added only where a real fix would change behaviour, and then at item level with a one-line reason comment naming the reason, which is the shape the `static-analysis-gates` capability already accepts.

### D7 — Local prerequisites documented, not auto-installed

`README.md` §Prerequisites gains the Linux native package line that CI uses, plus the override for a workstation where those libraries come from another prefix (`PKG_CONFIG_PATH`), which is how the current machine builds at all. `scripts/build_linux.sh` adds `libsasl2`, `openssl`, `zlib` to the pkg-config probe it already runs before the Rust step, so a missing package fails in one line with the install command instead of dying inside a C build script after the read-only gate.

Rejected alternative: install the packages from the script. Requires root and would silently mutate a contributor machine.

## Risks / Trade-offs

- [Struct moves add cost to the consumption hot path] → Criteria structs are built once per run before `spawn_blocking`, moved into `run_poll_loop`, and passed as `&ConsumeCriteria` / `&ScanBounds` to `process_and_send_message`. No `Clone` in the per-message path; the payload and decode path keep passing references.
- [The regenerated frb diff buries the hand-written diff] → Commit order: (1) hand-written Rust, (2) `flutter_rust_bridge_codegen generate`, (3) `build_runner` mocks, (4) Dart call sites. Reviewer reads 1 and 4.
- [Autofix changes a test assertion into a weaker one] → `cargo clippy --fix` runs are separate commits, and the `bool_assert_comparison` changes are reviewed by hand immediately after the run.
- [Signature change breaks a caller that was missed] → The Dart call sites are three (`message_stream_controller.dart:91`, `topic_partition_table.dart:75`, `multi_search_controller.dart:183` as a factory default) plus `test/src/rust/api/kafka_consumer_test.dart`; `flutter analyze` catches any remaining mismatch, and the Rust compiler catches the rest.
- [Behaviour drift while moving criteria between layers] → The change adds no new criteria and removes none. `kafka_consumer_test.dart` is extended to assert that omitted optional criteria keep their defaults, which is the `topic-consumption` scenario for omitted criteria.
- [Local verdict differs from CI because of native libraries] → D7 documents and probes the CI package set, so a contributor can reach the same green verdict.
- [Stored saved searches or script steps no longer resolve] → Nothing in storage changes: the criteria keep the same names in the generated Dart class. The replay scenario in the `topic-consumption` delta is covered by an existing saved-search round-trip test plus one new test that a stored criterion set produces the same generated request.

## Migration Plan

1. `kafkalyzer-core` mechanical fixes (test-only) — independently green, no API change.
2. `kafkalyzer-kafka` structs, aliases and mechanical fixes; crate compiles and its own tests pass.
3. Bridge crate: `ConsumeRequest`, mapping, `to_domain(self)` ×3, `useless_conversion` removal. `cargo clippy --workspace --all-targets` must report zero findings at this point.
4. `flutter_rust_bridge_codegen generate` — separate commit.
5. `dart run build_runner build` for the checked-in mocks — separate commit.
6. Dart call sites (3 files) and `test/src/rust/api/kafka_consumer_test.dart`.
7. Prerequisite docs and `scripts/build_linux.sh` probe.
8. Full verification order from `openspec/config.yaml`, then `scripts/quality_gates.sh` and `scripts/check_read_only.sh`.

Rollback: revert the commit series. The generated files revert with the hand-written ones, so no manual regeneration is needed to go back.

## Open Questions

- Whether `ScanBounds` should also carry the per-partition timeout or keep it as an explicit parameter. Either clears the findings; it does not change the specs, the approach, or the task list, so it is decided during implementation.
