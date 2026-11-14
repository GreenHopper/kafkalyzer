# Design: harden-read-only-gate

## Context

See `proposal.md` (Why) and the delta spec for the requirements. Current state that shapes the approach:

- `scripts/check_read_only.sh` builds one file list (`rust/**/*.rs` without `target/`, plus `lib/src/**/*.dart`) and
  runs a table of `NAME:::REGEX:::EXCLUDE` checks with `grep -nE`. The `EXCLUDE` regex drops matching output lines;
  today only `.send(` uses it, with the token `allow_read_only_exception`. If the target has neither `rust/` nor
  `lib/src/`, it falls back to all `*.rs`/`*.dart` files under the target. The script is called by the CI job
  `read-only-gate` (`.github/workflows/build.yml`) and by `scripts/build_linux.sh`.
- `scripts/test_check_read_only.sh` has 10 cases: full repo passes, clean temp tree passes, 7 rejected samples, 1
  accepted marked `.send(`. CI does **not** run it today.
- `AdminClient` appears only in `rust/kafkalyzer-kafka/src/kafka_metadata.rs` (lines 8, 71, 92) and
  `kafka_analyzer.rs` (lines 12, 1092, 1096). Both call only `describe_configs`.
- HTTP: `reqwest` is used in `kafkalyzer-kafka` (`schema_registry.rs`, `kafka_consumer.rs`). All requests are
  `.get(` except one `.post(` at `schema_registry.rs:301` (`/compatibility`). **Correction to the task brief:** the
  `// allow_read_only_exception` marker in that function sits on the `.send()` line (310), not on the `.post(` line
  (301). A line-based `.post(` check would flag line 301 until the marker is added there.
- Manifests: `rust/Cargo.toml` (bridge crate, `flutter_rust_bridge`), `rust/kafkalyzer-core/Cargo.toml` (none of the
  guarded crates), `rust/kafkalyzer-kafka/Cargo.toml` (`reqwest`, plus `rdkafka`/`rdkafka-sys` in three
  `[target.'cfg(...)'.dependencies]` sections). The vendored plugin `packages/velopack_flutter/rust/Cargo.toml` also
  declares `flutter_rust_bridge`.
- Baseline: `bash scripts/check_read_only.sh` → exit 0 (187 files, 5 checks passed); `bash
  scripts/test_check_read_only.sh` → exit 0 (10/10).

## Goals / Non-Goals

**Goals:**

- Extend the existing script in place; keep its CLI (`[TARGET_ROOT]`), output style and exit codes.
- Zero false positives on today's tree after the one-line marker comment.
- Portable regexes (POSIX ERE, works with GNU and BSD grep).

**Non-Goals:**

- No new tool (no Rust test, no clippy lint, no `cargo metadata`/`cargo deny`).
- No TLS patterns (owned by `restore-tls-verification`, §5.21, with unit tests).
- No Dart HTTP check: the Dart app has no HTTP client import today (`http` is declared in `pubspec.yaml` but imported
  nowhere under `lib/`, `test/`, `bin/`).

## Decisions

### D1: Stay grep-based and extend the check table

The new source checks become rows in the existing table. A fourth field `SCOPE` (`all` or `rs`) selects the file
list: `all` = current list, `rs` = only the `*.rs` subset. Existing rows get `all`.
Alternative: a Rust integration test or clippy `disallowed_methods`. Rejected: it needs a build, covers no Dart and
no manifests, and splits the gate into two mechanisms. A grep stays fast and runs before compilation in CI.

### D2: Patterns (POSIX ERE, no `\b`/`\s`)

| Check | Scope | Pattern | Exclude |
|---|---|---|---|
| Mutating admin calls | all | `(^\|[^A-Za-z0-9_])(create_topics\|delete_topics\|create_partitions\|alter_configs\|incremental_alter_configs\|delete_records\|delete_groups)[[:space:]]*\(` | none |
| Offset store | all | `(^\|[^A-Za-z0-9_])store_offset(s\|_from_message)?[[:space:]]*\(` | none |
| HTTP PUT/DELETE/PATCH | rs | `\.(put\|delete\|patch)[[:space:]]*\(\|Method::(PUT\|DELETE\|PATCH)` | none |
| HTTP POST | rs | `\.post[[:space:]]*\(\|Method::POST` | `allow_read_only_exception:[[:space:]]*[^[:space:]]` |

