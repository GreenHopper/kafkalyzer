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

- [x] 2.1 Add the `ConsumeCriteria` struct (filter terms, filter field, filter type, search scope, compiled expression, filter variables, local schema assignments, fast-trace key, start partition, max results, run-forever) in `rust/kafkalyzer-kafka/src/kafka_consumer.rs` and verify the crate compiles with `cargo check -p kafkalyzer-kafka`
- [x] 2.2 Add the `ScanBounds` struct (start offset, start timestamp, end offset, end timestamp, tail flag), `Copy` and `Default`; the fast-trace key and start partition live in `ConsumeCriteria` because they select partitions rather than bound the window
- [x] 2.3 Convert `consume_with_filter` to take `ConsumeCriteria` + `ScanBounds` plus the profile, topic and sink; `too_many_arguments` is gone (19 args to 5)
- [x] 2.4 Convert `run_poll_loop` to `ResolvedPlan` + `ScanFilter` + `DecodeContext` (18 args to 6, no `#[allow]`); the decode-context grouping named in D6 was needed to get under seven
- [x] 2.5 Convert `process_and_send_message` to borrow `&ScanFilter` and `&DecodeContext` plus the compiled regexes (14 args to 6); the diff introduces no `Clone` on the per-message path
- [x] 2.6 Convert `resolve_start_offsets` (9 args to 6) and `calculate_end_offsets` (11 args to 6) to `ScanTarget` + `ScanBounds`, keeping consumer, metadata, timeout and sink explicit; `calculate_end_offsets` drops its unused `_run_forever`
- [x] 2.7 Add type aliases for the three `type_complexity` findings — `WorkerTask` in `kafka_analyzer.rs`, `DecodedParts` in `kafka_consumer.rs`, `ConfigChunk` in `kafka_metadata.rs` — all three findings gone
- [x] 2.8 Apply `cargo clippy --fix -p kafkalyzer-kafka --all-targets` for `needless_borrows_for_generic_args` and the three `bool_assert_comparison` findings, review the assertion changes by hand, and verify `cargo test -p kafkalyzer-kafka` passes with the previous test count (105 passing, 7 ignored)
- [x] 2.9 Fix `redundant_guards` (`kafka_analyzer.rs:218`, now `Some([])`), `single_match` (`kafka_metadata.rs:594`) and `manual_flatten` (`schema_registry.rs:1020`) by hand and verify `cargo clippy -p kafkalyzer-kafka --all-targets` reports zero warnings
- [x] 2.10 Extend the existing consumer tests so one test builds a `ConsumeCriteria`/`ScanBounds` with every optional criterion unset and asserts the defaults the 19-argument version applied (start at the high watermark, no structured filter, no result limit, empty range finishes at once); added a test for `check_requested_partition`, so a partition the topic does not have is an error instead of a silent zero-range scan — 107 passing, 7 ignored

## 3. Bridge crate: request object and remaining lint fixes

- [x] 3.1 Add `ConsumeRequest` in `rust/src/api/kafka_consumer.rs` carrying all 18 criteria with `#[derive(Debug, Clone, Serialize, Deserialize)]` and `#[serde(rename_all = "camelCase")]` — the struct-level `default` was dropped: `profile` and `topic` are required and have no `Default`, and the field names already arrive in camelCase
- [x] 3.2 Change the bridge entry point to `consume_with_filter(request: ConsumeRequest, sink: StreamSink<KafkaMessage>)` and map it to the domain structs in one `into_domain(self)` call (`to_domain` would re-trigger `wrong_self_convention` on a non-`Copy` request); `too_many_arguments` at `src/api/kafka_consumer.rs:74` is gone
- [x] 3.3 Change `to_domain(&self)` to `to_domain(self)` for `FilterType`, `SearchScope`, `DuplicateDetectionScope` (`src/api/kafka_types.rs:102,119,396`); the three `wrong_self_convention` findings are gone and the other 22 `to_domain` methods are untouched
- [x] 3.4 Fix the `useless_conversion` at `src/api/kafka_types.rs:1193`: the test built a **domain** `ConsumerGroupLag` and converted it to itself, so the assertion never exercised the bridge mapping; it now names the bridge type and the finding is gone
- [x] 3.5 Run `cargo clippy --workspace --all-targets` and verify it reports **zero** warnings — the precondition the `enable-rust-lint-gate` follow-up needs
- [x] 3.6 Run `cargo test --workspace --manifest-path rust/Cargo.toml`: core 167, kafka 107 plus 7 ignored (baseline 105 plus the two new tests), bridge 35

## 4. Regenerate bridge code and mocks

