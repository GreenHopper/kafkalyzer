# Proposal

Backlog entry: **Q-4** in `design/code-quality-refactoring-backlog.md` §2. Change id fixed by §8 of that document: `rust-ffi-parameter-objects`.

## Why

`cargo clippy --workspace --all-targets` reports **30 findings** at the current HEAD (measured 2026-11-21: 9 in `kafkalyzer-core`, 16 in `kafkalyzer-kafka`, 5 in the bridge crate). Because that number is not zero, the clippy line stays commented out in `scripts/quality_gates.sh:166-170`, so the Rust half of the `ci-quality-gates` gate is still switched off and every new warning is invisible.

Six of the findings are `too_many_arguments` on functions with 9–19 positional parameters. The widest one is the app's hottest path: the message-consumption entry point takes 19 positional arguments, 12 of which are same-typed `Option<...>` values. Every new filter or scan criterion has to be threaded positionally through the bridge crate, `kafkalyzer-kafka` and the generated Dart bindings, and a swapped pair of same-typed arguments compiles cleanly while silently changing which criterion is applied — the failure mode the backlog calls out.

## What Changes

- Message consumption carries **one request object** instead of 19 positional arguments, from the bridge entry point down through the poll loop and per-message processing. The three Dart call sites move to the generated named constructor. **BREAKING** for the internal Rust↔Dart bridge signature only: `lib/src/rust/**` and the checked-in bridge mocks are regenerated in the same change, no stored JSON format changes, and no user-visible behaviour changes.
- The consumption criteria, the start bounds and the end bounds become named parameter structs inside `kafkalyzer-kafka`, clearing the five remaining `too_many_arguments` findings (`run_poll_loop` 18 args, `process_and_send_message` 14, `calculate_end_offsets` 11, `resolve_start_offsets` 9, `consume_with_filter` 19).
- Three `to_domain(&self)` methods on `Copy` types take `self` by value, which clears `wrong_self_convention` without renaming anything and keeps every call site unchanged (deviation from the backlog's `as_domain` rename suggestion; reason in design.md D4).
- 21 mechanical lint findings are cleared: 3 `type_complexity` (add type aliases), 4 `field_reassign_with_default`, 3 `bool_assert_comparison`, 2 `useless_conversion`, 2 `needless_lifetimes`, and one each of `redundant_iter_cloned`, `unnecessary_cast`, `single_match`, `redundant_guards`, `needless_borrow`, `needless_borrows_for_generic_args`, `manual_flatten`.
- The native build prerequisites that the Rust verification commands need on Linux are documented and covered by the local prerequisite check, so `cargo clippy --workspace` and `cargo test --workspace` reach a verdict on a contributor workstation instead of dying inside a C dependency build. Verified on 2026-11-21: without the SASL development package the whole workspace build aborts in `sasl2-sys`, and `scripts/build_linux.sh` does not check that package.
- No `#[allow]` is added beyond the one already present in `kafka_analyzer.rs`; no repository-wide exception list, baseline or severity downgrade.

## Capabilities

### New Capabilities

None. Both deltas extend capabilities that already exist.

### Modified Capabilities

- `topic-consumption`: one ADDED requirement — a consumption request states each criterion once, by name, and an unspecified criterion keeps its documented default, so criteria cannot be reordered or silently substituted and older saved searches resolve to the same criteria.
- `static-analysis-gates`: one ADDED requirement — the native build packages needed to run the Rust verification commands are documented and checked locally, so the lint and test verdict of the Rust workspace is reproducible on a workstation.

Parts of this change are a pure refactor with no spec-level behaviour (the 21 mechanical lint fixes, the generated-binding refresh). They are listed here for completeness and carry no requirement.

## Impact

- **Bridge crate `rust_lib_kafkalyzer`** (`rust/src/api/kafka_consumer.rs`, `rust/src/api/kafka_types.rs`): new request struct, `consume_with_filter(request, sink)` signature, three `to_domain` signatures, one `useless_conversion` removal.
- **Generated code, regenerated not edited:** `lib/src/rust/api/kafka_consumer.dart`, `lib/src/rust/api/kafka_types.dart`, `lib/src/rust/frb_generated.dart`, `rust/src/frb_generated.rs`, and the checked-in mocks `test/src/rust/api/rust_mocks.mocks.dart` via `dart run build_runner build`.
- **`kafkalyzer-kafka`:** `kafka_consumer.rs` (structs, 3 aliases, 2 mechanical), `kafka_analyzer.rs`, `kafka_metadata.rs`, `kafka_utils.rs`, `schema_registry.rs`.
- **`kafkalyzer-core`:** test code only (`filter_expr.rs`, `size_stats.rs`, `tests/spike_s2_descriptor_set.rs`) plus `duplicate_fingerprint.rs:332`.
- **Dart call sites:** `lib/src/features/topic/presentation/controllers/message_stream_controller.dart:91`, `lib/src/features/consumer/presentation/topic_partition_table.dart:75`, `lib/src/features/search/presentation/controllers/multi_search_controller.dart:183` (stream factory default), and `test/src/rust/api/kafka_consumer_test.dart:143,167`.
- **Scripts and docs:** `scripts/build_linux.sh` prerequisite check, and the documented verification order in `openspec/config.yaml` (its note about clippy joining with `-D warnings` stays valid — that still happens in `enable-rust-lint-gate`).
- **Read-only impact:** no new Kafka or Schema Registry calls. The same describe-only admin calls, the same manually assigned read-only consumer; `scripts/check_read_only.sh` must pass with no new exception.
- **Risk:** this touches the consumption hot path. The structs are moved or borrowed, never cloned per message, and the poll loop keeps its current single-threaded shape.

## Non-Goals

- Not enabling clippy in `scripts/quality_gates.sh` or CI. That stays the follow-up change `enable-rust-lint-gate` (one uncommented line), as fixed by `ci-quality-gates` design D2 and `openspec/config.yaml`.
- No generated-binding drift guard — that is Q-9 `verify-generated-bindings`.
- No new filter, offset or scan behaviour; no change to filter semantics, EOF handling or result-limit distribution.
- No new dependencies (`derive_builder`, `scopeguard` and similar are explicitly not introduced), no new crates, no crate renames.
- No Dart-side request-model redesign: the generated bridge struct is the request model.

## Prerequisites

None. `ci-quality-gates` (Q-1) is already merged; `enable-rust-lint-gate` is the successor of this change, not a prerequisite for it.