(`\|` in the table is markdown escaping; the script uses plain `|`.)

- The leading `(^|[^A-Za-z0-9_])` replaces `\b`, so `my_delete_topics_view(` or `restore_offsets(` do not match.
- Matching the call `name(` rather than the bare name keeps imports and prose like `AdminClient` neutral while
  catching method calls and UFCS calls.
- `store_offset_from_message` is added beyond the roadmap list: it is the rdkafka convenience form of the same
  operation.
- Admin and offset-store rows have no exclude, so a marker cannot bypass them (spec scenario).
- A Rust-only row covers mutating librdkafka C functions (`rd_kafka_commit`, `rd_kafka_offsets_store`,
  `rd_kafka_AlterConsumerGroupOffsets`, `rd_kafka_CreateTopics`, ...). `fix-consumer-lag-accuracy` may bind
  `rd_kafka_ListConsumerGroupOffsets` via FFI (its spike candidate A); this row keeps such a binding from growing
  write calls. List/Describe functions stay allowed. 0 hits on today's code.

### D3: HTTP checks only on Rust files

Dart sources contain unrelated `.delete(` calls (see results below), and every HTTP client of the app lives in Rust.
Scoping to all `*.rs` files is chosen over "only files that mention `reqwest`": a helper can receive a client without
naming the crate, and Rust std collections have no `put`/`delete`/`patch`/`post` methods, so the wider scope has no
false positives today. If one appears later, it gets the reasoned marker.

### D4: Reasoned exception marker for POST

Reuse the existing token, but require a reason: `// allow_read_only_exception: <reason>` on the same line as `.post(`.
Alternative: a new token such as `allow_http_post`. Rejected: one marker vocabulary is easier to audit (`grep
allow_read_only_exception`). The existing `.send(` row keeps its bare-token exclude; all current `.send(` markers
already carry a reason, but tightening that row is out of scope.
Implementation edit (comment only): line 301 becomes
`.post(endpoint) // allow_read_only_exception: Schema Registry compatibility check, stores nothing` (93 chars, within
the 120-char limit; `cargo fmt` keeps trailing comments).

### D5: Dependency allowlist by manifest path

A separate block after the source checks: for every `Cargo.toml` under `$TARGET_ROOT/rust` (pruning `target/`), with
its path relative to `$TARGET_ROOT`:

- if path ≠ `rust/kafkalyzer-kafka/Cargo.toml`, grep for `rdkafka`, `rdkafka-sys`, `reqwest`;
- if path ≠ `rust/Cargo.toml`, grep for `flutter_rust_bridge`.

Declaration regex per crate list `C`:
`^[[:space:]]*(C)[[:space:]]*=|dependencies\.(C)[[:space:]]*\]|package[[:space:]]*=[[:space:]]*"(C)"`. This covers
inline keys in any `[*dependencies]` section (including `[target.'cfg(...)'.dependencies]`, dev/build deps), the table
form `[dependencies.rdkafka]` and renames via `package = "rdkafka"`. Violations count toward the same total and exit
code, with manifest path and line.

- `rdkafka-sys` and `reqwest` go beyond the roadmap's "rdkafka, flutter_rust_bridge": guardrail L2 and §4.2 name
  `kafkalyzer-kafka` as the only rdkafka/reqwest user, and both are direct Kafka/HTTP write vectors. `openssl` is not
  guarded: it is not a write vector.
- Only `$TARGET_ROOT/rust` is walked, matching the source scan scope; `packages/velopack_flutter` is therefore not
  evaluated. Alternative: `cargo metadata`. Rejected: needs a Rust toolchain in the gate job and a resolved lockfile.
- In fallback mode (no `rust/` directory) the dependency block finds no manifests and passes.