- [x] 4.1 `flutter_rust_bridge_codegen generate` — `lib/src/rust/api/kafka_consumer.dart` exposes `ConsumeRequest` and `consumeWithFilter({required ConsumeRequest request})`; committed as its own commit
- [x] 4.2 `dart run build_runner build` regenerated `test/src/rust/api/rust_mocks.mocks.dart` with `crateApiKafkaConsumerConsumeWithFilter({required ConsumeRequest? request})`; committed as its own commit. A `script.freezed.dart` regeneration unrelated to this change was reverted
- [x] 4.3 `flutter analyze` reports no finding from the regenerated files, and no hand edit was made inside `lib/src/rust/**` or `rust/src/frb_generated.rs`

## 5. Dart call sites and Dart tests

- [x] 5.1 `message_stream_controller.dart` builds a `ConsumeRequest` in `bridgeConsumeStream` (the former private static, now shared so the search controller can default to it); the app-side `MessageConsumeStreamFactory` keeps its named parameters, so injected fakes and screen tests did not move
- [x] 5.2 `topic_partition_table.dart:75` builds a `consumer.ConsumeRequest`; its tests pass
- [x] 5.3 the `multi_search_controller.dart` default factory now points at `bridgeConsumeStream`; the multi-search tests pass unchanged
- [x] 5.4 `test/src/rust/api/kafka_consumer_test.dart` uses the new signature and a new test asserts a request built without the optional criteria carries the same defaults the 19-argument call applied (all optionals null, `runForever` false)
- [x] 5.5 Round-trip test for a saved search stored in the previous format: its criteria arrive in one `ConsumeRequest` with the same values. An unreadable stored criterion is now reported instead of defaulted — `TopicSearchPreset.fromJson` raises `FormatException` for a name this version cannot resolve, which `SavedSearchesService` logs per preset and keeps verbatim
- [x] 5.6 `dart format --output=none --set-exit-if-changed lib test` and `flutter analyze` clean, with no new ignore comment

## 6. Local prerequisites and project rules

- [x] 6.1 `README.md` § Prerequisites now names the Linux native packages the Kafka crate links (`libssl-dev libsasl2-dev libz-dev` beside the GTK/secret-storage ones), the failure a developer sees without them (`Could not find libsasl2 ... via pkg-config` inside `rdkafka-sys`), and the `PKG_CONFIG_PATH` case where the package is installed but not found
- [x] 6.2 `scripts/build_linux.sh` probe extended to `openssl libsasl2 zlib` beside `gtk+-3.0 libsecret-1`; its error output also points at `PKG_CONFIG_PATH`. Measured: the system `pkg-config` with an empty `PKG_CONFIG_PATH` reports `libsasl2` missing, the Homebrew one resolves it — exactly the case the probe now catches
- [x] 6.3 `openspec/config.yaml` gained the two design rules: one request struct for a Dart→Rust criteria bundle mapped by one explicit method, and no positional argument piles in shared Rust paths (drop arguments rather than adding an `allow`)
- [x] 6.4 `design/code-quality-refactoring-backlog.md`: Q-4 carries a status block with the measured outcome, and section 8 lists `enable-rust-lint-gate` as the Q-4 follow-up with its unblocked state

## 7. Integration verification

- [ ] 7.1 Run the full verification order from `openspec/config.yaml` in one pass and verify each step exits 0: `cargo fmt --all --manifest-path rust/Cargo.toml --check`, `cargo clippy --workspace --all-targets`, `cargo test --workspace --manifest-path rust/Cargo.toml`, `flutter_rust_bridge_codegen generate`, `dart run build_runner build`, `dart format --output=none --set-exit-if-changed lib test`, `flutter analyze`, `flutter test`
- [ ] 7.2 Run `bash scripts/quality_gates.sh` and verify it passes, including the 800-line size guard and the session-wide-state locator guard on the files this change touches
- [ ] 7.3 Run `./scripts/check_read_only.sh` and `bash scripts/test_check_read_only.sh` and verify SUCCESS with **no new exception** — this change adds no Kafka or Schema Registry call
- [ ] 7.4 Verify no suppression was introduced: `git diff` contains no new `#[allow(clippy::` outside the one already present in `kafka_analyzer.rs`, and no new `ignore_for_file` or analyzer severity change
- [ ] 7.5 Spot-check the consumption path against the local docker-compose broker (topic and group fixtures from `docker-compose.yaml`): verify a filtered search with tail start returns the same messages and progress reporting as the pre-change build, and that a partition whose read is denied is still reported as not readable

## Workflow follow-up

- Open the follow-up change `enable-rust-lint-gate` once this change is merged: uncomment the clippy line in `scripts/quality_gates.sh` and satisfy the "Deferred check is switched on once its baseline is clean" scenario in `static-analysis-gates`.
- Archive this change after review, then verify `openspec/specs/topic-consumption/spec.md` and `openspec/specs/static-analysis-gates/spec.md` carry the two added requirements.
