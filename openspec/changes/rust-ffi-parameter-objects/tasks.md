# Tasks

Measured baseline for this change: `cargo clippy --workspace --all-targets` at the branch start reports **30 findings** (9 `kafkalyzer-core`, 16 `kafkalyzer-kafka`, 5 `rust_lib_kafkalyzer`). Every group below names the findings it clears, so the group is done when those specific locations are gone.

Local prerequisite for every Rust command in this change: on a Linux workstation the workspace needs the native packages from task 6.1. Without them `cargo clippy --workspace` and `cargo test --workspace` abort in `sasl2-sys`. Until 6.1 lands, run the Rust commands with `PKG_CONFIG_PATH` pointed at the prefix that provides `libsasl2.pc` (verified working on 2026-11-21).

## 1. kafkalyzer-core lint fixes

- [x] 1.1 Run `cargo clippy -p kafkalyzer-core --all-targets` and record the 9 findings as the group work list; verify the list matches `duplicate_fingerprint.rs:325-351`, `filter_expr.rs:1908,1958,1982,1996`, `size_stats.rs:220`, `tests/spike_s2_descriptor_set.rs:91,108,119`
- [x] 1.2 Fix `redundant_iter_cloned` at `kafkalyzer-core/src/duplicate_fingerprint.rs:332` by hand and verify `cargo test -p kafkalyzer-core` passes with the same test count as before — clippy's own suggestion (`.iter()` without `.cloned()`) does not compile, because the spawned threads need owned batches; fixed by copying `batches` once outside the measured region and consuming it with `into_iter()`
- [x] 1.3 Apply `cargo clippy --fix --lib -p kafkalyzer-core --tests` for the four `field_reassign_with_default` findings in `filter_expr.rs` tests and the `unnecessary_cast` in `size_stats.rs` tests, review the diff, and verify `cargo test -p kafkalyzer-core` passes (expect 167 core tests) — the autofix was rolled back by cargo because its rewrite breaks the borrow rules in these tests (E0505/E0597); all five findings applied by hand as struct literals instead
- [x] 1.4 Fix the three findings in `kafkalyzer-core/tests/spike_s2_descriptor_set.rs` (`needless_lifetimes` at lines 91 and 119, `useless_conversion` at line 108) and verify `cargo clippy -p kafkalyzer-core --all-targets` reports zero warnings
- [x] 1.5 Commit group 1 alone and verify `cargo fmt --all --manifest-path rust/Cargo.toml --check` is clean

## 2. kafkalyzer-kafka parameter structs and lint fixes

- [ ] 2.1 Add the `ConsumeCriteria` struct (filter terms, filter field, filter type, search scope, `Option<CompiledExpr>`, filter variables, local schema assignments, max results, run-forever) in `rust/kafkalyzer-kafka/src/kafka_consumer.rs` and verify the crate compiles with `cargo check -p kafkalyzer-kafka`
- [ ] 2.2 Add the `ScanBounds` struct (start offset, start timestamp, start partition, fast-trace key, end offset, end timestamp, tail flag) and verify `cargo check -p kafkalyzer-kafka` compiles
- [ ] 2.3 Convert `consume_with_filter` (line 113, 19 args) to take `ConsumeCriteria` + `ScanBounds` plus the existing consumer and sink parameters, and verify `cargo clippy -p kafkalyzer-kafka --lib` no longer reports `too_many_arguments` at line 113
- [ ] 2.4 Convert `run_poll_loop` (line 607, 18 args) to the two structs and verify its `too_many_arguments` finding is gone; if the signature still exceeds seven parameters, group the remaining decode-context arguments (`decoder`, `key_is_avro`, `value_is_avro`, `loaded_local`) into one struct instead of suppressing
- [ ] 2.5 Convert `process_and_send_message` (line 1053, 14 args) to borrow `&ConsumeCriteria` and `&ScanBounds` and verify its finding is gone, and verify no `Clone` was introduced on the per-message path by inspecting the diff
- [ ] 2.6 Convert `resolve_start_offsets` (line 1298, 9 args) and `calculate_end_offsets` (line 1402, 11 args) to the structs, keeping the consumer, metadata, watermarks, sink and timeout explicit, and verify both findings are gone
- [ ] 2.7 Add type aliases for the three `type_complexity` findings — partition watermark map (`kafka_consumer.rs:964`, `kafka_analyzer.rs:1665` region) and the topic-config result shape (`kafka_metadata.rs:748`) — and verify the three findings are gone
- [ ] 2.8 Apply `cargo clippy --fix --lib -p kafkalyzer-kafka` and `--tests` for `needless_borrow` (`kafka_consumer.rs:749`), `needless_borrows_for_generic_args` (`kafka_utils.rs:89`) and the three `bool_assert_comparison` findings in `kafka_analyzer.rs:2205,2565,2579`, review the assertion changes by hand, and verify `cargo test -p kafkalyzer-kafka` passes with the previous test count (105 passing, 7 ignored)
- [ ] 2.9 Fix `redundant_guards` (`kafka_analyzer.rs:218`), `single_match` (`kafka_metadata.rs:594`) and `manual_flatten` (`schema_registry.rs:1020`) by hand and verify `cargo clippy -p kafkalyzer-kafka --all-targets` reports zero warnings
- [ ] 2.10 Extend the existing consumer tests in `rust/kafkalyzer-kafka/src/kafka_consumer.rs` so one test builds a `ConsumeCriteria`/`ScanBounds` with every optional criterion unset and asserts the same defaults the 19-argument version applied (tail off, no structured filter, no result limit); verify the new test passes and no existing test was weakened