### D6: Regression test layout

Keep the existing helper `test_violation` (rejected case). Add `test_accepted` (writes a sample, expects exit 0,
removes it) and a variant that writes a sample to a chosen path (`lib/src/*.dart`, `rust/**/Cargo.toml`). Per new
row: at least one rejected and one accepted sample (spec: "Regression Cases for Every Gate Pattern"). For the existing
rows without an accepted case, add cheap ones (`enable.auto.commit` = `"false"`, `consumer.assign(`). Update the final
case count message.

### D7: CI

Add a step `bash scripts/test_check_read_only.sh` to job `read-only-gate` after the gate step. The job stays first and
independent (`run-tests` already `needs: [read-only-gate]`); it needs no toolchain.

## False-positive check (run on the current tree)

Run with the D2/D5 regexes over the gate's own file set (28 `*.rs` under `rust/` without `target/`, 159 `*.dart` under
`lib/src/`; 3 manifests under `rust/`):

| Pattern | Rust hits | Dart hits | Verdict |
|---|---|---|---|
| Mutating admin calls | 0 | 0 | clean |
| camelCase admin names (`createTopics`, …), checked only for info | – | 0 | not needed |
| Offset store | 0 | 0 | clean |
| `.put(`/`.delete(`/`.patch(`/`Method::PUT\|DELETE\|PATCH` | 0 | 2 if Dart were scanned: `secure_storage_service.dart:70` (`_storage.delete(key:)`), `script_runner.dart:693` (`dir.delete(recursive:)`) | clean with `rs` scope (D3) |
| `.post(`/`Method::POST` without reasoned marker | 1: `schema_registry.rs:301` | – | expected; fixed by the D4 comment, then 0 (simulated) |
| `.request(` (info) | 0 | – | no generic request calls exist |
| Dependency allowlist | `flutter_rust_bridge` only in `rust/Cargo.toml:18`; `reqwest`/`rdkafka`/`rdkafka-sys` only in `rust/kafkalyzer-kafka/Cargo.toml` (lines 10, 24, 26, 30, 32, 36) | – | clean (all in allowed files) |
| `flutter_rust_bridge` outside `rust/` | `packages/velopack_flutter/rust/Cargo.toml:10` | – | not walked (D5) |

Sample checks of the regexes: 6/6 positive admin/offset samples matched (including `delete_groups (` with a space and
`incremental_alter_configs(`); 0/4 negatives matched (`describe_configs(`, `my_delete_topics_view(`,
`committed_offsets(`, `restore_offsets(`); 4/4 HTTP write samples matched; a `.post(` line with a bare marker and no
reason is still reported.

## Risks / Trade-offs

- [A grep can be evaded (e.g. `Method::from_bytes(b"PUT")`, a macro, a crate that wraps writes)] → The gate is one of
  three layers (§4.5: gate, crate layering, broker ACLs); documentation never calls it a guarantee. The dependency
  allowlist confines Kafka/HTTP crates to one crate, which keeps the review surface small.
- [Comments or doc strings that mention a forbidden call fail the gate] → Same behavior as today's rows; write prose
  without the `(`, e.g. "delete_topics".
- [`schema_registry_converter` (in `kafkalyzer-kafka`) can register schemas through its encoder API internally; a
  library-internal HTTP call is invisible to a source grep] → Only decoder/`get_schema_by_id` APIs are used today.
  Not covered by this change; see Open Questions.
- [Line-based marker: a reformat that moves `.post(` onto a different line from its comment breaks the gate] → The
  gate fails loudly (no silent pass); re-attach the marker.

## Migration Plan

Single PR: script, test script, workflow, the one-line marker, `.insecure_curlrc` deletion. Rollback is a revert;
there is no runtime or data impact.

## Open Questions

- Should a later change also forbid `schema_registry_converter` encoder/`post_schema` APIs by pattern? Deferrable; it
  does not affect this change's specs or tasks.
- Should the existing `.send(` exclude also require a reason? Deferrable; all current markers already have one.