## 3. Bridge crate: request object and remaining lint fixes

- [ ] 3.1 Add `ConsumeRequest` in `rust/src/api/kafka_consumer.rs` with the 18 criteria, `#[derive(Debug, Clone, Serialize, Deserialize)]` and `#[serde(rename_all = "camelCase", default)]`, and verify `cargo check -p rust_lib_kafkalyzer` compiles
- [ ] 3.2 Change the bridge entry point to `consume_with_filter(request: ConsumeRequest, sink: StreamSink<KafkaMessage>)` and map it to the domain `ConsumeCriteria`/`ScanBounds` at the boundary; verify `cargo clippy -p rust_lib_kafkalyzer --lib` no longer reports `too_many_arguments` at `src/api/kafka_consumer.rs:74`
- [ ] 3.3 Change `to_domain(&self)` to `to_domain(self)` for the three `Copy` types `FilterType`, `SearchScope`, `DuplicateDetectionScope` (`src/api/kafka_types.rs:102,119,396`) and verify the three `wrong_self_convention` findings are gone and the other 22 `to_domain` methods are untouched
- [ ] 3.4 Drop the `ConsumerGroupLag::from(group)` useless conversion at `src/api/kafka_types.rs:1193` and verify the finding is gone
- [ ] 3.5 Run `cargo clippy --workspace --all-targets` and verify it reports **zero** warnings, which is the precondition the `enable-rust-lint-gate` follow-up needs
- [ ] 3.6 Run `cargo test --workspace --manifest-path rust/Cargo.toml` and verify the workspace test counts match the pre-change baseline (core 167, kafka 105 plus 7 ignored, bridge 35) plus the new tests from 2.10

## 4. Regenerate bridge code and mocks

- [ ] 4.1 Run `flutter_rust_bridge_codegen generate` from the repository root and verify `lib/src/rust/api/kafka_consumer.dart` exposes `ConsumeRequest` and `consumeWithFilter(request: ..., sink: ...)`; commit this regeneration as its own commit
- [ ] 4.2 Run `dart run build_runner build` and verify `test/src/rust/api/rust_mocks.mocks.dart` regenerated with the new signature; commit as its own commit
- [ ] 4.3 Verify `flutter analyze` reports no finding caused by the regenerated files, and that no hand edit was made inside `lib/src/rust/**` or `rust/src/frb_generated.rs`

## 5. Dart call sites and Dart tests

- [ ] 5.1 Update `lib/src/features/topic/presentation/controllers/message_stream_controller.dart:91` to build a `ConsumeRequest` and verify that screen's existing tests still pass with unchanged filter behaviour
- [ ] 5.2 Update `lib/src/features/consumer/presentation/topic_partition_table.dart:75` and verify its tests pass
- [ ] 5.3 Update the `consumeWithFilter` default factory in `lib/src/features/search/presentation/controllers/multi_search_controller.dart:183` and verify the multi-search tests pass unchanged
- [ ] 5.4 Update `test/src/rust/api/kafka_consumer_test.dart:143,167` to the new signature and add one test asserting that a request built without the optional criteria produces the same defaults as before; verify `flutter test test/src/rust/api/kafka_consumer_test.dart` passes
- [ ] 5.5 Add one round-trip test for a stored saved search or script step: verify its stored criteria produce a `ConsumeRequest` with the same values the pre-change call produced for the same inputs, and that an unparseable stored criterion is reported rather than dropped
- [ ] 5.6 Run `dart format --output=none --set-exit-if-changed lib test` and `flutter analyze` and verify both are clean, with no new ignore comment added

## 6. Local prerequisites and project rules

- [ ] 6.1 Document the Linux native packages required by the Rust verification commands in `README.md` §Prerequisites — `libgtk-3-dev libsecret-1-dev libblkid-dev liblzma-dev pkg-config libssl-dev libsasl2-dev libz-dev`, the exact set `.github/workflows/build.yml:46` installs — and add one sentence on the `PKG_CONFIG_PATH` override for a prefix-based toolchain; verify the documented apt line is byte-identical to the CI line
- [ ] 6.2 Add `openssl`, `libsasl2` and `zlib` to the pkg-config prerequisite probe in `scripts/build_linux.sh` (next to the existing `gtk+-3.0` and `libsecret-1` check) and verify that with a package deliberately missing the script stops before the Rust step, naming the package and the apt line
- [ ] 6.3 Update `openspec/config.yaml`: add the native prerequisite to the numbered Verification list, and narrow the design rule that keeps Rust-Dart API signatures backward compatible so it covers persisted DTO data and stored formats, not internal bridge function signatures that `flutter_rust_bridge_codegen` regenerates; verify `openspec instructions design --change rust-ffi-parameter-objects --json` echoes the updated rule and `openspec validate rust-ffi-parameter-objects --strict` still passes
- [ ] 6.4 Update `design/code-quality-refactoring-backlog.md`: record the measured 30-finding split under Q-4 with a status line pointing at this change, and add `enable-rust-lint-gate` to the §8 change-id table, since it is currently referenced only from `openspec/config.yaml` and `scripts/quality_gates.sh`; verify the §8 table names one id per Tier 1/2 entry

## 7. Integration verification

- [ ] 7.1 Run the full verification order from `openspec/config.yaml` in one pass and verify each step exits 0: `cargo fmt --all --manifest-path rust/Cargo.toml --check`, `cargo clippy --workspace --all-targets`, `cargo test --workspace --manifest-path rust/Cargo.toml`, `flutter_rust_bridge_codegen generate`, `dart run build_runner build`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`
- [ ] 7.2 Run `bash scripts/quality_gates.sh` and verify it passes, including the 800-line size guard and the session-wide-state locator guard on the files this change touches
- [ ] 7.3 Run `./scripts/check_read_only.sh` and `bash scripts/test_check_read_only.sh` and verify SUCCESS with **no new exception** — this change adds no Kafka or Schema Registry call
- [ ] 7.4 Verify no suppression was introduced: `git diff` contains no new `#[allow(clippy::` outside the one already present in `kafka_analyzer.rs`, and no new `ignore_for_file` or analyzer severity change
- [ ] 7.5 Spot-check the consumption path against the local docker-compose broker (topic and group fixtures from `docker-compose.yaml`): verify a filtered search with tail start returns the same messages and progress reporting as the pre-change build, and that a partition whose read is denied is still reported as not readable

## Workflow follow-up

- Open the follow-up change `enable-rust-lint-gate` once this change is merged: uncomment the clippy line in `scripts/quality_gates.sh` and satisfy the "Deferred check is switched on once its baseline is clean" scenario in `static-analysis-gates`.
- Archive this change after review, then verify `openspec/specs/topic-consumption/spec.md` and `openspec/specs/static-analysis-gates/spec.md` carry the two added requirements.
